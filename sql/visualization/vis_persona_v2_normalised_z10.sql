-- ============================================================================
-- Persona v2 Normalised Scores Visualization Views (z10)
-- ============================================================================
-- This script creates materialized views for the 4 normalised persona v2 scores
-- optimized for visualization in QGIS.
-- Views are created at z10 zoom level (medium detail, 0.0005 tolerance).
--
-- This version processes all of India (no BBOX filter).
--
-- Usage: Run this script in pgAdmin Query Tool
-- The script is idempotent - safe to run multiple times.
--
-- Views created:
-- - vis.map_persona_milemuncher_v2_norm_z10
-- - vis.map_persona_cornercraver_v2_norm_z10
-- - vis.map_persona_trailblazer_v2_norm_z10
-- - vis.map_persona_tranquiltraveller_v2_norm_z10
--
-- To refresh views after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_<view_name>_z10;
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;


-- ============================================================================
-- Drop all existing normalised persona v2 views in vis schema (z10 only)
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_v2_norm_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_v2_norm_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_v2_norm_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_v2_norm_z10;

-- ============================================================================
-- PERSONA SCORE VIEWS (V2 - NORMALISED)
-- ============================================================================
-- These expose the *_score_normalised fields directly as the primary score column
-- (useful for quick styling in QGIS).

-- MileMuncher Persona v2 (Normalised)
CREATE MATERIALIZED VIEW vis.map_persona_milemuncher_v2_norm_z10 AS
SELECT 
    o.osm_id,
    o.persona_milemuncher_score_normalised AS persona_milemuncher_score_normalised,
    o.persona_milemuncher_score AS persona_milemuncher_score_raw,
    o.score_cruise_road,
    o.score_flow,
    o.score_twist,
    o.score_scenic_fast,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.avg_speed_kph,
    o.fourlane,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_milemuncher_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_norm_z10_geom ON vis.map_persona_milemuncher_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_norm_z10_score ON vis.map_persona_milemuncher_v2_norm_z10 (persona_milemuncher_score_normalised);

-- CornerCraver Persona v2 (Normalised)
CREATE MATERIALIZED VIEW vis.map_persona_cornercraver_v2_norm_z10 AS
SELECT 
    o.osm_id,
    o.persona_cornercraver_score_normalised AS persona_cornercraver_score_normalised,
    o.persona_cornercraver_score AS persona_cornercraver_score_raw,
    o.score_twist,
    o.score_flow,
    o.score_cruise_road,
    o.score_remoteness,
    o.score_scenic_fast,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.twistiness_score,
    o.tags->>'surface' AS surface,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_cornercraver_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_norm_z10_geom ON vis.map_persona_cornercraver_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_norm_z10_score ON vis.map_persona_cornercraver_v2_norm_z10 (persona_cornercraver_score_normalised);

-- TrailBlazer Persona v2 (Normalised)
CREATE MATERIALIZED VIEW vis.map_persona_trailblazer_v2_norm_z10 AS
SELECT 
    o.osm_id,
    o.persona_trailblazer_score_normalised AS persona_trailblazer_score_normalised,
    o.persona_trailblazer_score AS persona_trailblazer_score_raw,
    o.score_offroad,
    o.score_remoteness,
    o.score_scenic_wild,
    o.scenery_v2_confidence,
    o.wc_forest_frac,
    o.wc_field_frac,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.tags->>'surface' AS surface,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_trailblazer_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_norm_z10_geom ON vis.map_persona_trailblazer_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_norm_z10_score ON vis.map_persona_trailblazer_v2_norm_z10 (persona_trailblazer_score_normalised);

-- TranquilTraveller Persona v2 (Normalised)
CREATE MATERIALIZED VIEW vis.map_persona_tranquiltraveller_v2_norm_z10 AS
SELECT 
    o.osm_id,
    o.persona_tranquiltraveller_score_normalised AS persona_tranquiltraveller_score_normalised,
    o.persona_tranquiltraveller_score AS persona_tranquiltraveller_score_raw,
    o.score_calm_road,
    o.score_remoteness,
    o.score_twist,
    o.score_scenic_serene,
    o.scenery_v2_confidence,
    o.wc_forest_frac,
    o.wc_field_frac,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_tranquiltraveller_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_norm_z10_geom ON vis.map_persona_tranquiltraveller_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_norm_z10_score ON vis.map_persona_tranquiltraveller_v2_norm_z10 (persona_tranquiltraveller_score_normalised);

-- ============================================================================
-- Summary
-- ============================================================================
-- Created 4 materialized views at z10 zoom level:
--
-- PERSONA SCORES V2 (NORMALISED) (4 views):
-- - vis.map_persona_milemuncher_v2_norm_z10
-- - vis.map_persona_cornercraver_v2_norm_z10
-- - vis.map_persona_trailblazer_v2_norm_z10
-- - vis.map_persona_tranquiltraveller_v2_norm_z10
--
-- Each view includes:
-- - Normalised persona score (primary field for styling)
-- - Raw persona score (for reference)
-- - Supporting parameter scores
-- - Road attributes (road_type_i1, road_setting_i1, road_classification_v2)
-- - Simplified geometry (0.0005 tolerance for z10)
-- - Spatial and attribute indexes for performance
--
-- To refresh after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_persona_<persona>_v2_norm_z10;
--
-- To use in QGIS:
-- 1. Connect to PostgreSQL database
-- 2. Add layer from database
-- 3. Select schema: vis
-- 4. Select table: map_persona_<persona>_v2_norm_z10
-- 5. Style by persona_<persona>_score_normalised using graduated symbology
-- ============================================================================
