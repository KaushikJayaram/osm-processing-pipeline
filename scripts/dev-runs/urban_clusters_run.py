#!/usr/bin/env python3

import os
import sys
import time
import logging
import argparse
import psycopg
import psutil
import gc
from datetime import datetime
from dotenv import load_dotenv

# ----------------------------------------------------------------------------
# Path helpers
# ----------------------------------------------------------------------------
def get_project_base_dir():
    # Helper to find the pipeline root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # script is in scripts/dev-runs, so up 2 levels is osm-processing-pipeline
    return os.path.dirname(os.path.dirname(script_dir))

def resolve_path(path):
    base_dir = get_project_base_dir()
    if os.path.isabs(path):
        return path
    if path.startswith("./"):
        path = path[2:]
    return os.path.join(base_dir, path)

# ----------------------------------------------------------------------------
# Tunable parameters & Constants
# ----------------------------------------------------------------------------
# Default bounds (all India)
DEFAULT_LAT_MIN = 6.5
DEFAULT_LAT_MAX = 35.5
DEFAULT_LON_MIN = 68.0
DEFAULT_LON_MAX = 97.5

# Test bounds (matching other test scripts)
TEST_LAT_MIN = 12.0
TEST_LAT_MAX = 15.0
TEST_LON_MIN = 75.0
TEST_LON_MAX = 79.0

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"urban_clusters_run_{timestamp}.log")

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
# DB Helpers
# ----------------------------------------------------------------------------
def execute_sql_file(cursor, filepath, params=None):
    logger.info("Executing SQL file: %s", os.path.basename(filepath))
    with open(filepath, "r", encoding="utf-8") as file:
        sql_query = file.read()
    
    if params:
        for key, value in params.items():
            # Basic substitution (be careful with SQL injection if untrusted input)
            sql_query = sql_query.replace(f":{key}", str(value))
            
    cursor.execute(sql_query)

def perform_memory_cleanup(step_name):
    logger.info("[MEMORY_CLEANUP] Starting cleanup after %s...", step_name)
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / (1024 * 1024 * 1024)
    collected = gc.collect()
    mem_after = process.memory_info().rss / (1024 * 1024 * 1024)
    logger.info("[MEMORY_CLEANUP] Collected %s objects", collected)
    logger.info(
        "[MEMORY_CLEANUP] Memory before: %.2f GB, after: %.2f GB",
        mem_before,
        mem_after,
    )

# ----------------------------------------------------------------------------
# CLI bbox helpers
# ----------------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Urban Clusters pipeline runner with bbox selection."
    )
    parser.add_argument(
        "--bbox",
        choices=["all", "test"],
        default="test",
        help="Select bounding box (default: test).",
    )
    parser.add_argument("--lat-min", type=float, help="Override LAT_MIN.")
    parser.add_argument("--lat-max", type=float, help="Override LAT_MAX.")
    parser.add_argument("--lon-min", type=float, help="Override LON_MIN.")
    parser.add_argument("--lon-max", type=float, help="Override LON_MAX.")
    return parser.parse_args()


def resolve_bbox(args):
    if args.bbox == "test":
        lat_min, lat_max = TEST_LAT_MIN, TEST_LAT_MAX
        lon_min, lon_max = TEST_LON_MIN, TEST_LON_MAX
    else:
        lat_min, lat_max = DEFAULT_LAT_MIN, DEFAULT_LAT_MAX
        lon_min, lon_max = DEFAULT_LON_MIN, DEFAULT_LON_MAX

    if args.lat_min is not None:
        lat_min = args.lat_min
    if args.lat_max is not None:
        lat_max = args.lat_max
    if args.lon_min is not None:
        lon_min = args.lon_min
    if args.lon_max is not None:
        lon_max = args.lon_max

    return lat_min, lat_max, lon_min, lon_max

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    args = parse_args()
    lat_min, lat_max, lon_min, lon_max = resolve_bbox(args)
    load_dotenv(override=True)

    db_config = {
        "host": os.getenv("DB_HOST", "localhost"),
        "name": os.getenv("DB_NAME", "ridesense"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", "postgres"),
        "port": int(os.getenv("DB_PORT", "5432")),
    }
    
    required = ["name", "user", "password"]
    missing = [k for k in required if not db_config.get(k)]
    if missing:
        logger.error("Missing required DB config values: %s", ", ".join(missing))
        sys.exit(1)

    logger.info(f"Connecting to DB {db_config['name']} at {db_config['host']}")
    logger.info(f"Using bbox: lon_min={lon_min}, lat_min={lat_min}, lon_max={lon_max}, lat_max={lat_max}")

    sql_dir = resolve_path("sql/urban_clusters")
    
    start_time = time.time()
    
    # Connect for operations
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
        autocommit=False
    ) as conn:
        conn.autocommit = True
        
        # Session tuning for performance
        with conn.cursor() as cursor:
            cursor.execute("SET synchronous_commit = OFF;")
            cursor.execute("SET work_mem = '256MB';")
            cursor.execute("SET maintenance_work_mem = '1GB';")

        base_params = {
            "lat_min": lat_min,
            "lat_max": lat_max,
            "lon_min": lon_min,
            "lon_max": lon_max,
        }

        try:
            # Run SQL Steps
            sql_steps = [
                "01_clusters_opt1_test.sql",  # Option 1: ST_ClusterIntersecting
                "02_clusters_opt3_test.sql",  # Option 3: ST_ClusterDBSCAN
            ]
            
            for sql_file in sql_steps:
                filepath = os.path.join(sql_dir, sql_file)
                if not os.path.exists(filepath):
                    logger.error(f"SQL file not found: {filepath}")
                    continue
                    
                logger.info(f"--- Running {sql_file} ---")
                step_start = time.time()
                
                try:
                    with conn.cursor() as cursor:
                        execute_sql_file(cursor, filepath, params=base_params)
                    
                    perform_memory_cleanup(sql_file)
                    elapsed = time.time() - step_start
                    logger.info(f"Finished {sql_file} in {elapsed:.2f}s")
                except Exception as e:
                    logger.error(f"Error executing {sql_file}: {e}", exc_info=True)
                    raise
            
            logger.info("All SQL steps completed successfully")
            
            # Create visualization views and materialized views
            vis_sql_file = resolve_path("sql/visualization/vis_urban_clusters_test.sql")
            if os.path.exists(vis_sql_file):
                logger.info("--- Creating visualization views ---")
                vis_start = time.time()
                try:
                    with conn.cursor() as cursor:
                        execute_sql_file(cursor, vis_sql_file, params=None)
                    elapsed = time.time() - vis_start
                    logger.info(f"Visualization views created in {elapsed:.2f}s")
                except Exception as e:
                    logger.error(f"Error creating visualization views: {e}", exc_info=True)
                    logger.warning("Continuing despite visualization view errors...")
            else:
                logger.warning(f"Visualization SQL file not found: {vis_sql_file}")
            
        except Exception as e:
            logger.error(f"Fatal error during execution: {e}", exc_info=True)
            sys.exit(1)
            
    total_time = time.time() - start_time
    logger.info(f"Urban Clusters pipeline finished in {total_time:.2f}s")
    logger.info(f"Full log saved to: {log_file}")
    logger.info("Visualization views created. Load in QGIS using 'egis' connection.")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
