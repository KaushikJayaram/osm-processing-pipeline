#!/usr/bin/env python3

import sys
import os
import time
import logging
from datetime import datetime
from dotenv import load_dotenv

# Setup logging to both console and file
def setup_logging():
    """Setup logging to both console and file."""
    # Create logs directory if it doesn't exist
    log_dir = "logs"
    os.makedirs(log_dir, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"main_pipeline_{timestamp}.log")
    
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

# Load environment variables from .env file
load_dotenv(override=True)

# -------------------------------------------------------------------------------
# Import helper functions from scripts/
# -------------------------------------------------------------------------------
from scripts.write_tags_to_pbf_2 import write_tags_to_pbf as write_tags_to_pbf_2
from scripts.download_osm_pbf import download_osm_pbf
from scripts.import_into_postgres import import_into_postgres
from scripts.add_custom_tags import add_custom_tags
from scripts.write_tags_to_pbf import write_tags_to_pbf

# -------------------------------------------------------------------------------
# 1. CONFIG SECTION
# -------------------------------------------------------------------------------
# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = int(os.getenv("DB_PORT", "5432"))

# Paths to input and output files
NEW_PBF_PATH = os.getenv("NEW_PBF_PATH", "./osm_pbf_inputs/osm_pbf_new/india-latest.osm.pbf")
OUTPUT_PBF_PATH = os.getenv("OUTPUT_PBF_PATH", "./osm_pbf_augmented_output/india-latest-augmented.osm.pbf")

SQL_SCRIPTS_FOLDER = "./sql"

# Path to Lua script for osm2pgsql flex mode
STYLE_LUA_SCRIPT = "./scripts/Lua2_RouteProcessing.lua"

# Validate required environment variables
required_vars = ["DB_NAME", "DB_USER", "DB_PASSWORD"]
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    print(f"Error: Missing required environment variables: {', '.join(missing_vars)}")
    print("Please check your .env file")
    sys.exit(1)

# -------------------------------------------------------------------------------
# 2. PIPELINE FUNCTION
# -------------------------------------------------------------------------------
import gc
import psutil
import os

# ... existing imports ...

def perform_pipeline_cleanup(db_config, step_name="Unknown"):
    """
    Performs cleanup between major pipeline steps.
    """
    logger.info(f"[PIPELINE_CLEANUP] Starting cleanup after {step_name}...")
    
    # Python garbage collection
    collected = gc.collect()
    logger.info(f"[PIPELINE_CLEANUP] Python GC collected {collected} objects")
    
    # Log memory usage
    try:
        process = psutil.Process(os.getpid())
        mem_usage = process.memory_info().rss / (1024 * 1024 * 1024)  # GB
        logger.info(f"[PIPELINE_CLEANUP] Current memory usage: {mem_usage:.2f} GB")
    except Exception as e:
        logger.warning(f"[PIPELINE_CLEANUP] Could not get memory usage: {e}")

