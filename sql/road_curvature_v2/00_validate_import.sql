-- VALIDATION: Check that OSM import created required tables correctly
-- This should be run IMMEDIATELY after the OSM import completes.
-- Validates that tables exist and have data. Coordinates may be NULL (populated later in curvature workflow).

DO $$
DECLARE
    total_rows BIGINT;
    null_coords_count BIGINT;
    non_null_coords_count BIGINT;
    null_coords_pct NUMERIC;
    distinct_ways BIGINT;
    ways_with_all_null_coords BIGINT;
    ways_with_some_coords BIGINT;
    ways_with_all_coords BIGINT;
BEGIN
    -- Check if table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'rs_highway_way_nodes'
    ) THEN
        RAISE EXCEPTION 'ERROR: Table rs_highway_way_nodes does not exist. OSM import may have failed or used wrong Lua script. Expected Lua3_RouteProcessing_with_curvature.lua';
    END IF;
    
    -- Get basic counts
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE lon IS NULL OR lat IS NULL),
        COUNT(*) FILTER (WHERE lon IS NOT NULL AND lat IS NOT NULL),
        COUNT(DISTINCT way_id)
    INTO 
        total_rows,
        null_coords_count,
        non_null_coords_count,
        distinct_ways
    FROM rs_highway_way_nodes;
    
    -- Check if table is empty
    IF total_rows = 0 THEN
        RAISE EXCEPTION 'ERROR: rs_highway_way_nodes table is empty. OSM import did not populate way nodes. Check that Lua script is correct and PBF file contains highway data.';
    END IF;
    
    -- Calculate percentage
    null_coords_pct := (null_coords_count::NUMERIC / NULLIF(total_rows, 0)::NUMERIC) * 100;
    
    -- Check per-way statistics
    WITH way_stats AS (
        SELECT 
            way_id,
            COUNT(*) AS total_nodes,
            COUNT(*) FILTER (WHERE lon IS NULL OR lat IS NULL) AS null_nodes,
            COUNT(*) FILTER (WHERE lon IS NOT NULL AND lat IS NOT NULL) AS valid_nodes
        FROM rs_highway_way_nodes
        GROUP BY way_id
    )
    SELECT 
        COUNT(*) FILTER (WHERE null_nodes = total_nodes),
        COUNT(*) FILTER (WHERE valid_nodes > 0 AND null_nodes > 0),
        COUNT(*) FILTER (WHERE null_nodes = 0)
    INTO 
        ways_with_all_null_coords,
        ways_with_some_coords,
        ways_with_all_coords
    FROM way_stats;
    
    -- NOTE: NULL coordinates are expected in slim mode (cache doesn't persist between passes)
    -- Coordinates will be populated by 00_populate_node_coordinates.sql in the curvature workflow
    -- So we don't fail on NULL coordinates, just report status
    
    -- WARN if all coordinates are NULL (unusual, but OK since we populate them later)
    IF null_coords_count = total_rows THEN
        RAISE WARNING 
            'NOTE: All coordinates are NULL in rs_highway_way_nodes (% rows, % ways). '
            'This is expected in slim mode. Coordinates will be populated by 00_populate_node_coordinates.sql in the curvature workflow.',
            total_rows, distinct_ways;
    ELSIF null_coords_pct > 50 THEN
        RAISE WARNING 
            'NOTE: %s%% of coordinates are NULL (%s of %s rows). '
            'This is expected in slim mode. Coordinates will be populated by 00_populate_node_coordinates.sql in the curvature workflow.',
            ROUND(null_coords_pct, 1)::TEXT, null_coords_count, total_rows;
    END IF;
    
    -- SUCCESS message
    RAISE NOTICE 
        '✓ Import validation PASSED: '
        '%s rows in rs_highway_way_nodes, '
        '%s distinct ways, '
        '%s%% have NULL coordinates (%s rows) - will be populated in curvature workflow, '
        '%s ways have all valid coordinates, '
        '%s ways have partial coordinates, '
        '%s ways have all NULL coordinates. '
        'Table structure is correct. Proceeding with curvature pipeline is safe.',
        total_rows, distinct_ways, ROUND(null_coords_pct, 1)::TEXT, null_coords_count,
        ways_with_all_coords, ways_with_some_coords, ways_with_all_null_coords;
END $$;

