-- ============================================================================
-- Visualization Views for Urban Clusters (Test Bbox)
-- ============================================================================
-- Creates views in vis schema for inspecting urban and semi-urban cluster polygons from
-- both clustering approaches (Option 1: ST_ClusterIntersecting, Option 3: ST_ClusterDBSCAN).
--
-- Usage: Run in pgAdmin or psql. Safe to re-run (drops and recreates views).
-- Load in QGIS using existing "egis" connection pattern.
--
-- Returns two separate layers:
--   1. vis.urban_clusters_opt1_test - Contiguity-based clusters (Urban + SemiUrban)
--   2. vis.urban_clusters_opt3_test - Distance-based DBSCAN clusters (Urban + SemiUrban)
-- ============================================================================

-- Ensure visualization schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- ============================================================================
-- Option 1: Contiguity-based Clusters (ST_ClusterIntersecting)
-- ============================================================================
DROP VIEW IF EXISTS vis.urban_clusters_opt1_test;
CREATE OR REPLACE VIEW vis.urban_clusters_opt1_test AS
SELECT
    cluster_id,
    geom,
    area_km2,
    grid_count,
    centroid,
    bbox
FROM public.rs_urban_clusters_i1_opt1_test
WHERE geom IS NOT NULL
  AND ST_Intersects(
      geom,
      ST_MakeEnvelope(75.0, 12.0, 79.0, 15.0, 4326)
  )
ORDER BY area_km2 DESC;

-- ============================================================================
-- Option 3: Distance-based DBSCAN Clusters
-- ============================================================================
DROP VIEW IF EXISTS vis.urban_clusters_opt3_test;
CREATE OR REPLACE VIEW vis.urban_clusters_opt3_test AS
SELECT
    cluster_id,
    geom,
    area_km2,
    grid_count,
    centroid,
    bbox
FROM public.rs_urban_clusters_i1_opt3_test
WHERE geom IS NOT NULL
  AND ST_Intersects(
      geom,
      ST_MakeEnvelope(75.0, 12.0, 79.0, 15.0, 4326)
  )
ORDER BY area_km2 DESC;

-- ============================================================================
-- Simplified Materialized Views for Quick Rendering (z10-ish)
-- ============================================================================

-- Option 1: Simplified view
DROP MATERIALIZED VIEW IF EXISTS vis.map_urban_clusters_opt1_test_z10;
CREATE MATERIALIZED VIEW vis.map_urban_clusters_opt1_test_z10 AS
SELECT
    cluster_id,
    area_km2,
    grid_count,
    ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.urban_clusters_opt1_test;

CREATE INDEX IF NOT EXISTS idx_mv_urban_clusters_opt1_test_z10_geom
  ON vis.map_urban_clusters_opt1_test_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_urban_clusters_opt1_test_z10_area
  ON vis.map_urban_clusters_opt1_test_z10 (area_km2);

-- Option 3: Simplified view
DROP MATERIALIZED VIEW IF EXISTS vis.map_urban_clusters_opt3_test_z10;
CREATE MATERIALIZED VIEW vis.map_urban_clusters_opt3_test_z10 AS
SELECT
    cluster_id,
    area_km2,
    grid_count,
    ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.urban_clusters_opt3_test;

CREATE INDEX IF NOT EXISTS idx_mv_urban_clusters_opt3_test_z10_geom
  ON vis.map_urban_clusters_opt3_test_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_urban_clusters_opt3_test_z10_area
  ON vis.map_urban_clusters_opt3_test_z10 (area_km2);
