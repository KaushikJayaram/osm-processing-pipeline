#!/usr/bin/env python3

import sys
import os
import time
import logging
import gc
import psutil
from datetime import datetime
from dotenv import load_dotenv

from scripts.write_tags_to_pbf_2 import write_tags_to_pbf as write_tags_to_pbf_2
from scripts.download_osm_pbf import download_osm_pbf
from scripts.import_into_postgres import import_into_postgres
from scripts.add_custom_tags import add_custom_tags

# ============================================================================
# PATH RESOLUTION
# ============================================================================

def get_script_base_dir():
    """Get the base directory (osm-file-processing-v2) where main.py is located."""
    # Get the directory where this script (main.py) is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # main.py is in osm-file-processing-v2/, so return script_dir directly
    return script_dir

def resolve_path(path, base_dir=None):
    """Resolve a path relative to the script base directory if it's relative."""
    if base_dir is None:
        base_dir = get_script_base_dir()
    
    # If path is already absolute, return as-is
    if os.path.isabs(path):
        return path
    
    # If path starts with ./, remove it
    if path.startswith('./'):
        path = path[2:]
    
    # Join with base directory
    return os.path.join(base_dir, path)

# ============================================================================
# CONFIGURATION
# ============================================================================

# Pipeline Section Toggles
# Set to True/False to enable/disable sections
PIPELINE_SECTIONS = {
    'download_osm': False,           # Downloads OSM PBF from Geofabrik
                                     # Script: download_osm_pbf.py
    'import_to_postgres': False,     # Imports PBF into PostgreSQL using osm2pgsql
                                     # Script: import_into_postgres.py
                                     # Lua: Lua3_RouteProcessing_with_curvature.lua
    'add_custom_tags': True,          # Full custom tags pipeline
                                     # Script: add_custom_tags.py
                                     # Includes: road classification, curvature v2, scenery, rsbikeaccess, 
                                     #           intersection speed degradation v2, persona scoring
    'write_pbf': True,                # Writes augmented attributes back to PBF
                                     # Script: write_tags_to_pbf_2.py
}

# Environment Configuration
load_dotenv(override=True)

# Get base directory for path resolution
BASE_DIR = get_script_base_dir()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = int(os.getenv("DB_PORT", "5432"))

# Resolve paths relative to script location
NEW_PBF_PATH = resolve_path(os.getenv("NEW_PBF_PATH", "./osm_pbf_inputs/osm_pbf_new/india-latest.osm.pbf"), BASE_DIR)
OUTPUT_PBF_PATH = resolve_path(os.getenv("OUTPUT_PBF_PATH", "./osm_pbf_augmented_output/india-latest-augmented.osm.pbf"), BASE_DIR)
STYLE_LUA_SCRIPT = resolve_path("./scripts/Lua3_RouteProcessing_with_curvature.lua", BASE_DIR)

# Validate required environment variables
required_vars = ["DB_NAME", "DB_USER", "DB_PASSWORD"]
missing_vars = [var for var in required_vars if not os.getenv(var)]
if missing_vars:
    print(f"Error: Missing required environment variables: {', '.join(missing_vars)}")
    print("Please check your .env file")
    sys.exit(1)

# ============================================================================
# LOGGING SETUP
# ============================================================================

def setup_logging():
    """Setup logging to both console and file."""
    # Resolve log directory relative to script location
    log_dir = resolve_path("logs", BASE_DIR)
    os.makedirs(log_dir, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"main_pipeline_{timestamp}.log")
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, mode='a', encoding='utf-8'),
            logging.StreamHandler()
        ]
    )
    
    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized. Log file: {log_file}")
    return logger, log_file

logger, log_file = setup_logging()

# ============================================================================
# PIPELINE FUNCTIONS
# ============================================================================

def perform_pipeline_cleanup(step_name="Unknown"):
    """Performs lightweight cleanup between major pipeline steps."""
    logger.info(f"[PIPELINE_CLEANUP] Starting cleanup after {step_name}...")
    
    collected = gc.collect()
    logger.info(f"[PIPELINE_CLEANUP] Python GC collected {collected} objects")
    
    try:
        process = psutil.Process(os.getpid())
        mem_usage = process.memory_info().rss / (1024 * 1024 * 1024)  # GB
        logger.info(f"[PIPELINE_CLEANUP] Current memory usage: {mem_usage:.2f} GB")
    except Exception as e:
        logger.warning(f"[PIPELINE_CLEANUP] Could not get memory usage: {e}")

