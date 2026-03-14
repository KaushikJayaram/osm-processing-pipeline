-- ============================================================================
-- Visualization Views for Scenery V2 Flags (Forest, Field, Desert, Snow, Water)
-- ============================================================================
-- Creates views in vis schema for inspecting scenery boolean flags and road_scenery_* flags.
-- Safe to re-run.
-- ============================================================================

-- Ensure visualization schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- Base view: all rows with scenery flags
CREATE OR REPLACE VIEW vis.scenery_v2_flags_base AS
SELECT
  osm_id,
  geometry AS geom,
  road_scenery_primary,
  scenery_v2_desert,
  scenery_v2_snow,
  scenery_v2_water,
  road_scenery_forest,
  road_scenery_field
FROM public.osm_all_roads
WHERE wc_total_px IS NOT NULL
  AND wc_total_px > 0;

-- Test-bbox view (matching test bbox used in runners)
CREATE OR REPLACE VIEW vis.scenery_v2_flags_test_bbox AS
SELECT
  *
FROM vis.scenery_v2_flags_base
WHERE ST_Intersects(
  geom,
  ST_MakeEnvelope(75.0, 12.0, 79.0, 15.0, 4326)
);

-- Simplified view for quick map rendering (z10-ish)
DROP MATERIALIZED VIEW IF EXISTS vis.map_scenery_v2_flags_z10;
CREATE MATERIALIZED VIEW vis.map_scenery_v2_flags_z10 AS
SELECT
  osm_id,
  road_scenery_primary AS class_label,
  scenery_v2_desert,
  scenery_v2_snow,
  scenery_v2_water,
  road_scenery_forest,
  road_scenery_field,
  ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.scenery_v2_flags_base;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_mv_scenery_v2_flags_z10_geom
  ON vis.map_scenery_v2_flags_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_scenery_v2_flags_z10_lbl
  ON vis.map_scenery_v2_flags_z10 (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_scenery_v2_flags_z10_water
  ON vis.map_scenery_v2_flags_z10 (scenery_v2_water) WHERE scenery_v2_water = TRUE;
