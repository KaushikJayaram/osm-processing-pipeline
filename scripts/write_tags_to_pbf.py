#!/usr/bin/env python3

import os
import sys
import pickle
import psycopg2
import osmium as osm
import json

def write_tags_to_pbf(db_config, output_pbf_path):
    """
    Reads OSM data from PostGIS, updates tags, and writes them back to a new OSM PBF file.
    """
    # Debug: Print db_config to ensure expected keys exist
    print("[DEBUG] db_config contents:", json.dumps(db_config, indent=4))

    # Always use new_pbf_path for v2 (new mode only)
    main_input_osm_file = db_config.get("new_pbf_path")
    
    if not main_input_osm_file:
        print("[ERROR] Missing new_pbf_path in db_config!")
        sys.exit(1)

    print(f"[write_tags_to_pbf] Input OSM PBF file: {main_input_osm_file}")
    print(f"[write_tags_to_pbf] Output OSM PBF file: {output_pbf_path}")

    # Ensure the output directory exists
    output_dir = os.path.dirname(output_pbf_path)
    os.makedirs(output_dir, exist_ok=True)

    # Delete existing output file if it exists
    if os.path.exists(output_pbf_path):
        os.remove(output_pbf_path)

    # Connect to the PostgreSQL database
    conn = psycopg2.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"]
    )
    cursor = conn.cursor()

    # Load custom attributes from osm_all_roads
    fields = [
        "road_classification",
        "road_classification_i1",
        "road_classification_v2",
        "maybe_mdr_primary",
        "maybe_mdr_secondary",
        "road_curvature_classification",
        "road_curvature_ratio",
        "road_scenery_urban",
        "road_scenery_semiurban",
        "road_scenery_rural",
        "road_scenery_forest",
        "road_scenery_hill",
        "road_scenery_lake",
        "road_scenery_beach",
        "road_scenery_river",
        "road_scenery_desert",
        "road_scenery_field",
        "road_scenery_saltflat",
        "road_scenery_mountainpass",
        "road_scenery_snowcappedmountain",
        "road_scenery_plantation",
        "road_scenery_backwater",
        "rsbikeaccess",
        "mdr",
        "final_mdr_status",
        "build_perc",
        "population_density"
    ]

    field_maps = {}

    for field in fields:
        print(f"[write_tags_to_pbf] Loading {field} from database...")
        cursor.execute(f"SELECT osm_id, {field} FROM osm_all_roads WHERE {field} IS NOT NULL")
        field_maps[field] = {row[0]: str(row[1]) for row in cursor.fetchall()}

    conn.close()
    print("[write_tags_to_pbf] Database connection closed.")

    # Save field maps for debugging
    for field, data in field_maps.items():
        with open(f'{field}_map.pkl', 'wb') as f:
            pickle.dump(data, f)
        print(f"[write_tags_to_pbf] Saved {field} map to {field}_map.pkl")

    # Define the OSM handler
    class WayHandler(osm.SimpleHandler):
        def __init__(self, field_maps, writer):
            super(WayHandler, self).__init__()
            self.field_maps = field_maps
            self.writer = writer

        def way(self, w):
            tags = dict(w.tags)
            for field, data_map in self.field_maps.items():
                if w.id in data_map:
                    tags[field] = data_map[w.id]
                    print(f"[write_tags_to_pbf] Added {field} for way {w.id}")

            new_way = osm.osm.mutable.Way(
                id=w.id,
                nodes=w.nodes,
                tags=tags
            )
            self.writer.add_way(new_way)

        def node(self, n):
            self.writer.add_node(n)

        def relation(self, r):
            self.writer.add_relation(r)

    print("[write_tags_to_pbf] Creating handler and processing OSM file...")
    
    # Delete output file if it already exists
    if os.path.exists(output_pbf_path):
        os.remove(output_pbf_path)

    writer = osm.SimpleWriter(output_pbf_path)
    handler = WayHandler(field_maps, writer)
    handler.apply_file(main_input_osm_file)

    writer.close()
    print("[write_tags_to_pbf] Way updating completed. Updated OSM file saved.")

