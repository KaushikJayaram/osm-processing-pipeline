-- ============================================================================
-- RS Bike Access Visualization View (z10)
-- ============================================================================
-- This script creates a materialized view for rsbikeaccess (yes/no) values
-- optimized for visualization in QGIS.
-- View is created at z10 zoom level (medium detail, 0.0005 tolerance).
--
-- This version processes all of India (no BBOX filter).
--
-- Usage: Run this script in pgAdmin Query Tool
-- The script is idempotent - safe to run multiple times.
--
-- View created:
-- - vis.map_rsbikeaccess_z10
--
-- To refresh view after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_rsbikeaccess_z10;
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;


-- ============================================================================
-- Drop existing rsbikeaccess view in vis schema (z10 only)
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS vis.map_rsbikeaccess_z10;

-- ============================================================================
-- RS BIKE ACCESS VIEW
-- ============================================================================

-- RS Bike Access (z10)
CREATE MATERIALIZED VIEW vis.map_rsbikeaccess_z10 AS
SELECT 
    o.osm_id,
    o.rsbikeaccess,
    o.highway,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.bikable_road,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.rsbikeaccess IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_rsbikeaccess_z10_geom ON vis.map_rsbikeaccess_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_rsbikeaccess_z10_value ON vis.map_rsbikeaccess_z10 (rsbikeaccess);
CREATE INDEX IF NOT EXISTS idx_mv_rsbikeaccess_z10_highway ON vis.map_rsbikeaccess_z10 (highway);

-- ============================================================================
-- Summary
-- ============================================================================
-- Created 1 materialized view at z10 zoom level:
--
-- RS BIKE ACCESS (1 view):
-- - vis.map_rsbikeaccess_z10
--
-- View includes:
-- - rsbikeaccess value ('yes' or 'no')
-- - Highway type
-- - Road attributes (road_type_i1, road_setting_i1, road_classification_v2)
-- - bikable_road flag
-- - Simplified geometry (0.0005 tolerance for z10)
-- - Spatial and attribute indexes for performance
--
-- To refresh after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_rsbikeaccess_z10;
--
-- To use in QGIS:
-- 1. Connect to PostgreSQL database
-- 2. Add layer from database
-- 3. Select schema: vis
-- 4. Select table: map_rsbikeaccess_z10
-- 5. Style by rsbikeaccess using categorized symbology (yes/no)
-- ============================================================================
