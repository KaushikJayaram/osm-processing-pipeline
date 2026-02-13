#!/usr/bin/env python3

import os
import sys
import time
import logging
import subprocess
import argparse
import gc
from datetime import datetime

import psycopg
import psutil
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
# Tunable parameters
# ----------------------------------------------------------------------------
# Default bounds (all India)
DEFAULT_LAT_MIN = 6.5
DEFAULT_LAT_MAX = 35.5
DEFAULT_LON_MIN = 68.0
DEFAULT_LON_MAX = 97.5

# Test bounds (matched with urban_pressure_run.py)
TEST_LAT_MIN = 12.0
TEST_LAT_MAX = 15.0
TEST_LON_MIN = 75.0
TEST_LON_MAX = 79.0

# Thresholds (to be tuned)
HILL_RELIEF_THRESHOLD = 100.0  # Example value (relief threshold)

# Raster file paths
RELIEF_RASTER_PATH = resolve_path(
    "data/DEM_data/dem_india_full_120m_nd_relief_smoothed.tif"
)

RELIEF_TABLE = "public.rs_relief_1km_120m"

RASTER_TILE_SIZE = 128
CHUNK_SIZE = 20000

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"hill_scenery_run_{timestamp}.log")

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

def columns_exist(conn, schema, table, columns):
    with conn.cursor() as cursor:
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
              AND column_name = ANY(%s);
            """,
            (schema, table, columns),
        )
        found = {row[0] for row in cursor.fetchall()}
    missing = [col for col in columns if col not in found]
    return missing

def execute_sql_file(cursor, filepath, params=None):
    logger.info("Executing SQL file: %s", os.path.basename(filepath))
    with open(filepath, "r", encoding="utf-8") as file:
        sql_query = file.read()

    if params:
        for key, value in params.items():
            sql_query = sql_query.replace(f":{key}", str(value))

    cursor.execute(sql_query)

def import_raster(table_name, raster_path, db_config):
    if not os.path.exists(raster_path):
        logger.warning(f"Raster file not found: {raster_path}. Skipping import.")
        return

    # -s 3857 : Source is Pseudo-Mercator (Verified via gdalinfo)
    # -I : Create spatial index
    # -C : Apply constraints
    # -M : Vacuum analyze
    # -t : Tile size
    # -N : NoData value
    cmd = (
        f'raster2pgsql -s 3857 -I -C -M -t {RASTER_TILE_SIZE}x{RASTER_TILE_SIZE} '
        f'-N -9999 "{raster_path}" {table_name} | '
        f'psql -d {db_config["name"]} -U {db_config["user"]} '
        f'-h {db_config["host"]} -p {db_config["port"]}'
    )

    env = os.environ.copy()
    if db_config.get("password"):
        env["PGPASSWORD"] = db_config["password"]

    logger.info("Importing raster to %s (EPSG:3857, NoData=-9999)", table_name)
    logger.info("Raster import command: %s", cmd)
    subprocess.run(cmd, shell=True, check=True, env=env)
    logger.info("Raster import completed for %s", table_name)

def parse_args():
    parser = argparse.ArgumentParser(
        description="Hill scenery pipeline runner with bbox selection."
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


def get_osm_id_range(conn, base_params):
    query = """
        SELECT COUNT(*), MIN(osm_id), MAX(osm_id)
        FROM osm_all_roads
        WHERE bikable_road = TRUE
          AND geometry && ST_MakeEnvelope(%(lon_min)s, %(lat_min)s, %(lon_max)s, %(lat_max)s, 4326)
    """
    with conn.cursor() as cursor:
        cursor.execute(query, base_params)
        total, min_id, max_id = cursor.fetchone()
    return total, min_id, max_id

def create_roads_grid_mapping(conn, base_params, table_name="public.osm_all_roads_grid"):
    logger.info("Creating osm_all_roads_grid mapping table...")
    with conn.cursor() as cursor:
        cursor.execute(f"DROP TABLE IF EXISTS {table_name};")
        cursor.execute(
            f"""
            CREATE UNLOGGED TABLE {table_name} AS
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
            f"CREATE INDEX IF NOT EXISTS idx_osm_all_roads_grid_grid_id "
            f"ON {table_name} (grid_id);"
        )
        cursor.execute(
            f"CREATE INDEX IF NOT EXISTS idx_osm_all_roads_grid_osm_id "
            f"ON {table_name} (osm_id);"
        )
    logger.info("Road-to-grid mapping table created.")

