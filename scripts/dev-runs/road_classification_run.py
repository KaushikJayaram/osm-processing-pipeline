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
    log_file = os.path.join(log_dir, f"road_classification_run_{timestamp}.log")

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
def execute_sql_file(cursor, filepath, params=None):
    logger.info("Executing SQL file: %s", os.path.basename(filepath))
    with open(filepath, "r", encoding="utf-8") as file:
        sql_query = file.read()

    if params:
        for key in sorted(params.keys(), key=len, reverse=True):
            value = params[key]
            sql_query = sql_query.replace(f":{key}", str(value))

    cursor.execute(sql_query)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Road classification runner with bbox selection."
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

    # Test bounds (match scenery_v2_run.py)
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

    sql_dir = resolve_path("sql/road_classification")
    grid_chunk_size = int(os.getenv("ROAD_CLASSIFICATION_GRID_CHUNK_SIZE", "100"))
    osm_chunk_size = int(os.getenv("ROAD_CLASSIFICATION_OSM_CHUNK_SIZE", "20000"))
    base_params = {
        "lat_min": lat_min,
        "lat_max": lat_max,
        "lon_min": lon_min,
        "lon_max": lon_max,
    }
    sql_files = [
    #    "04_prepare_osm_all_roads_table.sql",
        "06_handle_roads_intersecting_multiple_grids.sql",
        "07_assign_final_road_classification.sql",
    ]

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

        with conn.cursor() as stats_cursor:
            if use_bbox_filter:
                stats_cursor.execute(
                    """
                    SELECT COUNT(*), MIN(grid_id), MAX(grid_id)
                    FROM india_grids
                    WHERE grid_geom && ST_MakeEnvelope(%s, %s, %s, %s, 4326)
                      AND ST_Intersects(grid_geom, ST_MakeEnvelope(%s, %s, %s, %s, 4326));
                    """,
                    (lon_min, lat_min, lon_max, lat_max, lon_min, lat_min, lon_max, lat_max),
                )
            else:
                stats_cursor.execute(
                    "SELECT COUNT(*), MIN(grid_id), MAX(grid_id) FROM india_grids;"
                )
            total_grids, min_id, max_id = stats_cursor.fetchone()

        if min_id is None or max_id is None:
            raise RuntimeError("No grids found in india_grids.")

        total_chunks = ((max_id - min_id) // grid_chunk_size) + 1
        logger.info(
            "Grid range: %s..%s | total_grids=%s | chunks=%s (chunk_size=%s)",
            min_id,
            max_id,
            total_grids,
            total_chunks,
            grid_chunk_size,
        )

        try:
            for sql_file in sql_files:
                filepath = os.path.join(sql_dir, sql_file)
                if sql_file == "06_handle_roads_intersecting_multiple_grids.sql":
                    chunk_index = 0
                    for start_id in range(min_id, max_id + 1, grid_chunk_size):
                        end_id = min(start_id + grid_chunk_size - 1, max_id)
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
                        with conn.cursor() as cursor:
                            execute_sql_file(
                                cursor,
                                filepath,
                                params={
                                    "grid_id_min": start_id,
                                    "grid_id_max": end_id,
                                    **base_params,
                                },
                            )
                        conn.commit()
                elif sql_file == "07_assign_final_road_classification.sql":
                    if use_bbox_filter:
                        with conn.cursor() as cursor:
                            cursor.execute("DROP TABLE IF EXISTS tmp_osm_ids_bbox;")
                            cursor.execute(
                                """
                                CREATE TEMP TABLE tmp_osm_ids_bbox AS
                                SELECT osm_id
                                FROM osm_all_roads
                                WHERE bikable_road = TRUE
                                  AND geometry && ST_MakeEnvelope(%s, %s, %s, %s, 4326)
                                  AND ST_Intersects(geometry, ST_MakeEnvelope(%s, %s, %s, %s, 4326));
                                """,
                                (lon_min, lat_min, lon_max, lat_max, lon_min, lat_min, lon_max, lat_max),
                            )

                    with conn.cursor() as stats_cursor:
                        if use_bbox_filter:
                            stats_cursor.execute(
                                "SELECT MIN(osm_id), MAX(osm_id) FROM tmp_osm_ids_bbox;"
                            )
                        else:
                            stats_cursor.execute(
                                "SELECT MIN(osm_id), MAX(osm_id) FROM osm_all_roads WHERE bikable_road = TRUE;"
                            )
                        min_osm, max_osm = stats_cursor.fetchone()

                    if min_osm is None or max_osm is None:
                        raise RuntimeError("No bikable roads found in osm_all_roads.")

                    total_osm_chunks = ((max_osm - min_osm) // osm_chunk_size) + 1
                    logger.info(
                        "OSM range: %s..%s | chunks=%s (chunk_size=%s)",
                        min_osm,
                        max_osm,
                        total_osm_chunks,
                        osm_chunk_size,
                    )

                    osm_id_filter_clause = ""
                    osm_id_filter_clause_r = ""
                    if use_bbox_filter:
                        osm_id_filter_clause = "AND osm_id IN (SELECT osm_id FROM tmp_osm_ids_bbox)"
                        osm_id_filter_clause_r = "AND r.osm_id IN (SELECT osm_id FROM tmp_osm_ids_bbox)"

                    chunk_index = 0
                    for start_id in range(min_osm, max_osm + 1, osm_chunk_size):
                        end_id = min(start_id + osm_chunk_size - 1, max_osm)
                        chunk_index += 1
                        progress_pct = (chunk_index / total_osm_chunks) * 100.0
                        logger.info(
                            "[%s] Chunk %s/%s (%.1f%%) osm_id %s..%s",
                            sql_file,
                            chunk_index,
                            total_osm_chunks,
                            progress_pct,
                            start_id,
                            end_id,
                        )
                        with conn.cursor() as cursor:
                            execute_sql_file(
                                cursor,
                                filepath,
                                params={
                                    "osm_id_min": start_id,
                                    "osm_id_max": end_id,
                                    "osm_id_filter_clause": osm_id_filter_clause,
                                    "osm_id_filter_clause_r": osm_id_filter_clause_r,
                                },
                            )
                        conn.commit()
                else:
                    with conn.cursor() as cursor:
                        execute_sql_file(cursor, filepath)
                    conn.commit()

            # One-time finalize step after 06/07 complete
            finalize_path = os.path.join(sql_dir, "08_finalize_road_classification_one_time.sql")
            if os.path.exists(finalize_path):
                logger.info("Executing one-time finalize SQL: %s", os.path.basename(finalize_path))
                with conn.cursor() as cursor:
                    execute_sql_file(cursor, finalize_path)
                conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            with conn.cursor() as cursor:
                cursor.execute("ALTER TABLE public.osm_all_roads RESET (autovacuum_enabled);")

    elapsed = time.time() - start_time
    logger.info("Road classification run completed in %.2f seconds", elapsed)
    logger.info("Full log saved to: %s", log_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        logger.error("Fatal error: %s", exc, exc_info=True)
        sys.exit(1)
