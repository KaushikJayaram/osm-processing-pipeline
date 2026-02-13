#!/usr/bin/env python3

import os
import sys
import time
import logging
import subprocess
import gc
from datetime import datetime

import psycopg
import psutil
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
# Tunable parameters
# ----------------------------------------------------------------------------
# Full India bounds (update if needed)
LAT_MIN = 6.5
LAT_MAX = 35.5
LON_MIN = 68.0
LON_MAX = 97.5

# If true, recreate india_grids_54009 for full-India runs
RECREATE_INDIA_GRIDS_54009 = False

# Chunking (grid_id ranges)
CHUNK_SIZE = 200000

PD_SAT = 50000
NEIGHBOR_RADIUS = 2000
RASTER_TILE_SIZE = 256

# Raster file paths (downloaded locally)
POP_RASTER_PATH = "/Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/data/GHSL_data/GHS_POP_E2030_GLOBE_R2023A_54009_100_V1_0.tif"
BUILT_RASTER_PATH = "/Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/data/GHSL_data/GHS_BUILT_S_E2030_GLOBE_R2023A_54009_100_V1_0.tif"

POP_TABLE = "public.ghs_pop_e2030_r2023a_54009_100"
BUILT_TABLE = "public.ghs_built_s_e2030_r2023a_54009_100"


# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"urban_pressure_run_{timestamp}.log")

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
def table_exists(conn, schema, table):
    full_name = f"{schema}.{table}"
    with conn.cursor() as cursor:
        cursor.execute("SELECT to_regclass(%s) IS NOT NULL;", (full_name,))
        return cursor.fetchone()[0]


def execute_sql_file(cursor, filepath, params=None):
    logger.info("Executing SQL file: %s", os.path.basename(filepath))
    with open(filepath, "r", encoding="utf-8") as file:
        sql_query = file.read()

    if params:
        for key, value in params.items():
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

    cmd = (
        f'raster2pgsql -s 54009 -I -C -M -t {RASTER_TILE_SIZE}x{RASTER_TILE_SIZE} '
        f'"{raster_path}" {table_name} | '
        f'psql -d {db_config["name"]} -U {db_config["user"]} '
        f'-h {db_config["host"]} -p {db_config["port"]}'
    )

    env = os.environ.copy()
    if db_config.get("password"):
        env["PGPASSWORD"] = db_config["password"]

    logger.info("Importing raster to %s", table_name)
    subprocess.run(cmd, shell=True, check=True, env=env)


def main():
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

    sql_dir = resolve_path("sql/urban_pressure")

    start_time = time.time()
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        conn.autocommit = False

        # Idempotent raster import
        if not table_exists(conn, "public", "ghs_pop_e2030_r2023a_54009_100"):
            import_raster(POP_TABLE, POP_RASTER_PATH, db_config)
        else:
            logger.info("Raster table exists: %s (skipping import)", POP_TABLE)

        if not table_exists(conn, "public", "ghs_built_s_e2030_r2023a_54009_100"):
            import_raster(BUILT_TABLE, BUILT_RASTER_PATH, db_config)
        else:
            logger.info("Raster table exists: %s (skipping import)", BUILT_TABLE)

        sql_files = [
            "00_prerequisites.sql",
            "01_create_india_grids_54009.sql",
            "02_add_target_columns.sql",
        ]

        for sql_file in sql_files:
            filepath = os.path.join(sql_dir, sql_file)
            if sql_file == "01_create_india_grids_54009.sql":
                if table_exists(conn, "public", "india_grids_54009"):
                    if RECREATE_INDIA_GRIDS_54009:
                        logger.info("Dropping public.india_grids_54009 for full-India rebuild")
                        with conn.cursor() as cursor:
                            cursor.execute("DROP TABLE IF EXISTS public.india_grids_54009;")
                        conn.commit()
                    else:
                        logger.info("Table exists: public.india_grids_54009 (skipping)")
                        continue
                params = {
                    "lat_min": LAT_MIN,
                    "lat_max": LAT_MAX,
                    "lon_min": LON_MIN,
                    "lon_max": LON_MAX,
                }
            else:
                params = None

            with conn.cursor() as cursor:
                execute_sql_file(cursor, filepath, params=params)
            conn.commit()
            perform_memory_cleanup(sql_file)

        # Chunked processing for heavy steps
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*), MIN(grid_id), MAX(grid_id) FROM public.india_grids_54009;"
            )
            total_grids, min_id, max_id = cursor.fetchone()

        if min_id is None or max_id is None:
            logger.error("No rows found in public.india_grids_54009. Aborting.")
            sys.exit(1)

        total_chunks = ((max_id - min_id) // CHUNK_SIZE) + 1
        logger.info(
            "Grid range: %s..%s | total_grids=%s | chunks=%s (chunk_size=%s)",
            min_id,
            max_id,
            total_grids,
            total_chunks,
            CHUNK_SIZE,
        )

        def run_chunked(sql_name, extra_params=None):
            sql_path = os.path.join(sql_dir, sql_name)
            chunk_index = 0
            for start_id in range(min_id, max_id + 1, CHUNK_SIZE):
                end_id = min(start_id + CHUNK_SIZE - 1, max_id)
                params = {"grid_id_min": start_id, "grid_id_max": end_id}
                if extra_params:
                    params.update(extra_params)

                chunk_index += 1
                progress_pct = (chunk_index / total_chunks) * 100.0
                logger.info(
                    "Chunk %s: %s/%s (%.1f%%) grid_id %s..%s",
                    sql_name,
                    chunk_index,
                    total_chunks,
                    progress_pct,
                    start_id,
                    end_id,
                )

                with conn.cursor() as cursor:
                    execute_sql_file(cursor, sql_path, params=params)
                conn.commit()

                # Optional: memory cleanup only every N chunks
                if chunk_index % 20 == 0:
                    perform_memory_cleanup(f"{sql_name} [{start_id}-{end_id}]")

        run_chunked("03_zonal_pop_count_chunked.sql")
        run_chunked("04_zonal_built_up_chunked.sql")
        
        # Compute urban_pressure after pop/built
        with conn.cursor() as cursor:
            execute_sql_file(
                cursor,
                os.path.join(sql_dir, "05_compute_urban_pressure.sql"),
                params={"pd_sat": PD_SAT},
            )
        conn.commit()
        perform_memory_cleanup("05_compute_urban_pressure.sql")

        # Now reinforced_pressure
        run_chunked(
            "06_compute_reinforced_pressure_chunked.sql",
            extra_params={"neighbor_radius": NEIGHBOR_RADIUS},
        )

        # Finally classify
        with conn.cursor() as cursor:
            execute_sql_file(cursor, os.path.join(sql_dir, "07_classify_urban_class.sql"))
        conn.commit()
        perform_memory_cleanup("07_classify_urban_class.sql")

    elapsed = time.time() - start_time
    logger.info("Urban pressure run completed in %.2f seconds", elapsed)
    logger.info("Full log saved to: %s", log_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        logger.error("Fatal error: %s", exc, exc_info=True)
        sys.exit(1)
