-- ============================================================================
-- Intersection Speed Degradation Materialized Views for Visualization
-- ============================================================================
-- This script creates materialized views for intersection speed degradation
-- values optimized for visualization in QGIS or other GIS tools.
-- Views are created at z10 zoom level (medium detail, 0.0005 tolerance).
--
-- Usage: Run this script in pgAdmin Query Tool
-- The script is idempotent - safe to run multiple times.
--
-- Views created:
-- - base_degradation_z10: Base degradation (before setting/lanes factors)
-- - setting_adjusted_degradation_z10: After setting multiplier applied
-- - final_degradation_z10: Final degradation (after all factors)
--
-- To refresh views after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_base_degradation_z10;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_setting_adjusted_degradation_z10;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_final_degradation_z10;
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- ============================================================================
-- Base Degradation View (z10)
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS vis.map_isd_base_degradation_z10;
CREATE MATERIALIZED VIEW vis.map_isd_base_degradation_z10 AS
SELECT 
    o.osm_id,
    o.way_id,
    o.ref,
    o.name,
    o.highway,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    o.intersection_speed_degradation_base AS degradation_value,
    CASE 
        WHEN o.intersection_speed_degradation_base = 0.0 THEN 'None (0.0)'
        WHEN o.intersection_speed_degradation_base < 0.1 THEN 'Low (<0.1)'
        WHEN o.intersection_speed_degradation_base < 0.25 THEN 'Medium (0.1-0.25)'
        WHEN o.intersection_speed_degradation_base < 0.4 THEN 'High (0.25-0.4)'
        ELSE 'Very High (>=0.4)'
    END AS degradation_class,
    ST_SimplifyPreserveTopology(
        COALESCE(o.geom_ls, o.geometry), 
        0.0005
    ) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE
  AND o.intersection_speed_degradation_base IS NOT NULL
  AND o.intersection_speed_degradation_base > 0.0;

-- Create index on geometry for performance
CREATE INDEX IF NOT EXISTS idx_map_isd_base_degradation_z10_geom 
ON vis.map_isd_base_degradation_z10 USING GIST (geom);

-- Create index on degradation value for filtering
CREATE INDEX IF NOT EXISTS idx_map_isd_base_degradation_z10_value 
ON vis.map_isd_base_degradation_z10 (degradation_value);

-- ============================================================================
-- Setting-Adjusted Degradation View (z10)
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS vis.map_isd_setting_adjusted_degradation_z10;
CREATE MATERIALIZED VIEW vis.map_isd_setting_adjusted_degradation_z10 AS
SELECT 
    o.osm_id,
    o.way_id,
    o.ref,
    o.name,
    o.highway,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    o.intersection_speed_degradation_setting_adjusted AS degradation_value,
    CASE 
        WHEN o.intersection_speed_degradation_setting_adjusted = 0.0 THEN 'None (0.0)'
        WHEN o.intersection_speed_degradation_setting_adjusted < 0.1 THEN 'Low (<0.1)'
        WHEN o.intersection_speed_degradation_setting_adjusted < 0.25 THEN 'Medium (0.1-0.25)'
        WHEN o.intersection_speed_degradation_setting_adjusted < 0.4 THEN 'High (0.25-0.4)'
        ELSE 'Very High (>=0.4)'
    END AS degradation_class,
    ST_SimplifyPreserveTopology(
        COALESCE(o.geom_ls, o.geometry), 
        0.0005
    ) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE
  AND o.intersection_speed_degradation_setting_adjusted IS NOT NULL
  AND o.intersection_speed_degradation_setting_adjusted > 0.0;

-- Create index on geometry for performance
CREATE INDEX IF NOT EXISTS idx_map_isd_setting_adjusted_z10_geom 
ON vis.map_isd_setting_adjusted_degradation_z10 USING GIST (geom);

-- Create index on degradation value for filtering
CREATE INDEX IF NOT EXISTS idx_map_isd_setting_adjusted_z10_value 
ON vis.map_isd_setting_adjusted_degradation_z10 (degradation_value);

