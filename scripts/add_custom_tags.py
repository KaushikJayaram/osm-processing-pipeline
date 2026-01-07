#!/usr/bin/env python3

import json
import os
import psycopg
import time
import subprocess
import logging
from datetime import datetime
import gc
import psutil

# ============================================================================
# PATH RESOLUTION
# ============================================================================

def get_project_base_dir():
    """Get the base directory (osm-file-processing-v2) - one level up from scripts/."""
    # Get the directory where this script is located (scripts/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Go up one level to get osm-file-processing-v2/
    base_dir = os.path.dirname(script_dir)
    return base_dir

def resolve_project_path(path):
    """Resolve a path relative to the project base directory."""
    base_dir = get_project_base_dir()
    
    # If path is already absolute, return as-is
    if os.path.isabs(path):
        return path
    
    # If path starts with ./, remove it
    if path.startswith('./'):
        path = path[2:]
    
    # Join with base directory
    return os.path.join(base_dir, path)

# Setup logging to both console and file
def setup_logging():
    """Setup logging to both console and file."""
    # Create logs directory if it doesn't exist (relative to project root)
    log_dir = resolve_project_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"add_custom_tags_{timestamp}.log")
    
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

def log_time(task_name, start_time):
    """Logs the elapsed time for a task."""
    end_time = time.time()
    elapsed_time = end_time - start_time
    message = f"{task_name} completed in {elapsed_time:.2f} seconds"
    log_print(message)
    return end_time

def execute_sql_file(cursor, filepath, params=None):
    """Reads and executes an SQL file with optional parameters."""
    log_print(f"Starting execution of {os.path.basename(filepath)}")
    start_time = time.time()

    with open(filepath, 'r', encoding='utf-8') as file:
        sql_query = file.read()

    # If parameters are provided, format the SQL query dynamically
    if params:
        csv_path = params['csv_path']
        sql_query = sql_query.replace(":csv_path", f"'{csv_path}'")\

    cursor.execute(sql_query)

    elapsed_time = time.time() - start_time
    log_print(f"Executed {os.path.basename(filepath)} in {elapsed_time:.2f} seconds")

def table_exists(db_name, db_user, db_host, db_port, db_password, table_name):
    """Checks if a table exists in the database."""
    conn = psycopg.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port
    )
    cursor = conn.cursor()
    cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = %s
        );
    """, (table_name,))
    table_exists = cursor.fetchone()[0]
    cursor.close()
    conn.close()
    return table_exists

def load_raster_data(db_config):
    """Loads raster data into PostGIS using raster2pgsql."""
    log_print("[add_custom_tags] Loading raster data into PostGIS...")

    raster_files = [
        {
            "filepath": resolve_project_path("data/Population_data/ind_pd_2020_1km_UNadj.tif"),
            "table": "public.pop_density"
        },
        {
            "filepath": resolve_project_path("data/GHSL_data/GHS_BUILT_S_E2030_GLOBE_R2023A_4326_30ss_V1_0.tif"),
            "table": "public.built_up_area"
        }
    ]
    # Establish a database connection here
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()  # Now `cursor` is defined

    for raster in raster_files:
        raster_path = raster["filepath"]
        table_name = raster["table"]

        if not os.path.exists(raster_path):
            log_print(f"[WARNING] Raster file {raster_path} not found. Skipping...", level='warning')
            continue

        # Check if the raster table already exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = %s
            );
        """, (table_name.split('.')[-1],))
        table_exists = cursor.fetchone()[0]

        if table_exists:
            log_print(f"[INFO] Raster table {table_name} already exists. Skipping import...")
            continue  # Skip this raster import

        log_print(f"[add_custom_tags] Importing {os.path.basename(raster_path)} into {table_name}...")

        # Construct raster2pgsql command
        cmd = f'raster2pgsql -s 4326 -I -C -M -F -t 100x100 "{raster_path}" {table_name} | ' \
              f'psql -d {db_config["name"]} -U {db_config["user"]} -h {db_config["host"]} -p {db_config["port"]}'
        
        # Set up the environment to pass the password without prompting
        env = os.environ.copy()
        if db_config.get("password"):
            env["PGPASSWORD"] = db_config["password"]

        # Execute raster2pgsql command
        start_time = time.time()
        try:
            subprocess.run(cmd, shell=True, check=True, env=env)
            log_time(f"Loading {table_name}", start_time)
        except subprocess.CalledProcessError as e:
            log_print(f"[ERROR] Failed to load raster data for {table_name}: {e}", level='error')
    cursor.close()
    conn.close()  # Ensure proper closing of the connection
    
