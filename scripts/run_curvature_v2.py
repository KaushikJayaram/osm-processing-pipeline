#!/usr/bin/env python3

import os
import time
import logging
from datetime import datetime

import psycopg2
from dotenv import load_dotenv


def setup_logging():
    log_dir = "logs"
    os.makedirs(log_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"curvature_v2_{timestamp}.log")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file, mode="a", encoding="utf-8"),
            logging.StreamHandler(),
        ],
    )

    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized. Log file: {log_file}")
    return logger, log_file


logger, log_file = setup_logging()


def execute_sql_file(cursor, filepath: str) -> None:
    logger.info(f"[curvature_v2] Executing {os.path.basename(filepath)}")
    start = time.time()
    with open(filepath, "r", encoding="utf-8") as f:
        sql = f.read()
    cursor.execute(sql)
    elapsed = time.time() - start
    logger.info(f"[curvature_v2] Finished {os.path.basename(filepath)} in {elapsed:.2f}s")


def run_curvature_v2():
    load_dotenv(override=True)

    db_name = os.getenv("DB_NAME")
    db_user = os.getenv("DB_USER")
    db_password = os.getenv("DB_PASSWORD")
    db_host = os.getenv("DB_HOST", "localhost")
    db_port = int(os.getenv("DB_PORT", "5432"))

    required = {"DB_NAME": db_name, "DB_USER": db_user, "DB_PASSWORD": db_password}
    missing = [k for k, v in required.items() if not v]
    if missing:
        raise RuntimeError(f"Missing required env vars: {', '.join(missing)}")

    sql_dir = os.path.join("sql", "road_curvature_v2")
    sql_files = [
        "00_schema.sql",
        "01_prepare_inputs.sql",
        "02_compute_vertex_angles.sql",
        "03_classify_radius_and_segment_meters.sql",
        "04_conflict_zone_suppression.sql",
        "05_aggregate_to_way.sql",
        # Intentionally not run by default:
        # "06_optional_update_osm_all_roads.sql",
    ]

    logger.info("[curvature_v2] Starting curvature v2 mini-module...")
    logger.info(f"[curvature_v2] DB: {db_host}:{db_port}/{db_name} user={db_user}")
    logger.info(f"[curvature_v2] SQL dir: {sql_dir}")

    conn = psycopg2.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port,
    )
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            for name in sql_files:
                path = os.path.join(sql_dir, name)
                if not os.path.exists(path):
                    raise FileNotFoundError(f"SQL file not found: {path}")
                execute_sql_file(cur, path)
                conn.commit()

        logger.info("[curvature_v2] Completed successfully.")
        logger.info(f"[curvature_v2] Full log saved to: {log_file}")
    except Exception:
        conn.rollback()
        logger.exception("[curvature_v2] Failed; rolled back current transaction.")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    run_curvature_v2()


