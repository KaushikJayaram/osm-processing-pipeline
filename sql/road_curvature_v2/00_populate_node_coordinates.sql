-- Populate node coordinates in rs_highway_way_nodes
-- This script populates lon/lat coordinates by joining with rs_node_coords or extracting from way geometries.
-- 
-- IDEMPOTENT: Automatically skips if >95% of coordinates are already populated (safe for iterative runs).
-- Run as part of curvature v2 workflow - coordinates are needed for curvature calculations.

-- EARLY EXIT CHECK: Skip if coordinates are already populated (>95% have coordinates)
DO $$
DECLARE
    total_way_nodes BIGINT;
    nodes_with_coords BIGINT;
    pct_with_coords NUMERIC;
    should_skip BOOLEAN := FALSE;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE lon IS NOT NULL AND lat IS NOT NULL)
    INTO total_way_nodes, nodes_with_coords
    FROM rs_highway_way_nodes;
    
    IF total_way_nodes = 0 THEN
        RAISE EXCEPTION 'ERROR: rs_highway_way_nodes table is empty. Way processing may have failed.';
    END IF;
    
    pct_with_coords := (nodes_with_coords::NUMERIC / NULLIF(total_way_nodes, 0)::NUMERIC) * 100;
    
    -- If >95% already have coordinates, skip this script (already populated)
    IF pct_with_coords > 95.0 THEN
        RAISE NOTICE 'Coordinates already populated: %s%% of way nodes have coordinates. Skipping coordinate population step.', ROUND(pct_with_coords, 1)::TEXT;
        should_skip := TRUE;
    ELSE
        RAISE NOTICE 'Starting coordinate population: %s%% of way nodes have coordinates. Need to populate remaining %s%%', 
            ROUND(pct_with_coords, 1)::TEXT, ROUND(100.0 - pct_with_coords, 1)::TEXT;
    END IF;
    
    -- Store flag in a temp table so subsequent DO blocks can check it
    CREATE TEMP TABLE IF NOT EXISTS _coordinate_population_skip (should_skip BOOLEAN);
    DELETE FROM _coordinate_population_skip;
    INSERT INTO _coordinate_population_skip VALUES (should_skip);
END $$;

-- Check if we should skip (coordinates already populated)
DO $$
DECLARE
    should_skip BOOLEAN;
BEGIN
    SELECT COALESCE(should_skip, FALSE) INTO should_skip FROM _coordinate_population_skip LIMIT 1;
    IF should_skip THEN
        -- Exit early - all subsequent operations will be skipped
        RETURN;
    END IF;
END $$;

-- Check if node_coords table exists and has data
DO $$
DECLARE
    node_coords_count BIGINT;
    way_nodes_count BIGINT;
    should_skip BOOLEAN;
BEGIN
    SELECT COALESCE(should_skip, FALSE) INTO should_skip FROM _coordinate_population_skip LIMIT 1;
    IF should_skip THEN
        RETURN;
    END IF;
    -- Check if rs_node_coords table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'rs_node_coords'
    ) THEN
        RAISE EXCEPTION 'ERROR: rs_node_coords table does not exist. The Lua script may not have created it. Check Lua3_RouteProcessing_with_curvature.lua.';
    END IF;
    
    SELECT COUNT(*) INTO node_coords_count FROM rs_node_coords;
    SELECT COUNT(*) INTO way_nodes_count FROM rs_highway_way_nodes;
    
    IF node_coords_count = 0 THEN
        RAISE EXCEPTION 'ERROR: rs_node_coords table is empty. Node processing may have failed.';
    END IF;
    
    RAISE NOTICE 'Populating coordinates: % nodes in rs_node_coords, % way nodes to update', node_coords_count, way_nodes_count;
END $$;

-- First, populate coordinates in rs_node_coords from geometry (if not already set)
-- Also create geometry from coordinates if geometry is missing but coordinates exist
UPDATE rs_node_coords AS n
SET 
    -- Populate coordinates from geometry if missing
    lon = CASE 
        WHEN n.lon IS NULL AND n.geometry IS NOT NULL THEN ST_X(n.geometry)
        ELSE n.lon 
    END,
    lat = CASE 
        WHEN n.lat IS NULL AND n.geometry IS NOT NULL THEN ST_Y(n.geometry)
        ELSE n.lat 
    END,
    -- Create geometry from coordinates if missing
    geometry = CASE 
        WHEN n.geometry IS NULL AND n.lon IS NOT NULL AND n.lat IS NOT NULL 
        THEN ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)
        ELSE n.geometry
    END
WHERE (n.lon IS NULL OR n.lat IS NULL OR n.geometry IS NULL)
  AND (n.geometry IS NOT NULL OR (n.lon IS NOT NULL AND n.lat IS NOT NULL));

-- NOTE: In flex output mode, planet_osm_nodes is NOT created by osm2pgsql.
-- Only tables defined in the Lua script are created.
-- If nodes are missing from rs_node_coords, the Lua script needs to be fixed to store all nodes.
DO $$
DECLARE
    missing_nodes_count BIGINT;
    rs_node_coords_count BIGINT;
BEGIN
    -- Count nodes in ways that aren't in rs_node_coords
    SELECT COUNT(DISTINCT w.node_id)
    INTO missing_nodes_count
    FROM rs_highway_way_nodes w
    LEFT JOIN rs_node_coords n ON w.node_id = n.osm_id
    WHERE n.osm_id IS NULL;
    
    SELECT COUNT(*) INTO rs_node_coords_count FROM rs_node_coords;
    
    IF missing_nodes_count > 0 THEN
        RAISE WARNING 'Found % way nodes missing from rs_node_coords (out of % total nodes in rs_node_coords). The Lua script may not be storing all nodes. Check that process_node() stores all nodes with coordinates.', 
            missing_nodes_count, rs_node_coords_count;
    END IF;