def get_grid_id_range(conn, table_name="public.osm_all_roads_grid"):
    query = f"""
        SELECT COUNT(*), MIN(grid_id), MAX(grid_id)
        FROM {table_name}
    """
    with conn.cursor() as cursor:
        cursor.execute(query)
        total, min_id, max_id = cursor.fetchone()
    return total, min_id, max_id

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

    sql_dir = resolve_path("sql/road_scenery/hill_v2")

    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        conn.autocommit = False
        
        missing_cols = columns_exist(
            conn,
            "public",
            "osm_all_roads",
            ["geom_3857", "length_geom_3857"],
        )
        if missing_cols:
            logger.warning(
                "Missing columns on public.osm_all_roads: %s. "
                "Run the one-time backfill before hill relief sampling.",
                ", ".join(missing_cols),
            )

        # 1. Import Relief Raster
        if not table_exists(conn, "public", "rs_relief_1km_120m"):
            logger.info("Relief raster table not found. Starting import.")
            import_raster(RELIEF_TABLE, RELIEF_RASTER_PATH, db_config)
        else:
            logger.info("Raster table %s exists. Skipping.", RELIEF_TABLE)

        # 2. Session tuning + autovacuum control (high ROI for large updates)
        with conn.cursor() as cursor:
            cursor.execute("SET synchronous_commit = OFF;")
            cursor.execute("SET work_mem = '256MB';")
            cursor.execute("SET maintenance_work_mem = '1GB';")
            cursor.execute("ALTER TABLE public.osm_all_roads SET (autovacuum_enabled = false);")
        conn.commit()

        base_params = {
            "hill_relief_threshold": HILL_RELIEF_THRESHOLD,
            "lat_min": lat_min,
            "lat_max": lat_max,
            "lon_min": lon_min,
            "lon_max": lon_max,
        }

        # 3. Build road-to-grid mapping for spatial chunking (always rebuild)
        grid_table = "public.osm_all_roads_grid"
        create_roads_grid_mapping(conn, base_params, table_name=grid_table)

        # 4. Run SQL Pipeline
        # Map SQL files to required raster tables (if any)
        sql_steps = [
            ("02_add_hill_columns.sql", None, False),
            ("03_compute_relief_from_raster.sql", RELIEF_TABLE, True),  # True = Chunked
            ("04_compute_hill_signal.sql", None, False),
            ("05_finalize_classification.sql", None, False),
        ]

        for sql_file, required_table, is_chunked in sql_steps:
            filepath = os.path.join(sql_dir, sql_file)
            if not os.path.exists(filepath):
                logger.error("SQL file missing: %s", filepath)
                continue

            if required_table:
                schema, table = required_table.split('.')
                if not table_exists(conn, schema, table):
                    logger.warning(f"Required table {required_table} missing. Skipping {sql_file}.")
                    continue

            if is_chunked:
                logger.info("Starting chunked execution for %s", sql_file)
                total, min_id, max_id = get_grid_id_range(conn, table_name=grid_table)
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
                        with conn.cursor() as cursor:
                            execute_sql_file(cursor, filepath, params=chunk_params)
                        conn.commit()
                    except Exception as e:
                        conn.rollback()
                        logger.error("Error executing %s: %s", sql_file, e)
                
            else:
                # Standard execution
                try:
                    with conn.cursor() as cursor:
                        execute_sql_file(cursor, filepath, params=base_params)
                    conn.commit()
                    logger.info("Finished %s", sql_file)
                except Exception as e:
                    conn.rollback()
                    logger.error(f"Error executing {sql_file}: {e}")

        # Re-enable autovacuum after batch run
        with conn.cursor() as cursor:
            cursor.execute("ALTER TABLE public.osm_all_roads RESET (autovacuum_enabled);")
        conn.commit()

    logger.info("Hill scenery run completed.")

if __name__ == "__main__":
    main()