def run_pipeline():
    """Main pipeline execution."""
    start_time = time.time()
    
    db_config = {
        "host": DB_HOST,
        "name": DB_NAME,
        "user": DB_USER,
        "password": DB_PASSWORD,
        "port": DB_PORT,
        "new_pbf_path": NEW_PBF_PATH
    }
    
    # Section 1: Download OSM PBF
    if PIPELINE_SECTIONS['download_osm']:
        logger.info("=" * 80)
        logger.info("Section 1: Downloading OSM PBF")
        logger.info("=" * 80)
        step_start = time.time()
        
        url = "https://download.geofabrik.de/asia/india-latest.osm.pbf"
        download_osm_pbf(url, NEW_PBF_PATH)
        
        elapsed = time.time() - step_start
        logger.info(f"Section 1 completed in {elapsed:.2f} seconds")
        perform_pipeline_cleanup("Section 1: Download OSM PBF")
    
    # Section 2: Import to PostgreSQL
    if PIPELINE_SECTIONS['import_to_postgres']:
        logger.info("=" * 80)
        logger.info("Section 2: Importing OSM PBF into PostgreSQL")
        logger.info("=" * 80)
        step_start = time.time()
        
        import_into_postgres(
            pbf_file=NEW_PBF_PATH,
            db_config=db_config,
            style_lua_script=STYLE_LUA_SCRIPT
        )
        
        elapsed = time.time() - step_start
        logger.info(f"Section 2 completed in {elapsed:.2f} seconds")
        perform_pipeline_cleanup("Section 2: Import to PostgreSQL")
    
    # Section 3: Add Custom Tags
    if PIPELINE_SECTIONS['add_custom_tags']:
        logger.info("=" * 80)
        logger.info("Section 3: Adding Custom Tags")
        logger.info("=" * 80)
        step_start = time.time()
        
        add_custom_tags(db_config)
        
        elapsed = time.time() - step_start
        logger.info(f"Section 3 completed in {elapsed:.2f} seconds")
        perform_pipeline_cleanup("Section 3: Add Custom Tags")
    
    # Section 4: Write Augmented PBF
    if PIPELINE_SECTIONS['write_pbf']:
        logger.info("=" * 80)
        logger.info("Section 4: Writing Augmented PBF")
        logger.info("=" * 80)
        step_start = time.time()
        
        write_tags_to_pbf_2(db_config, OUTPUT_PBF_PATH)
        
        elapsed = time.time() - step_start
        logger.info(f"Section 4 completed in {elapsed:.2f} seconds")
        perform_pipeline_cleanup("Section 4: Write PBF")
    
    total_elapsed = time.time() - start_time
    logger.info("=" * 80)
    logger.info(f"Pipeline completed in {total_elapsed:.2f} seconds")
    logger.info("=" * 80)

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def main():
    overall_start_time = time.time()
    
    logger.info("=" * 80)
    logger.info("Pipeline execution started")
    logger.info(f"Log file: {log_file}")
    logger.info("=" * 80)
    
    logger.info("Configuration:")
    logger.info(f"  DB Host: {DB_HOST}")
    logger.info(f"  DB Name: {DB_NAME}")
    logger.info(f"  DB User: {DB_USER}")
    logger.info(f"  DB Port: {DB_PORT}")
    logger.info(f"  Input PBF: {NEW_PBF_PATH}")
    logger.info(f"  Output PBF: {OUTPUT_PBF_PATH}")
    logger.info(f"  Lua Script: {STYLE_LUA_SCRIPT}")
    
    logger.info("\nEnabled Pipeline Sections:")
    for section, enabled in PIPELINE_SECTIONS.items():
        status = "✓ ENABLED" if enabled else "✗ DISABLED"
        logger.info(f"  {section}: {status}")
    logger.info("")
    
    run_pipeline()
    
    total_time = time.time() - overall_start_time
    logger.info("=" * 80)
    logger.info(f"Total execution time: {total_time:.2f} seconds")
    logger.info(f"Full log saved to: {log_file}")
    logger.info("=" * 80)

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        error_msg = f"Fatal error: {str(e)}"
        print(error_msg)
        logger.error(error_msg, exc_info=True)
        sys.exit(1)
