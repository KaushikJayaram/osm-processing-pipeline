-- ============================================================================
-- Visualization Views for Scenery V2 (WorldCover sampling)
-- ============================================================================
-- Creates views in vis schema for inspecting wc_* fractions and primary tag.
-- Safe to re-run.
-- ============================================================================

-- Ensure visualization schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- Base view: all rows with computed wc_* values
CREATE OR REPLACE VIEW vis.scenery_v2_worldcover_base AS
SELECT
  osm_id,
  geometry AS geom,
  wc_total_px,
  wc_forest_frac,
  wc_field_frac,
  wc_desert_frac,
  wc_snow_frac,
  wc_water_frac,
  scenery_v2_primary,
  scenery_v2_confidence
FROM public.osm_all_roads
WHERE wc_total_px IS NOT NULL
  AND wc_total_px > 0;

-- Test-bbox view (matching test bbox used in runners)
CREATE OR REPLACE VIEW vis.scenery_v2_worldcover_test_bbox AS
SELECT
  *
FROM vis.scenery_v2_worldcover_base
WHERE ST_Intersects(
  geom,
  ST_MakeEnvelope(75.0, 12.0, 79.0, 15.0, 4326)
);

-- Simplified view for quick map rendering (z10-ish)
DROP MATERIALIZED VIEW IF EXISTS vis.map_scenery_v2_worldcover_z10;
CREATE MATERIALIZED VIEW vis.map_scenery_v2_worldcover_z10 AS
SELECT
  osm_id,
  scenery_v2_primary AS class_label,
  wc_forest_frac,
  wc_field_frac,
  wc_desert_frac,
  wc_snow_frac,
  wc_water_frac,
  ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.scenery_v2_worldcover_base;

CREATE INDEX IF NOT EXISTS idx_mv_scenery_v2_wc_z10_geom
  ON vis.map_scenery_v2_worldcover_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_scenery_v2_wc_z10_lbl
  ON vis.map_scenery_v2_worldcover_z10 (class_label);
