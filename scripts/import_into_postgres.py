#!/usr/bin/env python3

import os
import subprocess
from datetime import datetime
import logging

# Setup logging to both console and file
def setup_logging():
    """Setup logging to both console and file."""
    # Create logs directory if it doesn't exist
    log_dir = "logs"
    os.makedirs(log_dir, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"import_into_postgres_{timestamp}.log")
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, mode='a', encoding='utf-8'),
            logging.StreamHandler()  # Also print to console
        ]
    )
    
    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized. Log file: {log_file}")
    return logger, log_file

# Initialize logger at module level
logger, log_file = setup_logging()

def log_print(message, level='info'):
    """Print to console and log to file."""
    print(message)
    if level == 'info':
        logger.info(message)
    elif level == 'warning':
        logger.warning(message)
    elif level == 'error':
        logger.error(message)
    elif level == 'debug':
        logger.debug(message)

def table_exists(db_name, db_user, db_host, db_port, db_password, table_name):
    """
    Check if a table exists in the database.
    """
    env = os.environ.copy()
    if db_password:
        env["PGPASSWORD"] = db_password

    cmd = [
        "psql",
        "-U", db_user,
        "-h", db_host,
        "-p", str(db_port),
        "-d", db_name,
        "-t",  # Tuple-only output
        "-c", f"SELECT to_regclass('{table_name}');"
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, env=env)

    # If the table exists, the query will return the table name. Otherwise, it returns an empty string.
    return result.stdout.strip() == table_name


def import_into_postgres(pbf_file, db_config, style_lua_script):
    """
    Imports an OSM PBF file into Postgres using osm2pgsql flex mode.
    Before that, it creates the postgis, postgis_raster and hstore extensions if they don't exist.
    """

    db_name = db_config.get("name", "ridesense_db")
    db_user = db_config.get("user", "postgres")
    db_host = db_config.get("host", "localhost")
    db_port = str(db_config.get("port", 5432))  # **Ensure port is a string**
    db_password = db_config.get("password", None)

    # Prepare environment to pass password automatically
    env = os.environ.copy()
    if db_password:
        env["PGPASSWORD"] = db_password

    # 1. Create PostGIS, RASTER and HSTORE extensions if not present
    log_print("[import_into_postgres] Ensuring PostGIS, PostGIS Raster, and HSTORE extensions exist...")

    # CREATE EXTENSION postgis
    cmd_create_postgis = [
        "psql",
        "-U", db_user,
        "-h", db_host,
        "-p", db_port,
        "-d", db_name,
        "-c", "CREATE EXTENSION IF NOT EXISTS postgis;"
    ]
    subprocess.run(cmd_create_postgis, check=True, env=env)

    # CREATE EXTENSION postgis_raster (Fixed db_port conversion)
    cmd_create_postgis_raster = [
        "psql",
        "-U", db_user,
        "-h", db_host,
        "-p", db_port,  # **Ensuring port is a string**
        "-d", db_name,
        "-c", "CREATE EXTENSION IF NOT EXISTS postgis_raster;"
    ]
    subprocess.run(cmd_create_postgis_raster, check=True, env=env)

    # CREATE EXTENSION hstore
    cmd_create_hstore = [
        "psql",
        "-U", db_user,
        "-h", db_host,
        "-p", db_port,
        "-d", db_name,
        "-c", "CREATE EXTENSION IF NOT EXISTS hstore;"
    ]
    subprocess.run(cmd_create_hstore, check=True, env=env)

    log_print("[import_into_postgres] PostGIS, PostGIS Raster, and HSTORE extensions are set up.")

    # Check if the target table already exists - this is useful for reruns to not reimport when the local db exists already
    #if table_exists(db_name, db_user, db_host, db_port, db_password, 'rs_forest'):
    #    log_print("[import_into_postgres] 'rs_forest' table already exists. Skipping import.")
    #    return

    # 2. Run osm2pgsql to import the PBF
    log_print("[import_into_postgres] Starting osm2pgsql import...")
    cmd_osm2pgsql = [
        "osm2pgsql",
        "-c",
        "-d", db_name,
        "-U", db_user,
        "-H", db_host,
        "-P", db_port,
        "--slim",
        # --hstore is not used with flex output, so it's removed.
        "--cache", "16384",  # Add cache for better performance, in MB. Adjust based on your system's RAM.
        #"--verbose",  # Add verbose for more detailed output
        "--output=flex",
        f"--style={style_lua_script}",
        pbf_file
    ]

    log_print(f"[import_into_postgres] Running command: {' '.join(cmd_osm2pgsql)}")
    process = subprocess.Popen(cmd_osm2pgsql, env=env)
    try:
        process.wait()
    except KeyboardInterrupt:
        log_print("\n[import_into_postgres] Keyboard interrupt received, terminating osm2pgsql...", level='warning')
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            log_print("[import_into_postgres] osm2pgsql did not terminate gracefully, killing it.", level='warning')
            process.kill()
        log_print("[import_into_postgres] Process terminated.", level='warning')
        # Re-raise the exception to ensure the script exits
        raise

    if process.returncode != 0:
        log_print(f"[import_into_postgres] Import failed with return code {process.returncode}", level='error')
        raise subprocess.CalledProcessError(process.returncode, cmd_osm2pgsql)

    log_print("[import_into_postgres] Import completed successfully!")
