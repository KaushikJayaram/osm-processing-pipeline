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
    log_file = os.path.join(log_dir, f"fourlane_run_{timestamp}.log")

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
        description="Four-lane (fourlane) classification runner with bbox selection."
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

    osm_chunk_size = int(os.getenv("FOURLANE_OSM_CHUNK_SIZE", "50000"))
    
    start_time = time.time()
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        conn.autocommit = False
        # Session tuning for large updates
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

        # Step 1: Add fourlane column if it doesn't exist
        logger.info("Adding fourlane column to osm_all_roads...")
        with conn.cursor() as cursor:
            cursor.execute(
                "ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS fourlane TEXT;"
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
            # Logic: fourlane = 'yes' if oneway AND lanes >= 2, else 'no'
            update_query = """
UPDATE osm_all_roads o
SET fourlane = 
  CASE
    -- Check if road is oneway
    WHEN UPPER(COALESCE(o.tags->>'oneway', '')) IN ('YES', 'TRUE', '1', '-1') THEN
      -- If oneway, check if lanes >= 2
      CASE
        WHEN COALESCE(
               -- Try tags->>'lanes' first (extract first integer)
               NULLIF((regexp_match(COALESCE(o.tags->>'lanes',''), '([0-9]+)'))[1], '')::INT,
               -- Fallback to o.lanes column
               CASE 
                 WHEN o.lanes ~ '^[0-9]+$' THEN o.lanes::INT
                 WHEN o.lanes ~ '^[0-9]+-[0-9]+$' THEN SPLIT_PART(o.lanes, '-', 2)::INT
                 ELSE NULL
               END,
               0
             ) >= 2 THEN 'yes'
        ELSE 'no'
      END
    ELSE 'no'
  END
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
        logger.info("Computing statistics for fourlane...")
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                  COUNT(*) AS total_roads,
                  COUNT(CASE WHEN fourlane = 'yes' THEN 1 END) AS fourlane_yes,
                  COUNT(CASE WHEN fourlane = 'no' THEN 1 END) AS fourlane_no,
                  COUNT(CASE WHEN fourlane IS NULL THEN 1 END) AS fourlane_null,
                  ROUND(100.0 * COUNT(CASE WHEN fourlane = 'yes' THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS pct_yes
                FROM osm_all_roads;
            """)
            stats = cursor.fetchone()
            if stats:
                logger.info("Statistics:")
                logger.info("  Total roads: %s", stats[0])
                logger.info("  Four-lane (yes): %s (%.2f%%)", stats[1], stats[4] if stats[4] else 0)
                logger.info("  Not four-lane (no): %s", stats[2])
                logger.info("  NULL values: %s", stats[3])

    elapsed = time.time() - start_time
    logger.info("fourlane classification completed in %.2f seconds", elapsed)
    logger.info("Full log saved to: %s", log_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        logger.error("Fatal error: %s", exc, exc_info=True)
        sys.exit(1)
