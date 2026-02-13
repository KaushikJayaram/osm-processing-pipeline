#!/usr/bin/env python3

import os
import sys
import time
import logging
import subprocess
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
RASTER_TILE_SIZE = 256
INPUT_RASTER_PATH = resolve_path(
    "helpers/Worldcover_Data/worldcover_2020_india/worldcover_2020_india_50m_3857_cog.tif"
)
TABLE_NAME = "public.rs_worldcover_2020_50m"

# Default bounds (all India)
DEFAULT_LAT_MIN = 6.5
DEFAULT_LAT_MAX = 35.5
DEFAULT_LON_MIN = 68.0
DEFAULT_LON_MAX = 97.5

# Test bounds (matching urban_pressure_run.py)
TEST_LAT_MIN = 12.0
TEST_LAT_MAX = 15.0
TEST_LON_MIN = 75.0
TEST_LON_MAX = 79.0

# Chunk size for large operations
CHUNK_SIZE = 20000

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"scenery_v2_run_{timestamp}.log")

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
def table_exists(conn, schema, table):
    full_name = f"{schema}.{table}"
    with conn.cursor() as cursor:
        cursor.execute("SELECT to_regclass(%s) IS NOT NULL;", (full_name,))
        res = cursor.fetchone()
        return res[0] if res else False

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

def import_raster(table_name, raster_path, db_config):
    if not os.path.exists(raster_path):
        raise FileNotFoundError(f"Raster file not found: {raster_path}")

    # -d flag drops table if exists
    cmd = (
        f'raster2pgsql -s 3857 -d -I -C -M -t {RASTER_TILE_SIZE}x{RASTER_TILE_SIZE} '
        f'"{raster_path}" {table_name} | '
        f'psql -d {db_config["name"]} -U {db_config["user"]} '
        f'-h {db_config["host"]} -p {db_config["port"]}'
    )

    env = os.environ.copy()
    if db_config.get("password"):
        env["PGPASSWORD"] = db_config["password"]

    logger.info("Importing raster to %s (this may take a while)...", table_name)
    start_import = time.time()
    subprocess.run(cmd, shell=True, check=True, env=env)
    elapsed = time.time() - start_import
    logger.info("Raster import completed in %.2f seconds", elapsed)

# ----------------------------------------------------------------------------
# CLI bbox helpers
# ----------------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Scenery V2 pipeline runner with bbox selection."
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


def create_roads_grid_mapping(conn, base_params):
    logger.info("Creating osm_all_roads_grid mapping table...")
    with conn.cursor() as cursor:
        cursor.execute("DROP TABLE IF EXISTS public.osm_all_roads_grid;")
        cursor.execute(
            """
            CREATE UNLOGGED TABLE public.osm_all_roads_grid AS
            SELECT
                r.osm_id,
                g.grid_id
            FROM osm_all_roads r
            JOIN LATERAL (
                SELECT g.grid_id
                FROM public.india_grids_54009 g
                WHERE ST_Covers(
                    g.geom_54009,
                    ST_Transform(ST_PointOnSurface(r.geometry), 54009)
                )
                ORDER BY g.grid_id
                LIMIT 1
            ) g ON TRUE
            WHERE r.bikable_road = TRUE
              AND r.geometry IS NOT NULL
              AND r.geometry && ST_MakeEnvelope(%(lon_min)s, %(lat_min)s, %(lon_max)s, %(lat_max)s, 4326)
              AND ST_Intersects(r.geometry, ST_MakeEnvelope(%(lon_min)s, %(lat_min)s, %(lon_max)s, %(lat_max)s, 4326));
            """,
            base_params,
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_osm_all_roads_grid_grid_id "
            "ON public.osm_all_roads_grid (grid_id);"
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS idx_osm_all_roads_grid_osm_id "
            "ON public.osm_all_roads_grid (osm_id);"
        )
    logger.info("Road-to-grid mapping table created.")


