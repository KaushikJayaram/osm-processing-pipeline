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
# Default bounds (all India)
DEFAULT_LAT_MIN = 6.5
DEFAULT_LAT_MAX = 35.5
DEFAULT_LON_MIN = 68.0
DEFAULT_LON_MAX = 97.5

# Test bounds
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
    log_file = os.path.join(log_dir, f"persona_v2_run_{timestamp}.log")

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

def column_exists(conn, schema, table, column):
    with conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1 
                FROM information_schema.columns 
                WHERE table_schema = %s 
                  AND table_name = %s 
                  AND column_name = %s
            );
            """,
            (schema, table, column)
        )
        res = cursor.fetchone()
        return res[0] if res else False

def execute_sql_file(cursor, filepath, params=None):
    logger.info("Executing SQL file: %s", os.path.basename(filepath))
    with open(filepath, "r", encoding="utf-8") as file:
        sql_query = file.read()
    
    if params:
        for key, value in params.items():
            # Basic substitution
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
        description="Persona V2 pipeline runner with bbox selection."
    )
    parser.add_argument(
        "--bbox",
        choices=["all", "test"],
        default="test",
        help="Select bounding box (default: test for faster iterations).",
    )
    parser.add_argument("--lat-min", type=float, help="Override LAT_MIN.")
    parser.add_argument("--lat-max", type=float, help="Override LAT_MAX.")
    parser.add_argument("--lon-min", type=float, help="Override LON_MIN.")
    parser.add_argument("--lon-max", type=float, help="Override LON_MAX.")
    parser.add_argument(
        "--skip-schema",
        action="store_true",
        help="Skip schema creation (columns already exist)."
    )
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
    with conn.cursor() as cursor:
        # Check if table exists
        cursor.execute("SELECT to_regclass('public.osm_all_roads_grid') IS NOT NULL;")
        table_exists = cursor.fetchone()[0]
        
        # Determine if current bbox is "test" or "all"
        is_test_bbox = (
            base_params["lat_min"] == TEST_LAT_MIN
            and base_params["lat_max"] == TEST_LAT_MAX
            and base_params["lon_min"] == TEST_LON_MIN
            and base_params["lon_max"] == TEST_LON_MAX
        )
        
        needs_recreate = False
        if table_exists:
            if is_test_bbox:
                logger.info("Road-to-grid mapping table exists. Using existing table for test bbox.")
            else:
                # For all India: check if table covers all India
                sample_lon = 80.0
                sample_lat = 13.0
                
                cursor.execute(
                    """
                    SELECT EXISTS(
                        SELECT 1
                        FROM osm_all_roads r
                        WHERE r.bikable_road = TRUE
                          AND r.geometry IS NOT NULL
                          AND ST_Intersects(r.geometry, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
                          AND EXISTS (
                              SELECT 1 FROM public.osm_all_roads_grid rg WHERE rg.osm_id = r.osm_id
                          )
                        LIMIT 1
                    );
                    """,
                    (sample_lon, sample_lat),
                )
                covers_all_india = cursor.fetchone()[0]
                
                if covers_all_india:
                    logger.info("Road-to-grid mapping table exists and covers all India. Skipping creation.")
                else:
                    logger.info("Table exists but only covers test bbox. Recreating for all India...")
                    needs_recreate = True
        else:
            logger.info("Road-to-grid mapping table not found. Creating...")
            needs_recreate = True
        
        if needs_recreate:
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

def compute_global_persona_norm_bounds(conn):
    """
    Compute global min/max for all 4 persona scores across all bikable roads.
    Used for normalization stretching.

    Returns dict with keys:
      mm_min, mm_max, cc_min, cc_max, tb_min, tb_max, tt_min, tt_max
    """
    logger.info("Computing global min/max normalization bounds for persona scores (bikable roads)...")
    query = """
        SELECT
            MIN(persona_milemuncher_score) AS mm_min,
            MAX(persona_milemuncher_score) AS mm_max,

            MIN(persona_cornercraver_score) AS cc_min,
            MAX(persona_cornercraver_score) AS cc_max,

            MIN(persona_trailblazer_score) AS tb_min,
            MAX(persona_trailblazer_score) AS tb_max,

            MIN(persona_tranquiltraveller_score) AS tt_min,
            MAX(persona_tranquiltraveller_score) AS tt_max
        FROM osm_all_roads
        WHERE bikable_road = TRUE
          AND geometry IS NOT NULL;
    """
    with conn.cursor() as cursor:
        cursor.execute(query)
        result = cursor.fetchone()
        
    # IMPORTANT: don't use `or` here: 0.0 is a valid value and would incorrectly fall back.
    bounds = {
        "mm_min": float(result[0]) if result[0] is not None else 0.0,
        "mm_max": float(result[1]) if result[1] is not None else 1.0,
        "cc_min": float(result[2]) if result[2] is not None else 0.0,
        "cc_max": float(result[3]) if result[3] is not None else 1.0,
        "tb_min": float(result[4]) if result[4] is not None else 0.0,
        "tb_max": float(result[5]) if result[5] is not None else 1.0,
        "tt_min": float(result[6]) if result[6] is not None else 0.0,
        "tt_max": float(result[7]) if result[7] is not None else 1.0,
    }

    # Efficiency shortcut: if bounds are already [0, 1], normalization is identity.
    # We'll pass flags to SQL so it can do a cheap copy instead of divide.
    eps = 1e-12
    bounds.update(
        {
            "mm_identity_norm": 1
            if abs(bounds["mm_min"] - 0.0) <= eps and abs(bounds["mm_max"] - 1.0) <= eps
            else 0,
            "cc_identity_norm": 1
            if abs(bounds["cc_min"] - 0.0) <= eps and abs(bounds["cc_max"] - 1.0) <= eps
            else 0,
            "tb_identity_norm": 1
            if abs(bounds["tb_min"] - 0.0) <= eps and abs(bounds["tb_max"] - 1.0) <= eps
            else 0,
            "tt_identity_norm": 1
            if abs(bounds["tt_min"] - 0.0) <= eps and abs(bounds["tt_max"] - 1.0) <= eps
            else 0,
        }
    )
    
    logger.info("Global min/max bounds computed:")
    logger.info("  MileMuncher: [min=%.6f, max=%.6f]", bounds["mm_min"], bounds["mm_max"])
    logger.info("  CornerCraver: [min=%.6f, max=%.6f]", bounds["cc_min"], bounds["cc_max"])
    logger.info("  TrailBlazer: [min=%.6f, max=%.6f]", bounds["tb_min"], bounds["tb_max"])
    logger.info("  TranquilTraveller: [min=%.6f, max=%.6f]", bounds["tt_min"], bounds["tt_max"])
    logger.info(
        "Identity normalization flags (1=copy raw): mm=%s cc=%s tb=%s tt=%s",
        bounds["mm_identity_norm"],
        bounds["cc_identity_norm"],
        bounds["tb_identity_norm"],
        bounds["tt_identity_norm"],
    )
    
    return bounds

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
    logger.info(f"Bounding box: lat[{lat_min}, {lat_max}] lon[{lon_min}, {lon_max}]")

    sql_dir = resolve_path("sql/road_persona_v2")
    
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
        
        # Session tuning
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
            # SQL Steps
            # Tuple format: (filename, is_chunked, skip_condition, needs_norm_bounds)
            sql_steps = [
                ("00_add_persona_v2_columns.sql", False, args.skip_schema, False),
                ("01_compute_parameter_scores.sql", True, False, False),
                ("02_compute_persona_scores.sql", True, False, False),
                ("03_normalize_persona_scores.sql", True, False, True),
            ]
            
            # Will store global min/max bounds for normalization
            persona_bounds = None
            
            for sql_file, is_chunked, should_skip, needs_minmax in sql_steps:
                if should_skip:
                    logger.info(f"Skipping {sql_file} (skip flag set)")
                    continue
                    
                filepath = os.path.join(sql_dir, sql_file)
                if not os.path.exists(filepath):
                    logger.error(f"SQL file not found: {filepath}")
                    continue
                    
                logger.info(f"--- Running {sql_file} ---")
                step_start = time.time()
                
                # If this step needs normalization bounds, compute them once
                if needs_minmax and persona_bounds is None:
                    persona_bounds = compute_global_persona_norm_bounds(conn)
                
                if is_chunked:
                    # Build grid mapping for chunking
                    create_roads_grid_mapping(conn, base_params)
                    
                    # Chunked Execution Strategy
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
                        # If this step needs normalization bounds, add those params too
                        if needs_minmax and persona_bounds:
                            chunk_params.update(persona_bounds)
                        
                        try:
                            sql_content = sql_template
                            for k, v in chunk_params.items():
                                sql_content = sql_content.replace(f":{k}", str(v))
                            with conn.cursor() as cursor:
                                cursor.execute(sql_content)
                        except Exception as e:
                            logger.error("Error executing %s chunk %s: %s", sql_file, chunk_index, e)
                else:
                    # Standard Execution
                    try:
                        with conn.cursor() as cursor:
                            execute_sql_file(cursor, filepath, params=base_params)
                    except Exception as e:
                        logger.error("Error executing %s: %s", sql_file, e)
                
                perform_memory_cleanup(sql_file)
                logger.info(f"Finished {sql_file} in {time.time() - step_start:.2f}s")
        
        except Exception as e:
            logger.error("Error in persona v2 pipeline: %s", e, exc_info=True)
            raise
                
    total_time = time.time() - start_time
    logger.info(f"Persona V2 pipeline finished in {total_time:.2f}s")
    logger.info(f"Full log saved to: {log_file}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
