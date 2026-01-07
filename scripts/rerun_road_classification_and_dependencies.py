#!/usr/bin/env python3
"""
Standalone script to re-run road classification and all dependent processes:
1. Road Classification (07_assign_final_road_classification.sql)
2. Intersection Density v2 (speed degradation)
3. Persona Scoring
4. Write augmented PBF

This script assumes:
- OSM data is already imported into PostgreSQL
- Grid data (india_grids) already exists
- All required columns already exist in osm_all_roads table
"""

import os
import sys
from typing import Dict, Any
from datetime import datetime
import logging
import subprocess
import time

import psycopg
from dotenv import load_dotenv

def get_script_base_dir():
    """Get the base directory (osm-file-processing-v2) where the script is located."""
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Script is in osm-file-processing-v2/scripts/, so go up one level
    base_dir = os.path.dirname(script_dir)
    return base_dir

# Setup logging
def setup_logging():
    """Setup logging to both console and file."""
    base_dir = get_script_base_dir()
    log_dir = os.path.join(base_dir, "logs")
    os.makedirs(log_dir, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"rerun_road_classification_{timestamp}.log")
    
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

def log_print(message, level='info'):
    """Print to console and log to file."""
    print(message)
    if level == 'info':
        logger.info(message)
    elif level == 'warning':
        logger.warning(message)
    elif level == 'error':
        logger.error(message)

# ============================================================================
# SECTION TOGGLES - Set to True/False to enable/disable pipeline steps
# ============================================================================
PIPELINE_SECTIONS = {
    'road_classification': False,      # Step 1: Road Classification
                                       # SQL: 07_assign_final_road_classification.sql
    'intersection_density': False,     # Step 2: Intersection Density v2 (Speed Degradation)
                                       # SQL: 00_schema_v2.sql, 01_find_and_categorize_intersections_v2.sql,
                                       #      02_map_intersections_to_ways_v2.sql, 03_calculate_base_degradation_v2.sql,
                                       #      04_calculate_final_degradation_v2.sql
    'persona_scoring': False,          # Step 3: Persona Scoring
                                       # SQL: 01_compute_persona_base_scores_simplified_all_india.sql
    'write_pbf': True,                 # Step 4: Write Augmented PBF
                                       # Script: write_tags_to_pbf_2.py
}

def get_db_config():
    """Load database configuration from .env file."""
    load_dotenv()
    
    base_dir = get_script_base_dir()
    
    # Resolve PBF path relative to script base directory
    default_pbf_path = os.path.join(base_dir, "osm_pbf_inputs", "osm_pbf_new", "india-latest.osm.pbf")
    pbf_path_from_env = os.getenv("NEW_PBF_PATH", default_pbf_path)
    
    # If path from env is relative, make it relative to base_dir
    if not os.path.isabs(pbf_path_from_env):
        pbf_path_from_env = os.path.join(base_dir, pbf_path_from_env.lstrip('./'))
    
    db_config = {
        'host': os.getenv("DB_HOST", "localhost"),
        'name': os.getenv("DB_NAME"),
        'user': os.getenv("DB_USER"),
        'password': os.getenv("DB_PASSWORD"),
        'port': int(os.getenv("DB_PORT", "5432")),
        'new_pbf_path': pbf_path_from_env,
    }
    
    required = ['name', 'user', 'password']
    missing = [k for k in required if not db_config.get(k)]
    if missing:
        log_print(f"[ERROR] Missing required environment variables: {', '.join(missing)}", level='error')
        log_print("Please set these in your .env file", level='error')
        sys.exit(1)
    
    return db_config