END $$;

-- METHOD 1: Try to update from rs_node_coords (if nodes were stored)
DO $$
DECLARE
    rows_updated_from_coords BIGINT;
    nodes_with_coords_before BIGINT;
    should_skip BOOLEAN;
BEGIN
    SELECT COALESCE(should_skip, FALSE) INTO should_skip FROM _coordinate_population_skip LIMIT 1;
    IF should_skip THEN
        RETURN;
    END IF;
    SELECT COUNT(*) INTO nodes_with_coords_before
    FROM rs_highway_way_nodes
    WHERE lon IS NOT NULL AND lat IS NOT NULL;
    
    UPDATE rs_highway_way_nodes AS w
    SET 
        lon = n.lon,
        lat = n.lat
    FROM rs_node_coords AS n
    WHERE w.node_id = n.osm_id
      AND n.lon IS NOT NULL
      AND n.lat IS NOT NULL
      AND (w.lon IS NULL OR w.lat IS NULL);
    
    GET DIAGNOSTICS rows_updated_from_coords = ROW_COUNT;
    RAISE NOTICE 'Method 1 (from rs_node_coords): Updated % rows. Nodes with coordinates before: %', 
        rows_updated_from_coords, nodes_with_coords_before;
END $$;

-- METHOD 2: Extract coordinates directly from way geometry
-- Use a simpler, more efficient approach: update directly from way geometry
-- This avoids the expensive window function over all ways
DO $$
DECLARE
    rows_updated_from_geometry BIGINT;
    nodes_with_coords_before BIGINT;
    nodes_with_coords_after BIGINT;
    should_skip BOOLEAN;
BEGIN
    SELECT COALESCE(should_skip, FALSE) INTO should_skip FROM _coordinate_population_skip LIMIT 1;
    IF should_skip THEN
        RETURN;
    END IF;
    RAISE NOTICE 'Starting Method 2: Extracting coordinates from way geometries...';
    
    SELECT COUNT(*) INTO nodes_with_coords_before
    FROM rs_highway_way_nodes
    WHERE lon IS NOT NULL AND lat IS NOT NULL;
    
    RAISE NOTICE 'Nodes with coordinates before: %', nodes_with_coords_before;
    RAISE NOTICE 'This may take 10-30 minutes for large datasets. Processing...';
    
    -- Extract all points from way geometries and match by sequence
    -- Using a subquery to number points sequentially per way
    UPDATE rs_highway_way_nodes AS w
    SET 
        lon = ST_X(way_points.point_geom),
        lat = ST_Y(way_points.point_geom)
    FROM (
        SELECT 
            o.osm_id AS way_id,
            ROW_NUMBER() OVER (PARTITION BY o.osm_id ORDER BY dp.path[1], dp.path[2]) - 1 AS seq,
            dp.geom AS point_geom
        FROM osm_all_roads o
        CROSS JOIN LATERAL ST_DumpPoints(o.geometry) AS dp
        WHERE o.geometry IS NOT NULL
          AND o.osm_id IN (
              SELECT DISTINCT way_id 
              FROM rs_highway_way_nodes 
              WHERE lon IS NULL OR lat IS NULL
          )
    ) AS way_points
    WHERE w.way_id = way_points.way_id
      AND w.seq = way_points.seq
      AND (w.lon IS NULL OR w.lat IS NULL);
    
    GET DIAGNOSTICS rows_updated_from_geometry = ROW_COUNT;
    
    SELECT COUNT(*) INTO nodes_with_coords_after
    FROM rs_highway_way_nodes
    WHERE lon IS NOT NULL AND lat IS NOT NULL;
    
    RAISE NOTICE 'Method 2 complete: Updated % rows. Nodes with coordinates: % before, % after', 
        rows_updated_from_geometry, nodes_with_coords_before, nodes_with_coords_after;
END $$;

-- Report results
DO $$
DECLARE
    total_way_nodes BIGINT;
    nodes_with_coords BIGINT;
    nodes_without_coords BIGINT;
    pct_with_coords NUMERIC;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE lon IS NOT NULL AND lat IS NOT NULL),
        COUNT(*) FILTER (WHERE lon IS NULL OR lat IS NULL)
    INTO 
        total_way_nodes,
        nodes_with_coords,
        nodes_without_coords
    FROM rs_highway_way_nodes;
    
    pct_with_coords := (nodes_with_coords::NUMERIC / NULLIF(total_way_nodes, 0)::NUMERIC) * 100;
    
    RAISE NOTICE 'Coordinate population complete: % way nodes total, % have coordinates (%), % still NULL', 
        total_way_nodes, nodes_with_coords, ROUND(pct_with_coords, 1)::TEXT, nodes_without_coords;
    
    IF nodes_with_coords = 0 THEN
        RAISE EXCEPTION 'ERROR: No coordinates were populated. All way nodes still have NULL coordinates. Check that rs_node_coords has matching node_ids.';
    ELSIF pct_with_coords < 50 THEN
        RAISE WARNING 'WARNING: Only %s%% of way nodes have coordinates. Many nodes may be missing from rs_node_coords.', ROUND(pct_with_coords, 1)::TEXT;
    END IF;
END $$;

-- Create index on node_coords for faster lookups (if not exists)
CREATE INDEX IF NOT EXISTS idx_rs_node_coords_osm_id ON rs_node_coords (osm_id);

