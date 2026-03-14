#!/usr/bin/env python3

import os
import sys
import time
import logging
from datetime import datetime

import psycopg
import argparse
from dotenv import load_dotenv


# ----------------------------------------------------------------------------
# Path helpers
# ----------------------------------------------------------------------------
def get_project_base_dir():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(script_dir))


def resolve_path(path):
    base_dir = get_project_base_dir()
    if os.path.isabs(path):
        return path
    if path.startswith("./"):
        path = path[2:]
    return os.path.join(base_dir, path)


# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"avg_speed_kph_run_{timestamp}.log")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file, mode="a", encoding="utf-8"),
            logging.StreamHandler(),
        ],
    )
    logger = logging.getLogger(__name__)
    logger.info("Logging initialized. Log file: %s", log_file)
    return logger, log_file


logger, log_file = setup_logging()


# ----------------------------------------------------------------------------
# Utility helpers
# ----------------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Average Speed (avg_speed_kph) calculation runner with bbox selection."
    )
    parser.add_argument(
        "--bbox",
        choices=["all", "test"],
        default="all",
        help="Select bounding box (default: all).",
    )
    parser.add_argument("--lat-min", type=float, help="Override LAT_MIN.")
    parser.add_argument("--lat-max", type=float, help="Override LAT_MAX.")
    parser.add_argument("--lon-min", type=float, help="Override LON_MIN.")
    parser.add_argument("--lon-max", type=float, help="Override LON_MAX.")
    return parser.parse_args()


def resolve_bbox(args):
    # Default bounds (all India)
    default_lat_min = 6.5
    default_lat_max = 35.5
    default_lon_min = 68.0
    default_lon_max = 97.5

    # Test bounds
    test_lat_min = 12.0
    test_lat_max = 15.0
    test_lon_min = 75.0
    test_lon_max = 79.0

    if args.bbox == "test":
        lat_min, lat_max = test_lat_min, test_lat_max
        lon_min, lon_max = test_lon_min, test_lon_max
    else:
        lat_min, lat_max = default_lat_min, default_lat_max
        lon_min, lon_max = default_lon_min, default_lon_max

    if args.lat_min is not None:
        lat_min = args.lat_min
    if args.lat_max is not None:
        lat_max = args.lat_max
    if args.lon_min is not None:
        lon_min = args.lon_min
    if args.lon_max is not None:
        lon_max = args.lon_max

    return lat_min, lat_max, lon_min, lon_max