def perform_storage_cleanup(db_config, step_name="Unknown"):
    """
    Performs storage-specific cleanup:
    - VACUUM FULL on tables with dead tuples
    - Drops intermediate tables that are no longer needed
    - Logs storage space reclaimed
    """
    log_print(f"[STORAGE_CLEANUP] Starting storage cleanup after {step_name}...")
    cleanup_start = time.time()
    
    try:
        conn = psycopg.connect(
            dbname=db_config['name'],
            user=db_config['user'],
            password=db_config['password'],
            host=db_config['host'],
            port=db_config['port']
        )
        conn.autocommit = True
        cursor = conn.cursor()
        
        # Get database size before cleanup
        cursor.execute("SELECT pg_size_pretty(pg_database_size(current_database()));")
        db_size_before = cursor.fetchone()[0]
        log_print(f"[STORAGE_CLEANUP] Database size before cleanup: {db_size_before}")
        
        # VACUUM FULL on rs_highway_way_nodes (has many dead tuples)
        log_print("[STORAGE_CLEANUP] Running VACUUM FULL on rs_highway_way_nodes (this may take a while)...")
        try:
            cursor.execute("VACUUM FULL rs_highway_way_nodes;")
            log_print("[STORAGE_CLEANUP] VACUUM FULL completed for rs_highway_way_nodes")
        except Exception as e:
            log_print(f"[STORAGE_CLEANUP] Could not VACUUM FULL rs_highway_way_nodes: {e}", level='warning')
        
        # Drop old intermediate tables
        tables_to_drop = [
            'osm_all_roads_geom_ls',  # Old curvature v1 intermediate table (2.9 GB)
            'rs_curvature_vertex_metrics',  # Intermediate curvature v2 table (35 GB)
            'rs_curvature_way_vertices',  # Intermediate curvature v2 table (21 GB)
            'rs_curvature_conflict_points',  # Intermediate curvature v2 table (3.2 GB)
        ]
        
        for table in tables_to_drop:
            try:
                # Check if table exists and get its size
                cursor.execute("""
                    SELECT pg_size_pretty(pg_total_relation_size(%s))
                    FROM information_schema.tables
                    WHERE table_schema = 'public' AND table_name = %s;
                """, (table, table))
                result = cursor.fetchone()
                if result and result[0]:
                    table_size = result[0]
                    log_print(f"[STORAGE_CLEANUP] Dropping table {table} (size: {table_size})...")
                    cursor.execute(f"DROP TABLE IF EXISTS {table} CASCADE;")
                    log_print(f"[STORAGE_CLEANUP] Successfully dropped {table}")
                else:
                    log_print(f"[STORAGE_CLEANUP] Table {table} does not exist, skipping")
            except Exception as e:
                log_print(f"[STORAGE_CLEANUP] Could not drop {table}: {e}", level='warning')
        
        # Get database size after cleanup
        cursor.execute("SELECT pg_size_pretty(pg_database_size(current_database()));")
        db_size_after = cursor.fetchone()[0]
        log_print(f"[STORAGE_CLEANUP] Database size after cleanup: {db_size_after}")
        
        cursor.close()
        conn.close()
        log_print("[STORAGE_CLEANUP] Storage cleanup completed")
    except Exception as e:
        log_print(f"[STORAGE_CLEANUP] Error during storage cleanup: {e}", level='error')
    
    elapsed = time.time() - cleanup_start
    log_print(f"[STORAGE_CLEANUP] Storage cleanup completed in {elapsed:.2f} seconds")


