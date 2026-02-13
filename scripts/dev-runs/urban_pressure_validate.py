#!/usr/bin/env python3

import os
import sys
import logging
from datetime import datetime

import psycopg
from dotenv import load_dotenv


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


def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"urban_pressure_validate_{timestamp}.log")

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

    sql_path = resolve_path("sql/urban_pressure/99_validation_queries.sql")
    with open(sql_path, "r", encoding="utf-8") as file:
        sql_text = file.read()

    statements = [s.strip() for s in sql_text.split(";") if s.strip()]

    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        with conn.cursor() as cursor:
            for idx, statement in enumerate(statements, start=1):
                logger.info("Running validation statement %d/%d", idx, len(statements))
                cursor.execute(statement)
                try:
                    rows = cursor.fetchall()
                    logger.info("Result rows: %s", rows)
                except psycopg.ProgrammingError:
                    logger.info("No result rows for this statement.")

    logger.info("Validation completed. Full log saved to: %s", log_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        logger.error("Fatal error: %s", exc, exc_info=True)
        sys.exit(1)
