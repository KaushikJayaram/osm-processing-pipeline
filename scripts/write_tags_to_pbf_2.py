#!/usr/bin/env python3

import os
import sys
from typing import Dict, Any
import logging

import psycopg
import osmium as osm

try:
    from .utils import setup_logging
except ImportError:
    from utils import setup_logging

# Initialize logger
logger = logging.getLogger(__name__)

def log_print(message, level='info'):
    """Print to console and log to file."""
    print(message)
    if level == 'info':
        logger.info(message)
    elif level == 'warning':
        logger.warning(message)
    elif level == 'error':
        logger.error(message)
    elif level == 'debug':
        logger.debug(message)


# Columns in osm_all_roads that should become tags on ways
TAG_FIELDS = [
    # Road classification
    "road_classification",
    "road_classification_i1",
    "road_setting_i1",
    "road_type_i1",
    "road_classification_v2",
    
    # Curvature (legacy - from old pipeline)
    "road_curvature_classification",
    "road_curvature_ratio",
    
    # Curvature v2 (new pipeline - from sql/road_curvature_v2/)
    "twistiness_score",
    "twistiness_class",
    "meters_sharp",
    "meters_broad",
    "meters_straight",
    
    # Scenery
    "road_scenery_urban",
    "road_scenery_forest",
    "road_scenery_hill",
    "road_scenery_lake",
    "road_scenery_beach",
    "road_scenery_river",
    "road_scenery_field",
    
    # Access and environment
    "rsbikeaccess",
    "build_perc",
    "population_density",
    
    # Intersection speed degradation (v2 - new approach)
    "intersection_speed_degradation_base",  # Base degradation value (0.0-0.5, before setting/lanes factors)
    "intersection_speed_degradation_setting_adjusted",  # Degradation value (0.0-0.5, after setting multiplier applied)
    "intersection_speed_degradation_final",  # MULTIPLIER (0.5-1.0) - ready for GraphHopper multiply_by operations
    
    # Persona scores (simplified framework - Phase 1)
    "persona_milemuncher_base_score",  # MileMuncher persona score (0-100)
    "persona_cornercraver_base_score",  # CornerCraver persona score (0-100)
    "persona_trailblazer_base_score",  # TrailBlazer persona score (0-100)
    "persona_tranquiltraveller_base_score",  # TranquilTraveller persona score (0-100)
]


def _build_where_clause() -> str:
    """
    Build a WHERE clause that filters to rows where at least one tag field is non-NULL.
    """
    conditions = [f"{field} IS NOT NULL" for field in TAG_FIELDS]
    return " OR ".join(conditions)


def _load_extra_tags(db_config: Dict[str, Any]) -> Dict[int, Dict[str, str]]:
    """
    Load all extra tags from osm_all_roads into a single mapping:

        { osm_id: { field_name: value_str, ... }, ... }

    Only non-NULL values are included for each field.
    Tag names are kept EXACTLY as column names (no prefixes/renaming).
    """
    log_print("[write_tags_to_pbf] Connecting to Postgres to load extra tags...")

    conn = psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    )

    extra_tags: Dict[int, Dict[str, str]] = {}

    try:
        cursor = conn.cursor()

        select_cols = ", ".join(["osm_id"] + TAG_FIELDS)
        where_clause = _build_where_clause()
        query = f"""
            SELECT {select_cols}
            FROM osm_all_roads
            WHERE {where_clause}
        """

        log_print("[write_tags_to_pbf] Executing query to load tag fields from osm_all_roads...")
        cursor.execute(query)

        row_count = 0
        for row in cursor:
            row_count += 1
            osm_id = int(row[0])
            row_tags: Dict[str, str] = {}

            # row[1:] corresponds to TAG_FIELDS in order
            for idx, field in enumerate(TAG_FIELDS, start=1):
                value = row[idx]
                if value is not None:
                    # keep tag name EXACTLY as field name, convert value to str
                    row_tags[field] = str(value)

            if row_tags:
                extra_tags[osm_id] = row_tags

        cursor.close()

        log_print(
            f"[write_tags_to_pbf] Loaded {row_count:,} rows from osm_all_roads, "
            f"{len(extra_tags):,} ways with at least one extra tag."
        )
    finally:
        conn.close()
        log_print("[write_tags_to_pbf] Database connection closed.")

    return extra_tags


class WayHandler(osm.SimpleHandler):
    """
    Streaming handler that:
    - Forwards nodes and relations unchanged
    - For ways:
        * If no 'highway' tag -> forward unchanged
        * If 'highway' present and osm_id in extra_tags -> merge tags and write
    """

    def __init__(self, extra_tags: Dict[int, Dict[str, str]], writer: osm.SimpleWriter):
        super().__init__()
        self.extra_tags = extra_tags
        self.writer = writer

    def node(self, n):
        self.writer.add_node(n)

    def relation(self, r):
        self.writer.add_relation(r)

    def way(self, w):
        # Fast path: skip any non-highway ways
        if "highway" not in w.tags:
            self.writer.add_way(w)
            return

        extra = self.extra_tags.get(w.id)
        if not extra:
            # Highway way but no extra tags -> forward unchanged
            self.writer.add_way(w)
            return

        # Merge existing tags with extra tags
        merged_tags = dict(w.tags)
        merged_tags.update(extra)

        # Use replace() to preserve other metadata (version, timestamp, etc.)
        new_way = w.replace(tags=merged_tags)
        self.writer.add_way(new_way)


def write_tags_to_pbf(db_config, output_pbf_path):
    """
    Reads custom tag data from PostGIS (osm_all_roads), updates OSM way tags,
    and writes them back to a new OSM PBF file.

    - Input PBF path is taken from db_config["new_pbf_path"]
    - Tags are added only for highway ways that appear in osm_all_roads
    - Tag names are kept exactly as DB column names (no prefixing/renaming)
    """

    main_input_osm_file = db_config.get("new_pbf_path")
    if not main_input_osm_file:
        log_print("[ERROR] Missing new_pbf_path in db_config!", level='error')
        sys.exit(1)

    log_print(f"[write_tags_to_pbf] Input OSM PBF file: {main_input_osm_file}")
    log_print(f"[write_tags_to_pbf] Output OSM PBF file: {output_pbf_path}")

    # Ensure the output directory exists
    output_dir = os.path.dirname(output_pbf_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    # Delete existing output file if it exists
    if os.path.exists(output_pbf_path):
        os.remove(output_pbf_path)

    # Step 1: Load extra tags from PostGIS
    extra_tags = _load_extra_tags(db_config)
    log_print(
        f"[write_tags_to_pbf] Extra tags loaded for {len(extra_tags):,} ways. "
        "Starting PBF augmentation..."
    )

    # Step 2: Stream over the input PBF and write augmented PBF
    writer = osm.SimpleWriter(output_pbf_path)
    try:
        handler = WayHandler(extra_tags, writer)
        handler.apply_file(main_input_osm_file)
    finally:
        writer.close()

    log_print("[write_tags_to_pbf] PBF augmentation completed. Updated OSM file saved.")

if __name__ == "__main__":
    setup_logging()
    # Logic to parse args if run directly would go here
    logger.info("Script run directly")