def perform_memory_cleanup(db_config, step_name="Unknown"):
    """
    Performs comprehensive memory cleanup:
    - Closes and reopens database connections
    - Runs PostgreSQL VACUUM ANALYZE
    - Forces Python garbage collection
    - Logs memory usage
    
    If step_name indicates curvature v2 completion, also performs storage cleanup.
    """
    log_print(f"[MEMORY_CLEANUP] Starting cleanup after {step_name}...")
    cleanup_start = time.time()
    
    # Get memory usage before cleanup
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / (1024 * 1024 * 1024)  # GB
    log_print(f"[MEMORY_CLEANUP] Memory before cleanup: {mem_before:.2f} GB")
    
    # Force Python garbage collection
    collected = gc.collect()
    log_print(f"[MEMORY_CLEANUP] Python GC collected {collected} objects")
    
    # Run PostgreSQL VACUUM ANALYZE to free up memory and update statistics
    try:
        conn = psycopg.connect(
            dbname=db_config['name'],
            user=db_config['user'],
            password=db_config['password'],
            host=db_config['host'],
            port=db_config['port']
        )
        conn.autocommit = True
        cursor = conn.cursor()
        
        log_print("[MEMORY_CLEANUP] Running VACUUM ANALYZE on osm_all_roads...")
        cursor.execute("VACUUM ANALYZE osm_all_roads;")
        
        # Also vacuum other large tables if they exist
        # (helps QGIS performance + keeps query planning sane after big updates)
        for table in ['india_grids', 'pop_density', 'built_up_area', 'rs_curvature_way_summary']:
            try:
                cursor.execute(f"VACUUM ANALYZE {table};")
                log_print(f"[MEMORY_CLEANUP] VACUUM ANALYZE completed for {table}")
            except Exception as e:
                log_print(f"[MEMORY_CLEANUP] Could not vacuum {table}: {e}", level='warning')
        
        cursor.close()
        conn.close()
        log_print("[MEMORY_CLEANUP] PostgreSQL cleanup completed")
    except Exception as e:
        log_print(f"[MEMORY_CLEANUP] Error during PostgreSQL cleanup: {e}", level='error')
    
    # Get memory usage after cleanup
    mem_after = process.memory_info().rss / (1024 * 1024 * 1024)  # GB
    mem_freed = mem_before - mem_after
    elapsed = time.time() - cleanup_start
    
    log_print(f"[MEMORY_CLEANUP] Memory after cleanup: {mem_after:.2f} GB")
    log_print(f"[MEMORY_CLEANUP] Memory freed: {mem_freed:.2f} GB")
    log_print(f"[MEMORY_CLEANUP] Cleanup completed in {elapsed:.2f} seconds")
    
    # Perform storage cleanup after curvature v2 processing (not v1)
    # Only trigger for curvature v2, not legacy v1
    if "Curvature" in step_name and ("v2" in step_name or ("Part 2" in step_name and "v1" not in step_name and "Legacy" not in step_name)):
        perform_storage_cleanup(db_config, step_name)

