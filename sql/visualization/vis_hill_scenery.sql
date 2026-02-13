-- ============================================================================
-- Visualization Views for Hill Scenery (DEM-based)
-- ============================================================================
-- Creates views in vis schema for inspecting hill_* metrics and classification.
-- Safe to re-run.
-- ============================================================================

-- Ensure visualization schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- Base view: all rows with computed hill metrics
CREATE OR REPLACE VIEW vis.hill_scenery_base AS
SELECT
  osm_id,
  geometry AS geom,
  hill_slope_mean,
  hill_slope_max,
  hill_relief_1km,
  hill_signal_raw,
  hill_signal_smoothed,
  road_scenery_hill
FROM public.osm_all_roads
WHERE hill_slope_mean IS NOT NULL
   OR hill_relief_1km IS NOT NULL
   OR hill_signal_smoothed IS NOT NULL;

-- Test-bbox view (matching test bbox used in runners)
CREATE OR REPLACE VIEW vis.hill_scenery_test_bbox AS
SELECT
  *
FROM vis.hill_scenery_base
WHERE ST_Intersects(
  geom,
  ST_MakeEnvelope(75.0, 12.0, 79.0, 15.0, 4326)
);

-- Simplified view for quick map rendering (z10-ish)
DROP MATERIALIZED VIEW IF EXISTS vis.map_hill_scenery_z10;
CREATE MATERIALIZED VIEW vis.map_hill_scenery_z10 AS
SELECT
  osm_id,
  road_scenery_hill AS class_label,
  hill_slope_mean,
  hill_slope_max,
  hill_relief_1km,
  hill_signal_smoothed,
  ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.hill_scenery_base;

CREATE INDEX IF NOT EXISTS idx_mv_hill_scenery_z10_geom
  ON vis.map_hill_scenery_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_hill_scenery_z10_lbl
  ON vis.map_hill_scenery_z10 (class_label);
