-- ============================================================================
-- Intersection Speed Degradation Test Materialized Views for Visualization
-- ============================================================================
-- This script creates materialized views for intersection speed degradation
-- test results optimized for visualization in QGIS or other GIS tools.
-- Views are created at z10 zoom level (medium detail, 0.0005 tolerance).
--
-- Usage: Run this script in pgAdmin Query Tool
-- The script is idempotent - safe to run multiple times.
--
-- Views created for each test case:
-- - base_degradation_z10: Base degradation (before setting/lanes factors)
-- - setting_adjusted_degradation_z10: After setting multiplier applied
-- - final_degradation_z10: Final degradation (after all factors)
--
-- Test cases are dynamically discovered from test_isd_*_final_results tables.
-- Each test case gets 3 views (base, setting adjusted, final).
--
-- To refresh views after test data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_base_degradation_z10;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_setting_adjusted_z10;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_final_degradation_z10;
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- ============================================================================
-- Helper function to get all test case names
-- ============================================================================
-- This will be used to dynamically create views for each test case
-- For now, we'll create views for known test cases

-- ============================================================================
-- Function to create views for a specific test case
-- ============================================================================
CREATE OR REPLACE FUNCTION create_isd_test_views(test_name TEXT)
RETURNS VOID AS $$
BEGIN
    -- Drop existing views for this test case
    EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS vis.map_isd_%s_base_degradation_z10', test_name);
    EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS vis.map_isd_%s_setting_adjusted_z10', test_name);
    EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS vis.map_isd_%s_final_degradation_z10', test_name);
    
    -- Create base degradation view
    EXECUTE format('
        CREATE MATERIALIZED VIEW vis.map_isd_%s_base_degradation_z10 AS
        SELECT 
            r.osm_id,
            r.way_id,
            r.base_degradation,
            r.intersection_count,
            b.major_count,
            b.middling_count,
            b.minor_count,
            b.calculation_method,
            r.length_m / 1000.0 AS length_km,
            r.road_type_i1,
            r.road_setting_i1,
            r.road_classification_v2,
            r.highway,
            r.population_density,
            r.build_perc,
            o.ref,
            o.name,
            ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
        FROM test_isd_%s_final_results r
        JOIN osm_all_roads o ON r.osm_id = o.osm_id
        LEFT JOIN test_isd_%s_base_degradation b ON r.way_id = b.way_id
        WHERE r.base_degradation IS NOT NULL
          AND o.geometry IS NOT NULL;
    ', test_name, test_name, test_name);
    
    -- Create setting adjusted degradation view
    EXECUTE format('
        CREATE MATERIALIZED VIEW vis.map_isd_%s_setting_adjusted_z10 AS
        SELECT 
            r.osm_id,
            r.way_id,
            r.setting_adjusted_degradation,
            r.base_degradation,
            r.road_setting_i1,
            r.intersection_count,
            r.length_m / 1000.0 AS length_km,
            r.road_type_i1,
            r.road_classification_v2,
            r.highway,
            r.population_density,
            r.build_perc,
            o.ref,
            o.name,
            ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
        FROM test_isd_%s_final_results r
        JOIN osm_all_roads o ON r.osm_id = o.osm_id
        WHERE r.setting_adjusted_degradation IS NOT NULL
          AND o.geometry IS NOT NULL;
    ', test_name, test_name);
    
    -- Create final degradation view
    EXECUTE format('
        CREATE MATERIALIZED VIEW vis.map_isd_%s_final_degradation_z10 AS
        SELECT 
            r.osm_id,
            r.way_id,
            r.final_intersection_speed_degradation,
            r.setting_adjusted_degradation,
            r.base_degradation,
            r.intersection_count,
            b.major_count,
            b.middling_count,
            b.minor_count,
            b.calculation_method,
            r.length_m / 1000.0 AS length_km,
            r.road_type_i1,
            r.road_setting_i1,
            r.road_classification_v2,
            r.highway,
            r.lanes,
            r.oneway,
            r.lanes_count,
            r.is_oneway,
            r.applied_lanes_oneway_factor,
            r.population_density,
            r.build_perc,
            o.ref,
            o.name,
            ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
        FROM test_isd_%s_final_results r
        JOIN osm_all_roads o ON r.osm_id = o.osm_id
        LEFT JOIN test_isd_%s_base_degradation b ON r.way_id = b.way_id
        WHERE r.final_intersection_speed_degradation IS NOT NULL
          AND o.geometry IS NOT NULL;
    ', test_name, test_name, test_name);
    
    -- Create indexes for base degradation
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_base_geom ON vis.map_isd_%s_base_degradation_z10 USING GIST (geom)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_base_degradation ON vis.map_isd_%s_base_degradation_z10 (base_degradation)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_base_setting ON vis.map_isd_%s_base_degradation_z10 (road_setting_i1)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_base_type ON vis.map_isd_%s_base_degradation_z10 (road_type_i1)', test_name, test_name);
    
    -- Create indexes for setting adjusted degradation
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_setting_geom ON vis.map_isd_%s_setting_adjusted_z10 USING GIST (geom)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_setting_degradation ON vis.map_isd_%s_setting_adjusted_z10 (setting_adjusted_degradation)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_setting_setting ON vis.map_isd_%s_setting_adjusted_z10 (road_setting_i1)', test_name, test_name);
    
    -- Create indexes for final degradation
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_final_geom ON vis.map_isd_%s_final_degradation_z10 USING GIST (geom)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_final_degradation ON vis.map_isd_%s_final_degradation_z10 (final_intersection_speed_degradation)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_final_setting ON vis.map_isd_%s_final_degradation_z10 (road_setting_i1)', test_name, test_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_mv_isd_%s_final_type ON vis.map_isd_%s_final_degradation_z10 (road_type_i1)', test_name, test_name);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Get list of test cases and create views for each
-- ============================================================================
DO $$
DECLARE
    test_table RECORD;
    test_name TEXT;
BEGIN
    -- Find all test_isd_*_final_results tables
    FOR test_table IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name LIKE 'test_isd_%_final_results'
        ORDER BY table_name
    LOOP
        -- Extract test name from table name (remove 'test_isd_' prefix and '_final_results' suffix)
        test_name := REPLACE(REPLACE(test_table.table_name, 'test_isd_', ''), '_final_results', '');
        
        RAISE NOTICE 'Creating views for test case: %', test_name;
        
        -- Create views for this test case
        PERFORM create_isd_test_views(test_name);
    END LOOP;
    
    RAISE NOTICE 'Completed creating views for all test cases';
END $$;

-- ============================================================================
-- Summary
-- ============================================================================
-- Created materialized views for all intersection speed degradation test cases.
-- Each test case has 3 views:
-- - vis.map_isd_<test_name>_base_degradation_z10
-- - vis.map_isd_<test_name>_setting_adjusted_z10
-- - vis.map_isd_<test_name>_final_degradation_z10
--
-- Views include:
-- - Degradation values (base, setting adjusted, final)
-- - Intersection counts (total, major, middling, minor)
-- - Road attributes (type, setting, classification, highway)
-- - Infrastructure (lanes, oneway, lanes_count)
-- - Environmental (population_density, build_perc)
-- - Simplified geometry (0.0005 tolerance for z10)
--
-- To refresh views after test data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_base_degradation_z10;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_setting_adjusted_z10;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_final_degradation_z10;
--
-- To list all created views:
--   SELECT table_name FROM information_schema.views 
--   WHERE table_schema = 'vis' AND table_name LIKE 'map_isd_%';