def add_custom_tags(db_config):
    """Executes raster loading first, then SQL scripts in four parts."""
    message = "[add_custom_tags] Starting custom tag processing..."
    log_print(message)
    log_print(f"Log file location: {log_file}")

    overall_start_time = time.time()

    # Step 1: Connect to PostgreSQL before loading raster data
    conn_start_time = time.time()
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    log_time("Database connection", conn_start_time)

    # Step 2: Load raster data
    load_raster_data(db_config)

    # **PART 1: Setting Road Classification**
    log_print("[add_custom_tags] Part 1: Setting Road Classification...")
    sql_dir = resolve_project_path("sql/road_classification")

    # Step 1: Handle india_grids
    if table_exists(db_config['name'], db_config['user'], db_config['host'], db_config['port'], db_config['password'], 'india_grids'):
        log_print("[INFO] Table 'india_grids' already exists, skipping creation.")
    else:
        log_print("[INFO] Table 'india_grids' does not exist, generating grids from scratch.")
        execute_sql_file(cursor, os.path.join(sql_dir, "01_create_india_grids.sql"))

    conn.commit()

    # Continue with the rest of the road classification SQL scripts
    road_classification_sql_files = [
        "02_add_pop_density_and_built_up_area_data.sql",
        "03_add_grid_classification_level1.sql",
        "04_prepare_osm_all_roads_table.sql",
        "05_add_grid_classification_level2.sql",
        "06_handle_roads_intersecting_multiple_grids.sql",
        "07_assign_final_road_classification.sql",
        #"09_add_mdr.sql",
    ]

    for sql_file in road_classification_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    # Close connection and cleanup after Part 1
    cursor.close()
    conn.close()
    perform_memory_cleanup(db_config, "Part 1: Road Classification")

    # **PART 2: Setting Road Curvature Classification**
    log_print("[add_custom_tags] Part 2: Setting Road Curvature Classification...")
    # Reopen connection for Part 2
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    # Curvature v2 mini-module:
    # - Requires Lua3 import: scripts/Lua3_RouteProcessing_with_curvature.lua
    # - Produces rs_curvature_way_summary and (optionally) copies summary fields onto osm_all_roads
    # - First populates node coordinates (idempotent, skips if >95% already populated)
    sql_dir = resolve_project_path("sql/road_curvature_v2")
    road_curvature_sql_files = [
        "00_populate_node_coordinates.sql",  # Populate coordinates in rs_highway_way_nodes (idempotent)
        "00_schema.sql",
        "01_prepare_inputs.sql",
        "02_compute_vertex_angles.sql",
        "03_classify_radius_and_segment_meters.sql",
        "04_conflict_zone_suppression.sql",
        "05_aggregate_to_way.sql",
        "06_optional_update_osm_all_roads.sql",
    ]


    for sql_file in road_curvature_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    # Close connection and cleanup after Part 2
    cursor.close()
    conn.close()
    perform_memory_cleanup(db_config, "Part 2: Road Curvature Classification")

    # **PART 3: Setting Road Scenery**
    log_print("[add_custom_tags] Part 3: Setting Road Scenery...")
    # Reopen connection for Part 3
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    sql_dir = resolve_project_path("sql/road_scenery")
    road_scenery_sql_files = [
        "01_scenery_processing_add_columns.sql",
        "00_reset_all_scenery.sql",
        "02_scenery_urban_and_semi_urban.sql",
        "03_scenery_forest.sql",
        "04_scenery_hill.sql",
        "05_scenery_lake.sql",
        "06_scenery_beach.sql",
        "07_scenery_river.sql",
        "08_scenery_desert.sql",
        "09_scenery_field.sql",
        "11_scenery_mountain_pass.sql",
    ]

    for sql_file in road_scenery_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    # Close connection and cleanup after Part 3
    cursor.close()
    conn.close()
    perform_memory_cleanup(db_config, "Part 3: Road Scenery")

    # **PART 4: Setting Road Access**
    log_print("[add_custom_tags] Part 4: Setting Road Access...")
    # Reopen connection for Part 4
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    sql_dir = resolve_project_path("sql/road_access")
    road_access_sql_files = ["01_rsbikeaccess_update.sql"]

    for sql_file in road_access_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    # Close connection and cleanup after Part 4
    cursor.close()
    conn.close()
    perform_memory_cleanup(db_config, "Part 4: Road Access")

    # **PART 5: Intersection Speed Degradation (v2)**
    log_print("[add_custom_tags] Part 5: Intersection Speed Degradation (v2)...")
    # Reopen connection for Part 5
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    sql_dir = resolve_project_path("sql/road_intersection_density")
    intersection_density_sql_files = [
        "00_schema_v2.sql",
        "01_find_and_categorize_intersections_v2.sql",
        "02_map_intersections_to_ways_v2.sql",
        "03_calculate_base_degradation_v2.sql",
        "04_calculate_final_degradation_v2.sql",
    ]

    for sql_file in intersection_density_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    # Close connection and cleanup after Part 5
    cursor.close()
    conn.close()
    perform_memory_cleanup(db_config, "Part 5: Intersection Speed Degradation (v2)")

    # **PART 6: Road Persona Scoring**
    # Computes 4 persona scores on osm_all_roads for QGIS inspection.
    log_print("[add_custom_tags] Part 6: Road Persona Scoring...")
    conn = psycopg.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()

    sql_dir = resolve_project_path("sql/road_persona")
    road_persona_sql_files = [
        "00_add_persona_columns.sql",
        "01_compute_persona_base_scores.sql",
        "02_compute_persona_corridors_and_final.sql",
    ]

    for sql_file in road_persona_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    cursor.close()
    conn.close()
    perform_memory_cleanup(db_config, "Part 6: Road Persona Scoring")

    log_time("SQL script execution", overall_start_time)
    message = "[add_custom_tags] Completed all processing steps."
    log_print(message)
    log_print(f"Full log saved to: {log_file}")

