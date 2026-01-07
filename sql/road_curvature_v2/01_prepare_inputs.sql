-- Curvature v2: prepare vertex table + indexes

-- VALIDATION: Quick check that source table has coordinate data
-- Uses sampling to avoid expensive full table scans on large datasets
DO $$
DECLARE
    has_data BOOLEAN;
    has_coords BOOLEAN;
    sample_null_count BIGINT;
    sample_total BIGINT;
BEGIN
    -- Quick existence check (uses index if available, very fast)
    SELECT EXISTS(SELECT 1 FROM rs_highway_way_nodes LIMIT 1) INTO has_data;
    
    IF NOT has_data THEN
        RAISE EXCEPTION 'ERROR: rs_highway_way_nodes table is empty. Cannot proceed with curvature calculation.';
    END IF;
    
    -- Quick check: do we have ANY non-null coordinates? (uses index, very fast)
    SELECT EXISTS(
        SELECT 1 FROM rs_highway_way_nodes 
        WHERE lon IS NOT NULL AND lat IS NOT NULL 
        LIMIT 1
    ) INTO has_coords;
    
    IF NOT has_coords THEN
        RAISE EXCEPTION 'ERROR: All coordinates are NULL in rs_highway_way_nodes. The OSM import did not populate node coordinates. Re-import using Lua3_RouteProcessing_with_curvature.lua or run recovery script.';
    END IF;
    
    -- Sample-based check: examine a random sample to estimate NULL percentage
    -- This is much faster than full table scan (typically < 1 second)
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE lon IS NULL OR lat IS NULL)
    INTO sample_total, sample_null_count
    FROM (
        SELECT lon, lat 
        FROM rs_highway_way_nodes 
        TABLESAMPLE SYSTEM (0.1)  -- Sample 0.1% of rows
        LIMIT 10000  -- Cap at 10k rows for speed
    ) sample;
    
    IF sample_total > 0 THEN
        DECLARE
            estimated_null_pct NUMERIC;
        BEGIN
            estimated_null_pct := (sample_null_count::NUMERIC / sample_total::NUMERIC) * 100;
            
            IF estimated_null_pct > 80 THEN
                RAISE WARNING 'WARNING: Sample suggests ~%s%% of coordinates may be NULL. Results may be incomplete. Consider checking full table if needed.', ROUND(estimated_null_pct, 1)::TEXT;
            ELSE
                RAISE NOTICE 'Validation passed: Table has data with coordinates. Sample suggests ~%s%% NULL coordinates.', ROUND(estimated_null_pct, 1)::TEXT;
            END IF;
        END;
    ELSE
        RAISE NOTICE 'Validation passed: Table has data with coordinates.';
    END IF;
END $$;

TRUNCATE rs_curvature_way_vertices;

-- Filter to bikable roads using the pre-computed flag (much faster than IN clause)
-- The bikable_road flag is set in sql/road_classification/04_prepare_osm_all_roads_table.sql
-- and has a partial index (idx_osm_all_roads_bikable_road) for efficient filtering
WITH eligible_ways AS (
    SELECT osm_id
    FROM osm_all_roads
    WHERE bikable_road = TRUE
)
INSERT INTO rs_curvature_way_vertices (way_id, node_id, seq, lon, lat, geom, geom_3857)
SELECT
    w.way_id,
    w.node_id,
    w.seq,
    w.lon,
    w.lat,
    CASE
        WHEN w.lon IS NULL OR w.lat IS NULL THEN NULL
        ELSE ST_SetSRID(ST_MakePoint(w.lon::double precision, w.lat::double precision), 4326)
    END AS geom,
    CASE
        WHEN w.lon IS NULL OR w.lat IS NULL THEN NULL
        ELSE ST_Transform(ST_SetSRID(ST_MakePoint(w.lon::double precision, w.lat::double precision), 4326), 3857)
    END AS geom_3857
FROM rs_highway_way_nodes AS w
JOIN eligible_ways AS e ON e.osm_id = w.way_id
WHERE w.seq IS NOT NULL;

-- Helpful indexes for windowing + joins
CREATE INDEX IF NOT EXISTS idx_rs_curvature_way_vertices_way_seq
ON rs_curvature_way_vertices (way_id, seq);

CREATE INDEX IF NOT EXISTS idx_rs_curvature_way_vertices_node_id
ON rs_curvature_way_vertices (node_id);

-- Source tables should also be indexed
CREATE INDEX IF NOT EXISTS idx_rs_highway_way_nodes_way_seq
ON rs_highway_way_nodes (way_id, seq);

CREATE INDEX IF NOT EXISTS idx_rs_highway_way_nodes_node_id
ON rs_highway_way_nodes (node_id);

CREATE INDEX IF NOT EXISTS idx_rs_conflict_nodes_geom
ON rs_conflict_nodes USING GIST (geometry);


