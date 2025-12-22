#!/usr/bin/env python3

import json
import os
import psycopg2
import time
import subprocess
import logging
from datetime import datetime
import gc
import psutil

# Setup logging to both console and file
def setup_logging():
    """Setup logging to both console and file."""
    # Create logs directory if it doesn't exist
    log_dir = "logs"
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

def import_india_grids_from_csv(db_config, csv_file_path):
    """
    Uses psql to import the simplified india_grids.csv.
    Assumes CSV has exactly 3 columns: grid_id, grid_geom (WKB hex), grid_area
    """
    import subprocess
    import os
    import psycopg2
    import time

    log_print(f"[INFO] Importing from {csv_file_path}...")
    
    # Convert to absolute path to avoid any path resolution issues
    abs_csv_path = os.path.abspath(csv_file_path)
    
    # Ensure the file exists
    if not os.path.exists(abs_csv_path):
        raise FileNotFoundError(f"CSV file not found: {abs_csv_path}")
    
    try:
        # Connect to create the table
        conn = psycopg2.connect(
            dbname=db_config['name'],
            user=db_config['user'],
            password=db_config.get('password', ''),
            host=db_config['host'],
            port=db_config['port']
        )
        conn.autocommit = True
        cursor = conn.cursor()
        
        # Create the table if it doesn't exist
        cursor.execute("""
            DROP TABLE IF EXISTS india_grids;
            CREATE TABLE india_grids (
                grid_id INTEGER PRIMARY KEY,
                grid_geom GEOMETRY(Polygon, 4326),
                grid_area DOUBLE PRECISION
            );
        """)
        cursor.close()
        conn.close()
        
        log_print("[INFO] Created/truncated india_grids table")
        
        # Build the psql command
        import_sql = f"""
        \\set ON_ERROR_STOP on
        \\timing on
        \\echo Starting import at: \\! date
        \\echo Importing from: {abs_csv_path}
        
        -- Create a temporary table
        CREATE TEMP TABLE temp_import (
            grid_id INTEGER,
            grid_geom TEXT,
            grid_area DOUBLE PRECISION
        );
        
        -- Import the data
        \\copy temp_import FROM '{abs_csv_path}' WITH (FORMAT csv, HEADER true, DELIMITER ',');
        
        -- Insert into the actual table
        INSERT INTO india_grids (grid_id, grid_geom, grid_area)
        SELECT 
            grid_id, 
            ST_GeomFromEWKB(decode(grid_geom, 'hex')),
            grid_area
        FROM temp_import
        WHERE grid_geom IS NOT NULL;
        
        -- Verify the import
        SELECT 
            COUNT(*) as total_rows,
            COUNT(grid_geom) as non_null_geometries,
            MIN(grid_id) as min_id,
            MAX(grid_id) as max_id
        FROM india_grids;
        
        -- Clean up
        DROP TABLE temp_import;
        """
        
        # Write the SQL to a temporary file
        with open('/tmp/import_grids.sql', 'w') as f:
            f.write(import_sql)
        
        # Build the psql command
        cmd = [
            "psql",
            "-d", db_config['name'],
            "-U", db_config['user'],
            "-h", db_config['host'],
            "-p", str(db_config['port']),
            "-v", "ON_ERROR_STOP=1",
            "-f", "/tmp/import_grids.sql"
        ]
        
        # Set up environment
        env = os.environ.copy()
        if 'password' in db_config and db_config['password']:
            env['PGPASSWORD'] = db_config['password']
        
        # Run the import with a timeout
        log_print("[INFO] Starting data import...")
        start_time = time.time()
        result = subprocess.run(
            cmd, 
            env=env,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        # Print the output
        log_print(result.stdout)
        if result.stderr:
            log_print("Error output:", level='error')
            log_print(result.stderr, level='error')
            
        log_print(f"[INFO] Import completed in {time.time() - start_time:.2f} seconds")
        
        # Check the return code
        result.check_returncode()
        
    except subprocess.TimeoutExpired:
        log_print("[ERROR] Import timed out after 5 minutes", level='error')
        raise
    except subprocess.CalledProcessError as e:
        log_print(f"[ERROR] Import failed with return code {e.returncode}", level='error')
        log_print(f"Command: {' '.join(e.cmd)}", level='error')
        log_print(f"Output: {e.output}", level='error')
        log_print(f"Error: {e.stderr}", level='error')
        raise
    except Exception as e:
        log_print(f"[ERROR] Unexpected error: {e}", level='error')
        raise

def table_exists(db_name, db_user, db_host, db_port, db_password, table_name):
    """Checks if a table exists in the database."""
    conn = psycopg2.connect(
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
            "filepath": "data/Population_data/ind_pd_2020_1km_UNadj.tif",
            "table": "public.pop_density"
        },
        {
            "filepath": "data/GHSL_data/GHS_BUILT_S_E2030_GLOBE_R2023A_4326_30ss_V1_0.tif",
            "table": "public.built_up_area"
        }
    ]
    # Establish a database connection here
    conn = psycopg2.connect(
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
    
def perform_memory_cleanup(db_config, step_name="Unknown"):
    """
    Performs comprehensive memory cleanup:
    - Closes and reopens database connections
    - Runs PostgreSQL VACUUM ANALYZE
    - Forces Python garbage collection
    - Logs memory usage
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
        conn = psycopg2.connect(
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
        for table in ['india_grids', 'pop_density', 'built_up_area']:
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

def add_custom_tags(db_config):
    """Executes raster loading first, then SQL scripts in four parts."""
    message = "[add_custom_tags] Starting custom tag processing..."
    log_print(message)
    log_print(f"Log file location: {log_file}")

    overall_start_time = time.time()

    # Step 1: Connect to PostgreSQL before loading raster data
    conn_start_time = time.time()
    conn = psycopg2.connect(
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
    sql_dir = "sql/road_classification"
    india_grids_csv = "data/india_grids.csv"

    # Step 1: Handle india_grids
    if table_exists(db_config['name'], db_config['user'], db_config['host'], db_config['port'], db_config['password'], 'india_grids'):
        log_print("[INFO] Table 'india_grids' already exists, skipping creation.")
    else:
        if os.path.exists(india_grids_csv):
            log_print(f"[INFO] Found {india_grids_csv}, using it instead of generating grids.")
        else:
            log_print(f"[INFO] {india_grids_csv} not found, generating grids from scratch.")
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
    conn = psycopg2.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    sql_dir = "sql/road_curvature_classification"
    road_curvature_sql_files = [
        "051_calculate_curvature_and_update.sql",
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
    conn = psycopg2.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    sql_dir = "sql/road_scenery"
    road_scenery_sql_files = [
        "01_scenery_processing_add_columns.sql",
        "02_scenery_urban_and_semi_urban.sql",
        "00_reset_all_scenery.sql",
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
    conn = psycopg2.connect(
        dbname=db_config['name'],
        user=db_config['user'],
        password=db_config['password'],
        host=db_config['host'],
        port=db_config['port']
    )
    cursor = conn.cursor()
    
    sql_dir = "sql/road_access"
    road_access_sql_files = ["01_rsbikeaccess_update.sql"]

    for sql_file in road_access_sql_files:
        filepath = os.path.join(sql_dir, sql_file)
        if os.path.exists(filepath):
            execute_sql_file(cursor, filepath)
            conn.commit()
            log_print(f"Finished execution of {sql_file}")
        else:
            log_print(f"[WARNING] File {sql_file} does not exist. Skipping.", level='warning')

    cursor.close()
    conn.close()
    log_time("SQL script execution", overall_start_time)
    message = "[add_custom_tags] Completed all processing steps."
    log_print(message)
    log_print(f"Full log saved to: {log_file}")