def from_scratch_pipeline():
    """
    Build a fresh augmented PBF from scratch.
    """
    print("[DEBUG] Entered from_scratch_pipeline()")
    logger.info("[DEBUG] Entered from_scratch_pipeline()")
    start_time = time.time()

    print("Step 1: Downloading OSM PBF (if needed)...")
    logger.info("Step 1: Downloading OSM PBF (if needed)...")
    step_start = time.time()
    url = "https://download.geofabrik.de/asia/india-latest.osm.pbf"
    #download_osm_pbf(url, NEW_PBF_PATH)
    elapsed = time.time() - step_start
    print(f"Step 1 completed in {elapsed:.2f} seconds")
    logger.info(f"Step 1 completed in {elapsed:.2f} seconds")
    
    perform_pipeline_cleanup(None, "Step 1: Download OSM PBF")

    print("Step 2: Importing OSM PBF into Postgres...")
    logger.info("Step 2: Importing OSM PBF into Postgres...")
    step_start = time.time()
    db_config = {
        "host": DB_HOST,
        "name": DB_NAME,
        "user": DB_USER,
        "password": DB_PASSWORD,
        "port": DB_PORT,
        "new_pbf_path": NEW_PBF_PATH
    }

    #import_into_postgres(
    #  pbf_file=NEW_PBF_PATH,
    #   db_config=db_config,
    #   style_lua_script=STYLE_LUA_SCRIPT
    #)
    elapsed = time.time() - step_start
    print(f"Step 2 completed in {elapsed:.2f} seconds")
    logger.info(f"Step 2 completed in {elapsed:.2f} seconds")
    
    perform_pipeline_cleanup(db_config, "Step 2: Import into Postgres")

    print("Step 3: Adding custom tags to database...")
    logger.info("Step 3: Adding custom tags to database...")
    step_start = time.time()
    #add_custom_tags(db_config)
    elapsed = time.time() - step_start
    print(f"Step 3 completed in {elapsed:.2f} seconds")
    logger.info(f"Step 3 completed in {elapsed:.2f} seconds")
    
    perform_pipeline_cleanup(db_config, "Step 3: Add Custom Tags")

    print("Step 4: Writing calculated custom tags to the original PBF...")
    logger.info("Step 4: Writing calculated custom tags to the original PBF...")
    step_start = time.time()
    write_tags_to_pbf_2(db_config, OUTPUT_PBF_PATH)
    elapsed = time.time() - step_start
    print(f"Step 4 completed in {elapsed:.2f} seconds")
    logger.info(f"Step 4 completed in {elapsed:.2f} seconds")

    total_elapsed = time.time() - start_time
    print(f"[DEBUG] Completed from_scratch_pipeline in {total_elapsed:.2f} seconds.")
    logger.info(f"[DEBUG] Completed from_scratch_pipeline in {total_elapsed:.2f} seconds.")


# -------------------------------------------------------------------------------
# 3. MAIN SCRIPT
# -------------------------------------------------------------------------------
def main():
    overall_start_time = time.time()

    logger.info("=" * 80)
    logger.info("Pipeline execution started")
    logger.info(f"Log file: {log_file}")
    logger.info("=" * 80)
    
    print("[DEBUG] main() has started.")
    logger.info("[DEBUG] main() has started.")
    print(f"DB Host: {DB_HOST}")
    logger.info(f"DB Host: {DB_HOST}")
    print(f"DB Name: {DB_NAME}")
    logger.info(f"DB Name: {DB_NAME}")
    print(f"DB User: {DB_USER}")
    logger.info(f"DB User: {DB_USER}")
    print(f"DB Port: {DB_PORT}")
    logger.info(f"DB Port: {DB_PORT}")
    print(f"New PBF Path: {NEW_PBF_PATH}")
    logger.info(f"New PBF Path: {NEW_PBF_PATH}")
    print(f"Output PBF Path: {OUTPUT_PBF_PATH}")
    logger.info(f"Output PBF Path: {OUTPUT_PBF_PATH}")
    print(f"SQL Scripts Folder: {SQL_SCRIPTS_FOLDER}")
    logger.info(f"SQL Scripts Folder: {SQL_SCRIPTS_FOLDER}")
    print(f"Lua Script: {STYLE_LUA_SCRIPT}")
    logger.info(f"Lua Script: {STYLE_LUA_SCRIPT}")
    print("[DEBUG] Configuration read complete.\n")
    logger.info("[DEBUG] Configuration read complete.\n")

    from_scratch_pipeline()

    total_time = time.time() - overall_start_time
    message = f"[DEBUG] main() has finished all tasks. Total execution time: {total_time:.2f} seconds. Exiting now."
    print(message)
    logger.info(message)
    logger.info(f"Full log saved to: {log_file}")
    logger.info("=" * 80)


if __name__ == "__main__":
    message = "[DEBUG] __name__ == '__main__': about to call main()"
    print(message)
    logger.info(message)
    try:
        sys.exit(main())
    except Exception as e:
        error_msg = f"Fatal error in main(): {str(e)}"
        print(error_msg)
        logger.error(error_msg, exc_info=True)
        sys.exit(1)