def get_grid_id_range(conn):
    query = """
        SELECT COUNT(*), MIN(grid_id), MAX(grid_id)
        FROM public.osm_all_roads_grid
    """
    with conn.cursor() as cursor:
        cursor.execute(query)
        total, min_id, max_id = cursor.fetchone()
    return total, min_id, max_id

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

    sql_dir = resolve_path("sql/road_scenery_v2")
    
    start_time = time.time()
    
    # Connect for operations
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
        autocommit=False # Control transaction manually where needed
    ) as conn:
        conn.autocommit = True
        
        # 1. Check/Ingest Raster
        # Split table name into schema and table for check
        if "." in TABLE_NAME:
            schema, table = TABLE_NAME.split(".")
        else:
            schema, table = "public", TABLE_NAME
            
        if not table_exists(conn, schema, table):
            logger.info(f"Raster table '{TABLE_NAME}' not found. Attempting ingest...")
            try:
                import_raster(TABLE_NAME, INPUT_RASTER_PATH, db_config)
            except Exception as e:
                logger.error(f"Failed to ingest raster: {e}")
                sys.exit(1)
        else:
            logger.info(f"Raster table '{TABLE_NAME}' exists. Skipping import.")

        # 2. Session tuning + autovacuum control (high ROI for large updates)
        with conn.cursor() as cursor:
            cursor.execute("SET synchronous_commit = OFF;")
            cursor.execute("SET work_mem = '256MB';")
            cursor.execute("SET maintenance_work_mem = '1GB';")
            cursor.execute("ALTER TABLE public.osm_all_roads SET (autovacuum_enabled = false);")

        base_params = {
            "lat_min": lat_min,
            "lat_max": lat_max,
            "lon_min": lon_min,
            "lon_max": lon_max,
        }

        try:
            # 3. Build road-to-grid mapping for spatial chunking
            create_roads_grid_mapping(conn, base_params)

            # 4. Run SQL Steps
            # Tuple format: (filename, is_chunked)
            sql_steps = [
                ("01_worldcover_schema.sql", False),
                ("02_worldcover_sampling.sql", True),  # Heavy operation, needs chunking
                ("03_scenery_v2_classify.sql", False), # Usually fast, runs on processed rows
                ("04_qc_samples.sql", False)
            ]
            
            for sql_file, is_chunked in sql_steps:
                filepath = os.path.join(sql_dir, sql_file)
                if not os.path.exists(filepath):
                    logger.error(f"SQL file not found: {filepath}")
                    continue
                    
                logger.info(f"--- Running {sql_file} ---")
                step_start = time.time()
                
                if "qc_samples" in sql_file:
                    # QC via psql
                    with conn.cursor() as cursor:
                        cursor.close()
                    logger.info("Running QC via psql for formatted output...")
                    env = os.environ.copy()
                    env["PGPASSWORD"] = db_config["password"]
                    cmd = [
                        "psql",
                        "-h", db_config["host"],
                        "-p", str(db_config["port"]),
                        "-U", db_config["user"],
                        "-d", db_config["name"],
                        "-f", filepath
                    ]
                    subprocess.run(cmd, env=env, check=False)
                    
                elif is_chunked:
                    # Chunked Execution Strategy (server-side range)
                    logger.info(f"Starting chunked execution for {sql_file}")
                    total, min_id, max_id = get_grid_id_range(conn)
                    if min_id is None or max_id is None:
                        logger.info("No eligible roads found. Skipping %s", sql_file)
                        continue
                    total_chunks = ((max_id - min_id) // CHUNK_SIZE) + 1
                    logger.info(
                        "grid_id range: %s..%s | total=%s | chunks=%s (chunk_size=%s)",
                        min_id,
                        max_id,
                        total,
                        total_chunks,
                        CHUNK_SIZE,
                    )
                    
                    # Prepare Template
                    with open(filepath, "r", encoding="utf-8") as f:
                        sql_template = f.read()
                    
                    
                    chunk_index = 0
                    for start_id in range(min_id, max_id + 1, CHUNK_SIZE):
                        end_id = min(start_id + CHUNK_SIZE - 1, max_id)
                        chunk_index += 1
                        progress_pct = (chunk_index / total_chunks) * 100.0
                        logger.info(
                        "[%s] Chunk %s/%s (%.1f%%) grid_id %s..%s",
                            sql_file,
                            chunk_index,
                            total_chunks,
                            progress_pct,
                            start_id,
                            end_id,
                        )
                        chunk_params = dict(base_params)
                        chunk_params.update(
                        {"grid_id_min": start_id, "grid_id_max": end_id}
                        )
                        try:
                            sql_content = sql_template
                            for k, v in chunk_params.items():
                                sql_content = sql_content.replace(f":{k}", str(v))
                            with conn.cursor() as cursor:
                                cursor.execute(sql_content)
                        except Exception as e:
                            logger.error("Error executing %s: %s", sql_file, e)

                else:
                    # Standard Execution
                    params = None
                    if "sampling" in sql_file: # Fallback if marked false but needs params
                        params = dict(base_params)
                    
                    try:
                        with conn.cursor() as cursor:
                            if params:
                                # Ensure id filter placeholder is removed for non-chunked run
                                with open(filepath, "r", encoding="utf-8") as f:
                                    sql_content = f.read()
                                sql_content = sql_content.replace(":id_filter_clause", "")
                                for k, v in params.items():
                                    sql_content = sql_content.replace(f":{k}", str(v))
                                cursor.execute(sql_content)
                            else:
                                execute_sql_file(cursor, filepath, params=params)
                    except Exception as e:
                        logger.error("Error executing %s: %s", sql_file, e)
                
                perform_memory_cleanup(sql_file)
                logger.info(f"Finished {sql_file} in {time.time() - step_start:.2f}s")
        finally:
            # Re-enable autovacuum after batch run
            with conn.cursor() as cursor:
                cursor.execute("ALTER TABLE public.osm_all_roads RESET (autovacuum_enabled);")
            
    total_time = time.time() - start_time
    logger.info(f"Scenery V2 pipeline finished in {total_time:.2f}s")
    logger.info(f"Full log saved to: {log_file}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