def execute_sql_file(cursor, sql_file_path):
    """Execute a SQL file using psycopg cursor."""
    if not os.path.exists(sql_file_path):
        log_print(f"[ERROR] SQL file not found: {sql_file_path}", level='error')
        raise FileNotFoundError(f"SQL file not found: {sql_file_path}")
    
    log_print(f"[EXECUTING] {sql_file_path}")
    start_time = time.time()
    
    with open(sql_file_path, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    try:
        # Execute SQL content (may contain multiple statements)
        cursor.execute(sql_content)
        elapsed = time.time() - start_time
        log_print(f"[COMPLETED] {sql_file_path} (took {elapsed:.2f} seconds)")
    except Exception as e:
        elapsed = time.time() - start_time
        log_print(f"[ERROR] Failed to execute {sql_file_path} after {elapsed:.2f} seconds", level='error')
        log_print(f"[ERROR] Error: {str(e)}", level='error')
        raise

def run_road_classification(db_config):
    """Run road classification SQL scripts."""
    log_print("\n" + "="*80)
    log_print("STEP 1: Road Classification")
    log_print("="*80)
    
    base_dir = get_script_base_dir()
    sql_dir = os.path.join(base_dir, "sql", "road_classification")
    
    # Only run the final classification script (07_assign_final_road_classification.sql)
    # This assumes all prerequisite steps (grids, etc.) are already done
    road_classification_script = os.path.join(sql_dir, "07_assign_final_road_classification.sql")
    
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    try:
        execute_sql_file(cursor, road_classification_script)
        conn.commit()
        log_print("[SUCCESS] Road classification completed")
    except Exception as e:
        conn.rollback()
        log_print(f"[ERROR] Road classification failed: {str(e)}", level='error')
        raise
    finally:
        cursor.close()
        conn.close()

def run_intersection_density_v2(db_config):
    """Run intersection density v2 (speed degradation) SQL scripts."""
    log_print("\n" + "="*80)
    log_print("STEP 2: Intersection Density v2 (Speed Degradation)")
    log_print("="*80)
    
    base_dir = get_script_base_dir()
    sql_dir = os.path.join(base_dir, "sql", "road_intersection_density")
    
    # Execution order for intersection density v2
    intersection_scripts = [
        "00_schema_v2.sql",
        "01_find_and_categorize_intersections_v2.sql",
        "02_map_intersections_to_ways_v2.sql",
        "03_calculate_base_degradation_v2.sql",
        "04_calculate_final_degradation_v2.sql",
    ]
    
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    try:
        for script_name in intersection_scripts:
            script_path = os.path.join(sql_dir, script_name)
            execute_sql_file(cursor, script_path)
            conn.commit()
        
        log_print("[SUCCESS] Intersection density v2 completed")
    except Exception as e:
        conn.rollback()
        log_print(f"[ERROR] Intersection density v2 failed: {str(e)}", level='error')
        raise
    finally:
        cursor.close()
        conn.close()

def run_persona_scoring(db_config):
    """Run persona scoring SQL scripts."""
    log_print("\n" + "="*80)
    log_print("STEP 3: Persona Scoring")
    log_print("="*80)
    
    base_dir = get_script_base_dir()
    sql_dir = os.path.join(base_dir, "sql", "road_persona")
    
    # Use the simplified persona scoring script
    persona_script = os.path.join(sql_dir, "01_compute_persona_base_scores_simplified_all_india.sql")
    
    # Check if all_india version exists, otherwise use regular version
    if not os.path.exists(persona_script):
        persona_script = os.path.join(sql_dir, "01_compute_persona_base_scores_simplified.sql")
    
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    try:
        execute_sql_file(cursor, persona_script)
        conn.commit()
        log_print("[SUCCESS] Persona scoring completed")
    except Exception as e:
        conn.rollback()
        log_print(f"[ERROR] Persona scoring failed: {str(e)}", level='error')
        raise
    finally:
        cursor.close()
        conn.close()

def write_pbf(db_config):
    """Write augmented PBF file."""
    log_print("\n" + "="*80)
    log_print("STEP 4: Writing Augmented PBF")
    log_print("="*80)
    
    # Import the write_tags_to_pbf function
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from write_tags_to_pbf_2 import write_tags_to_pbf
    
    base_dir = get_script_base_dir()
    
    # Resolve output PBF path relative to script base directory
    default_output_path = os.path.join(base_dir, "osm_pbf_augmented_output", "india-latest-augmented.osm.pbf")
    output_pbf_path = os.getenv("OUTPUT_PBF_PATH", default_output_path)
    
    # If path from env is relative, make it relative to base_dir
    if not os.path.isabs(output_pbf_path):
        output_pbf_path = os.path.join(base_dir, output_pbf_path.lstrip('./'))
    
    log_print(f"Output PBF path: {output_pbf_path}")
    
    try:
        write_tags_to_pbf(db_config, output_pbf_path)
        log_print("[SUCCESS] PBF writing completed")
        log_print(f"[SUCCESS] Augmented PBF saved to: {output_pbf_path}")
    except Exception as e:
        log_print(f"[ERROR] PBF writing failed: {str(e)}", level='error')
        raise

def main():
    """Main execution function."""
    overall_start_time = time.time()
    
    log_print("="*80)
    log_print("Re-running Road Classification and Dependencies")
    log_print("="*80)
    log_print(f"Log file: {log_file}")
    log_print("")
    
    # Show which sections are enabled
    enabled_sections = [k for k, v in PIPELINE_SECTIONS.items() if v]
    disabled_sections = [k for k, v in PIPELINE_SECTIONS.items() if not v]
    log_print(f"Enabled sections: {', '.join(enabled_sections) if enabled_sections else 'NONE'}")
    log_print(f"Disabled sections: {', '.join(disabled_sections) if disabled_sections else 'NONE'}")
    log_print("")
    
    # Load configuration
    db_config = get_db_config()
    log_print(f"Database: {db_config['host']}:{db_config['port']}/{db_config['name']}")
    log_print(f"Input PBF: {db_config['new_pbf_path']}")
    log_print("")
    
    try:
        # Step 1: Road Classification
        if PIPELINE_SECTIONS.get('road_classification', False):
            run_road_classification(db_config)
        else:
            log_print("\n[SKIPPED] Step 1: Road Classification (disabled in PIPELINE_SECTIONS)")
        
        # Step 2: Intersection Density v2
        if PIPELINE_SECTIONS.get('intersection_density', False):
            run_intersection_density_v2(db_config)
        else:
            log_print("\n[SKIPPED] Step 2: Intersection Density v2 (disabled in PIPELINE_SECTIONS)")
        
        # Step 3: Persona Scoring
        if PIPELINE_SECTIONS.get('persona_scoring', False):
            run_persona_scoring(db_config)
        else:
            log_print("\n[SKIPPED] Step 3: Persona Scoring (disabled in PIPELINE_SECTIONS)")
        
        # Step 4: Write PBF
        if PIPELINE_SECTIONS.get('write_pbf', False):
            write_pbf(db_config)
        else:
            log_print("\n[SKIPPED] Step 4: Write PBF (disabled in PIPELINE_SECTIONS)")
        
        overall_elapsed = time.time() - overall_start_time
        log_print("\n" + "="*80)
        log_print("ALL STEPS COMPLETED SUCCESSFULLY")
        log_print("="*80)
        log_print(f"Total execution time: {overall_elapsed:.2f} seconds ({overall_elapsed/60:.2f} minutes)")
        log_print(f"Log file: {log_file}")
        
    except Exception as e:
        overall_elapsed = time.time() - overall_start_time
        log_print("\n" + "="*80)
        log_print("EXECUTION FAILED")
        log_print("="*80)
        log_print(f"Failed after {overall_elapsed:.2f} seconds", level='error')
        log_print(f"Error: {str(e)}", level='error')
        log_print(f"Log file: {log_file}")
        sys.exit(1)

if __name__ == "__main__":
    main()