-- ============================================================================
-- Final Degradation View (z10)
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS vis.map_isd_final_degradation_z10;
CREATE MATERIALIZED VIEW vis.map_isd_final_degradation_z10 AS
SELECT 
    o.osm_id,
    o.way_id,
    o.ref,
    o.name,
    o.highway,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    o.intersection_speed_degradation_final AS degradation_value,
    CASE 
        WHEN o.intersection_speed_degradation_final = 0.0 THEN 'None (0.0)'
        WHEN o.intersection_speed_degradation_final < 0.1 THEN 'Low (<0.1)'
        WHEN o.intersection_speed_degradation_final < 0.25 THEN 'Medium (0.1-0.25)'
        WHEN o.intersection_speed_degradation_final < 0.4 THEN 'High (0.25-0.4)'
        ELSE 'Very High (>=0.4)'
    END AS degradation_class,
    ST_SimplifyPreserveTopology(
        COALESCE(o.geom_ls, o.geometry), 
        0.0005
    ) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE
  AND o.intersection_speed_degradation_final IS NOT NULL
  AND o.intersection_speed_degradation_final > 0.0;

-- Create index on geometry for performance
CREATE INDEX IF NOT EXISTS idx_map_isd_final_degradation_z10_geom 
ON vis.map_isd_final_degradation_z10 USING GIST (geom);

-- Create index on degradation value for filtering
CREATE INDEX IF NOT EXISTS idx_map_isd_final_degradation_z10_value 
ON vis.map_isd_final_degradation_z10 (degradation_value);

-- ============================================================================
-- Summary Statistics View
-- ============================================================================
DROP VIEW IF EXISTS vis.intersection_speed_degradation_stats;
CREATE VIEW vis.intersection_speed_degradation_stats AS
SELECT 
    'Base' AS degradation_type,
    COUNT(*) AS road_count,
    ROUND(AVG(intersection_speed_degradation_base)::numeric, 4) AS avg_degradation,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY intersection_speed_degradation_base)::numeric, 4) AS median_degradation,
    ROUND(MIN(intersection_speed_degradation_base)::numeric, 4) AS min_degradation,
    ROUND(MAX(intersection_speed_degradation_base)::numeric, 4) AS max_degradation,
    ROUND(STDDEV(intersection_speed_degradation_base)::numeric, 4) AS stddev_degradation
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND intersection_speed_degradation_base IS NOT NULL
  AND intersection_speed_degradation_base > 0.0

UNION ALL

SELECT 
    'Setting Adjusted' AS degradation_type,
    COUNT(*) AS road_count,
    ROUND(AVG(intersection_speed_degradation_setting_adjusted)::numeric, 4) AS avg_degradation,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY intersection_speed_degradation_setting_adjusted)::numeric, 4) AS median_degradation,
    ROUND(MIN(intersection_speed_degradation_setting_adjusted)::numeric, 4) AS min_degradation,
    ROUND(MAX(intersection_speed_degradation_setting_adjusted)::numeric, 4) AS max_degradation,
    ROUND(STDDEV(intersection_speed_degradation_setting_adjusted)::numeric, 4) AS stddev_degradation
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND intersection_speed_degradation_setting_adjusted IS NOT NULL
  AND intersection_speed_degradation_setting_adjusted > 0.0

UNION ALL

SELECT 
    'Final' AS degradation_type,
    COUNT(*) AS road_count,
    ROUND(AVG(intersection_speed_degradation_final)::numeric, 4) AS avg_degradation,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY intersection_speed_degradation_final)::numeric, 4) AS median_degradation,
    ROUND(MIN(intersection_speed_degradation_final)::numeric, 4) AS min_degradation,
    ROUND(MAX(intersection_speed_degradation_final)::numeric, 4) AS max_degradation,
    ROUND(STDDEV(intersection_speed_degradation_final)::numeric, 4) AS stddev_degradation
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND intersection_speed_degradation_final IS NOT NULL
  AND intersection_speed_degradation_final > 0.0;

-- ============================================================================
-- Completion Message
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE 'Intersection Speed Degradation visualization views created successfully!';
    RAISE NOTICE 'Views created:';
    RAISE NOTICE '  - vis.map_isd_base_degradation_z10';
    RAISE NOTICE '  - vis.map_isd_setting_adjusted_degradation_z10';
    RAISE NOTICE '  - vis.map_isd_final_degradation_z10';
    RAISE NOTICE '  - vis.intersection_speed_degradation_stats (summary statistics)';
    RAISE NOTICE '';
    RAISE NOTICE 'To refresh views after data updates:';
    RAISE NOTICE '  REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_base_degradation_z10;';
    RAISE NOTICE '  REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_setting_adjusted_degradation_z10;';
    RAISE NOTICE '  REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_final_degradation_z10;';
END $$;