def main():
    args = parse_args()
    lat_min, lat_max, lon_min, lon_max = resolve_bbox(args)
    load_dotenv(override=True)

    db_config = {
        "host": os.getenv("DB_HOST", "localhost"),
        "name": os.getenv("DB_NAME"),
        "user": os.getenv("DB_USER"),
        "password": os.getenv("DB_PASSWORD"),
        "port": int(os.getenv("DB_PORT", "5432")),
    }

    required = ["name", "user", "password"]
    missing = [k for k in required if not db_config.get(k)]
    if missing:
        logger.error("Missing required DB config values: %s", ", ".join(missing))
        sys.exit(1)

    logger.info("DB Host: %s", db_config["host"])
    logger.info("DB Name: %s", db_config["name"])
    logger.info("DB User: %s", db_config["user"])
    logger.info("DB Port: %s", db_config["port"])
    logger.info(
        "BBox: lat_min=%s, lat_max=%s, lon_min=%s, lon_max=%s",
        lat_min,
        lat_max,
        lon_min,
        lon_max,
    )

    osm_chunk_size = int(os.getenv("AVG_SPEED_OSM_CHUNK_SIZE", "20000"))
    
    start_time = time.time()
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        conn.autocommit = False
        # Session tuning for large spatial updates
        with conn.cursor() as cursor:
            cursor.execute("SET work_mem = '512MB';")
            cursor.execute("SET maintenance_work_mem = '1GB';")
            cursor.execute("SET temp_buffers = '128MB';")
            cursor.execute("SET synchronous_commit = OFF;")
            cursor.execute("ALTER TABLE public.osm_all_roads SET (autovacuum_enabled = false);")

        use_bbox_filter = (
            args.bbox == "test"
            or args.lat_min is not None
            or args.lat_max is not None
            or args.lon_min is not None
            or args.lon_max is not None
        )

        # Step 1: Add avg_speed_kph column if it doesn't exist
        logger.info("Adding avg_speed_kph column to osm_all_roads...")
        with conn.cursor() as cursor:
            cursor.execute(
                "ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS avg_speed_kph DOUBLE PRECISION;"
            )
        conn.commit()

        # Step 2: Determine OSM ID range
        with conn.cursor() as stats_cursor:
            if use_bbox_filter:
                stats_cursor.execute(
                    """
                    SELECT MIN(osm_id), MAX(osm_id)
                    FROM osm_all_roads
                    WHERE geometry && ST_MakeEnvelope(%s, %s, %s, %s, 4326)
                      AND ST_Intersects(geometry, ST_MakeEnvelope(%s, %s, %s, %s, 4326));
                    """,
                    (lon_min, lat_min, lon_max, lat_max, lon_min, lat_min, lon_max, lat_max),
                )
            else:
                stats_cursor.execute(
                    "SELECT MIN(osm_id), MAX(osm_id) FROM osm_all_roads;"
                )
            min_osm, max_osm = stats_cursor.fetchone()

        if min_osm is None or max_osm is None:
            raise RuntimeError("No roads found in osm_all_roads.")

        total_osm_chunks = ((max_osm - min_osm) // osm_chunk_size) + 1
        logger.info(
            "OSM range: %s..%s | chunks=%s (chunk_size=%s)",
            min_osm,
            max_osm,
            total_osm_chunks,
            osm_chunk_size,
        )

        # Step 3: Process in chunks
        chunk_index = 0
        for start_id in range(min_osm, max_osm + 1, osm_chunk_size):
            end_id = min(start_id + osm_chunk_size - 1, max_osm)
            chunk_index += 1
            progress_pct = (chunk_index / total_osm_chunks) * 100.0
            logger.info(
                "Chunk %s/%s (%.1f%%) osm_id %s..%s",
                chunk_index,
                total_osm_chunks,
                progress_pct,
                start_id,
                end_id,
            )

            # Build the UPDATE query
            # NOTE: Using twistiness_score (v2, higher values = more twisty/curved)
            # Thresholds based on persona framework:
            #   - 0.15+ is considered high twistiness for CornerCraver (max score)
            #   - 0.20 is cap for MileMuncher straightness calc
            #   - We use 0.08-0.20 range for speed penalty scaling
            update_query = """
UPDATE osm_all_roads o
SET avg_speed_kph =
  100.0
  * (
      -- lanes + oneway multiplier
      -- lanes_i: first integer from tags->>'lanes', fallback to o.lanes, then 0
      CASE
        WHEN UPPER(COALESCE(o.tags->>'oneway', '')) IN ('YES', 'TRUE', '1', '-1') THEN
          CASE
            WHEN COALESCE(
                   NULLIF((regexp_match(COALESCE(o.tags->>'lanes',''), '([0-9]+)'))[1], '')::INT,
                   CASE 
                     WHEN o.lanes ~ '^[0-9]+$' THEN o.lanes::INT
                     WHEN o.lanes ~ '^[0-9]+-[0-9]+$' THEN SPLIT_PART(o.lanes, '-', 2)::INT
                     ELSE NULL
                   END,
                   0
                 ) > 1 THEN 1.0
            ELSE 0.9
          END
        ELSE
          CASE
            WHEN COALESCE(
                   NULLIF((regexp_match(COALESCE(o.tags->>'lanes',''), '([0-9]+)'))[1], '')::INT,
                   CASE 
                     WHEN o.lanes ~ '^[0-9]+$' THEN o.lanes::INT
                     WHEN o.lanes ~ '^[0-9]+-[0-9]+$' THEN SPLIT_PART(o.lanes, '-', 2)::INT
                     ELSE NULL
                   END,
                   0
                 ) > 1 THEN 0.9
            ELSE 0.8
          END
      END
    )
  * (
      -- road_type_i1 x road_setting_i1 multiplier
      CASE
        WHEN COALESCE(o.road_setting_i1, '') = 'Rural' THEN
          CASE
            WHEN COALESCE(o.road_type_i1, '') = 'NH'    THEN 0.9
            WHEN COALESCE(o.road_type_i1, '') = 'SH'    THEN 0.8
            WHEN COALESCE(o.road_type_i1, '') = 'MDR'   THEN 0.7
            WHEN COALESCE(o.road_type_i1, '') = 'OH'    THEN 0.5
            WHEN COALESCE(o.road_type_i1, '') = 'HADJ'  THEN 0.5
            WHEN COALESCE(o.road_type_i1, '') = 'TRACK' THEN 0.2
            WHEN COALESCE(o.road_type_i1, '') IN ('WOH','Res') THEN 0.25
            ELSE 0.25
          END

        WHEN COALESCE(o.road_setting_i1, '') = 'SemiUrban' THEN
          CASE
            WHEN COALESCE(o.road_type_i1, '') = 'NH'    THEN 0.8
            WHEN COALESCE(o.road_type_i1, '') = 'SH'    THEN 0.6
            WHEN COALESCE(o.road_type_i1, '') = 'MDR'   THEN 0.6
            WHEN COALESCE(o.road_type_i1, '') = 'OH'    THEN 0.4
            WHEN COALESCE(o.road_type_i1, '') = 'HADJ'  THEN 0.5
            WHEN COALESCE(o.road_type_i1, '') = 'TRACK' THEN 0.2
            WHEN COALESCE(o.road_type_i1, '') IN ('WOH','Res') THEN 0.25
            ELSE 0.25
          END

        WHEN COALESCE(o.road_setting_i1, '') = 'Urban' THEN
          CASE
            WHEN COALESCE(o.road_type_i1, '') = 'NH'    THEN 0.6
            WHEN COALESCE(o.road_type_i1, '') = 'SH'    THEN 0.5
            WHEN COALESCE(o.road_type_i1, '') = 'MDR'   THEN 0.5
            WHEN COALESCE(o.road_type_i1, '') = 'OH'    THEN 0.4
            WHEN COALESCE(o.road_type_i1, '') = 'HADJ'  THEN 0.5
            WHEN COALESCE(o.road_type_i1, '') = 'TRACK' THEN 0.2
            WHEN COALESCE(o.road_type_i1, '') IN ('WOH','Res') THEN 0.4
            ELSE 0.25
          END

        ELSE 0.25
      END
    )
  * (
      -- intersection degradation (only if < 1.0)
      CASE
        WHEN COALESCE(o.intersection_speed_degradation_final, 1.0) < 1.0
          THEN COALESCE(o.intersection_speed_degradation_final, 1.0)
        ELSE 1.0
      END
    )
  * (
      -- curvature multiplier using twistiness_score (higher = more twisty)
      -- If twistiness_score is NULL, default to 1.0 (no penalty, assume straight)
      -- Scale: 0.0-0.08 = 1.0 (straight, no penalty)
      --        0.08-0.20 = scale from 1.0 to 0.6
      --        0.20+ = 0.6 (very twisty, max penalty)
      CASE
        WHEN COALESCE(o.twistiness_score, 0.0) >= 0.20 THEN 0.6
        WHEN COALESCE(o.twistiness_score, 0.0) >= 0.08 THEN 
          1.0 - ((COALESCE(o.twistiness_score, 0.0) - 0.08) * 3.333)
        ELSE 1.0
      END
    )
WHERE o.osm_id >= %s AND o.osm_id <= %s
            """

            # Add bbox filter if needed
            if use_bbox_filter:
                update_query += """
  AND o.geometry && ST_MakeEnvelope(%s, %s, %s, %s, 4326)
  AND ST_Intersects(o.geometry, ST_MakeEnvelope(%s, %s, %s, %s, 4326))
                """
                params = (start_id, end_id, lon_min, lat_min, lon_max, lat_max, lon_min, lat_min, lon_max, lat_max)
            else:
                params = (start_id, end_id)

            with conn.cursor() as cursor:
                cursor.execute(update_query, params)
                rows_updated = cursor.rowcount
                logger.info("  Updated %s rows in this chunk", rows_updated)
            
            conn.commit()

        # Re-enable autovacuum
        with conn.cursor() as cursor:
            cursor.execute("ALTER TABLE public.osm_all_roads RESET (autovacuum_enabled);")
        conn.commit()

        # Optional: compute statistics
        logger.info("Computing statistics for avg_speed_kph...")
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                  COUNT(*) AS n,
                  AVG(avg_speed_kph) AS avg_kph,
                  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_speed_kph) AS p50,
                  PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY avg_speed_kph) AS p90,
                  MIN(avg_speed_kph) AS min_kph,
                  MAX(avg_speed_kph) AS max_kph
                FROM osm_all_roads
                WHERE avg_speed_kph IS NOT NULL;
            """)
            stats = cursor.fetchone()
            if stats:
                logger.info("Statistics:")
                logger.info("  Total rows: %s", stats[0])
                logger.info("  Avg speed: %.2f kph", stats[1] if stats[1] else 0)
                logger.info("  Median (p50): %.2f kph", stats[2] if stats[2] else 0)
                logger.info("  P90: %.2f kph", stats[3] if stats[3] else 0)
                logger.info("  Min: %.2f kph", stats[4] if stats[4] else 0)
                logger.info("  Max: %.2f kph", stats[5] if stats[5] else 0)

    elapsed = time.time() - start_time
    logger.info("avg_speed_kph calculation completed in %.2f seconds", elapsed)
    logger.info("Full log saved to: %s", log_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        logger.error("Fatal error: %s", exc, exc_info=True)
        sys.exit(1)
