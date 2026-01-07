-- ============================================================================
-- Simplified Persona Scores Materialized Views for Visualization (z10)
-- ============================================================================
-- This script creates materialized views for simplified persona scores optimized 
-- for visualization in QGIS or other GIS tools. Views are created at z10 zoom level
-- (medium detail, 0.0005 tolerance) for performance optimization.
--
-- IMPORTANT: This version filters to TEST BBOX only (76-78° lon, 12-14° lat - Karnataka)
-- When running for all of India, remove the ST_Intersects filter from all WHERE clauses.
--
-- Usage: Run this script in pgAdmin Query Tool
-- The script is idempotent - safe to run multiple times.
--
-- Views created for each persona (MileMuncher, CornerCraver, TrailBlazer, TranquilTraveller):
-- - z10: Medium detail (0.0005 tolerance)
--
-- Each view includes:
-- - Base score (0-100): simplified scoring (direct scaling)
-- - Supporting fields: road_type, setting, length, population, build_perc
-- - Score classification: Excellent/Good/Fair/Poor/Very Poor (based on base_score)
--
-- To refresh views after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_persona_<persona>_simplified_z10;
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- ============================================================================
-- Verify persona columns exist before creating views
-- ============================================================================
DO $$
DECLARE
    v_column_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'osm_all_roads'
      AND column_name IN (
          'persona_milemuncher_base_score',
          'persona_cornercraver_base_score',
          'persona_trailblazer_base_score',
          'persona_tranquiltraveller_base_score'
      );
    
    IF v_column_count < 4 THEN
        RAISE EXCEPTION 'Persona columns do not exist! Found %/4 columns. Please run 00_add_simplified_persona_columns.sql first, or run the scoring script which will add them automatically.', v_column_count;
    ELSE
        RAISE NOTICE 'SUCCESS: All 4 persona base_score columns exist. Proceeding with view creation.';
    END IF;
END $$;

-- ============================================================================
-- Drop all existing simplified persona views in vis schema (z10 only)
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_simplified_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_simplified_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_simplified_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_simplified_z10;

-- ============================================================================
-- Persona: MileMuncher
-- ============================================================================

CREATE MATERIALIZED VIEW vis.map_persona_milemuncher_simplified_z10 AS
SELECT 
    o.osm_id,
    o.persona_milemuncher_base_score AS base_score,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_i1,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.population_density,
    o.build_perc,
    o.ref,
    o.name,
    o.twistiness_score,
    NULLIF(REGEXP_REPLACE(COALESCE(o.lanes, ''), '[^0-9]', '', 'g'), '')::INTEGER AS lanes_count,
    CASE 
        WHEN o.persona_milemuncher_base_score IS NULL THEN 'No Data'
        WHEN o.persona_milemuncher_base_score >= 80 THEN 'Excellent'
        WHEN o.persona_milemuncher_base_score >= 60 THEN 'Good'
        WHEN o.persona_milemuncher_base_score >= 40 THEN 'Fair'
        WHEN o.persona_milemuncher_base_score >= 20 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_milemuncher_base_score IS NOT NULL
  AND o.geometry IS NOT NULL
  AND ST_Intersects(o.geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326));  -- Test bbox filter

-- Indexes for MileMuncher
CREATE INDEX IF NOT EXISTS idx_mv_mm_simplified_z10_geom ON vis.map_persona_milemuncher_simplified_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_simplified_z10_base_score ON vis.map_persona_milemuncher_simplified_z10 (base_score);
CREATE INDEX IF NOT EXISTS idx_mv_mm_simplified_z10_score_class ON vis.map_persona_milemuncher_simplified_z10 (score_class);
CREATE INDEX IF NOT EXISTS idx_mv_mm_simplified_z10_road_type ON vis.map_persona_milemuncher_simplified_z10 (road_type_i1);

-- ============================================================================
-- Persona: CornerCraver
-- ============================================================================

CREATE MATERIALIZED VIEW vis.map_persona_cornercraver_simplified_z10 AS
SELECT 
    o.osm_id,
    o.persona_cornercraver_base_score AS base_score,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_i1,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.population_density,
    o.build_perc,
    o.ref,
    o.name,
    o.twistiness_score,
    o.tags->>'surface' AS surface,
    CASE 
        WHEN o.persona_cornercraver_base_score IS NULL THEN 'No Data'
        WHEN o.persona_cornercraver_base_score >= 80 THEN 'Excellent'
        WHEN o.persona_cornercraver_base_score >= 60 THEN 'Good'
        WHEN o.persona_cornercraver_base_score >= 40 THEN 'Fair'
        WHEN o.persona_cornercraver_base_score >= 20 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_cornercraver_base_score IS NOT NULL
  AND o.geometry IS NOT NULL
  AND ST_Intersects(o.geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326));  -- Test bbox filter

-- Indexes for CornerCraver
CREATE INDEX IF NOT EXISTS idx_mv_cc_simplified_z10_geom ON vis.map_persona_cornercraver_simplified_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_simplified_z10_base_score ON vis.map_persona_cornercraver_simplified_z10 (base_score);
CREATE INDEX IF NOT EXISTS idx_mv_cc_simplified_z10_score_class ON vis.map_persona_cornercraver_simplified_z10 (score_class);
CREATE INDEX IF NOT EXISTS idx_mv_cc_simplified_z10_road_type ON vis.map_persona_cornercraver_simplified_z10 (road_type_i1);

-- ============================================================================
-- Persona: TrailBlazer
-- ============================================================================

CREATE MATERIALIZED VIEW vis.map_persona_trailblazer_simplified_z10 AS
SELECT 
    o.osm_id,
    o.persona_trailblazer_base_score AS base_score,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_i1,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.population_density,
    o.build_perc,
    o.ref,
    o.name,
    (
        COALESCE(o.road_scenery_forest, 0) +
        COALESCE(o.road_scenery_hill, 0) +
        COALESCE(o.road_scenery_lake, 0) +
        COALESCE(o.road_scenery_river, 0) +
        COALESCE(o.road_scenery_mountainpass, 0) +
        COALESCE(o.road_scenery_field, 0)
    ) AS scenery_flags_count,
    CASE 
        WHEN o.persona_trailblazer_base_score IS NULL THEN 'No Data'
        WHEN o.persona_trailblazer_base_score >= 80 THEN 'Excellent'
        WHEN o.persona_trailblazer_base_score >= 60 THEN 'Good'
        WHEN o.persona_trailblazer_base_score >= 40 THEN 'Fair'
        WHEN o.persona_trailblazer_base_score >= 20 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_trailblazer_base_score IS NOT NULL
  AND o.geometry IS NOT NULL
  AND ST_Intersects(o.geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326));  -- Test bbox filter

-- Indexes for TrailBlazer
CREATE INDEX IF NOT EXISTS idx_mv_tb_simplified_z10_geom ON vis.map_persona_trailblazer_simplified_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_simplified_z10_base_score ON vis.map_persona_trailblazer_simplified_z10 (base_score);
CREATE INDEX IF NOT EXISTS idx_mv_tb_simplified_z10_score_class ON vis.map_persona_trailblazer_simplified_z10 (score_class);
CREATE INDEX IF NOT EXISTS idx_mv_tb_simplified_z10_road_type ON vis.map_persona_trailblazer_simplified_z10 (road_type_i1);

-- ============================================================================
-- Persona: TranquilTraveller
-- ============================================================================

CREATE MATERIALIZED VIEW vis.map_persona_tranquiltraveller_simplified_z10 AS
SELECT 
    o.osm_id,
    o.persona_tranquiltraveller_base_score AS base_score,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_i1,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.population_density,
    o.build_perc,
    o.ref,
    o.name,
    (
        COALESCE(o.road_scenery_forest, 0) +
        COALESCE(o.road_scenery_hill, 0) +
        COALESCE(o.road_scenery_lake, 0) +
        COALESCE(o.road_scenery_river, 0) +
        COALESCE(o.road_scenery_mountainpass, 0) +
        COALESCE(o.road_scenery_field, 0)
    ) AS scenery_flags_count,
    CASE 
        WHEN o.persona_tranquiltraveller_base_score IS NULL THEN 'No Data'
        WHEN o.persona_tranquiltraveller_base_score >= 80 THEN 'Excellent'
        WHEN o.persona_tranquiltraveller_base_score >= 60 THEN 'Good'
        WHEN o.persona_tranquiltraveller_base_score >= 40 THEN 'Fair'
        WHEN o.persona_tranquiltraveller_base_score >= 20 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(COALESCE(o.geom_ls, o.geometry), 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_tranquiltraveller_base_score IS NOT NULL
  AND o.geometry IS NOT NULL
  AND ST_Intersects(o.geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326));  -- Test bbox filter

-- Indexes for TranquilTraveller
CREATE INDEX IF NOT EXISTS idx_mv_tt_simplified_z10_geom ON vis.map_persona_tranquiltraveller_simplified_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_simplified_z10_base_score ON vis.map_persona_tranquiltraveller_simplified_z10 (base_score);
CREATE INDEX IF NOT EXISTS idx_mv_tt_simplified_z10_score_class ON vis.map_persona_tranquiltraveller_simplified_z10 (score_class);
CREATE INDEX IF NOT EXISTS idx_mv_tt_simplified_z10_road_type ON vis.map_persona_tranquiltraveller_simplified_z10 (road_type_i1);

-- ============================================================================
-- Summary
-- ============================================================================
-- Created 4 materialized views (z10 only for all personas):
-- - vis.map_persona_milemuncher_simplified_z10
-- - vis.map_persona_cornercraver_simplified_z10
-- - vis.map_persona_trailblazer_simplified_z10
-- - vis.map_persona_tranquiltraveller_simplified_z10
--
-- Each view includes:
-- - base_score (0-100): simplified scoring (direct scaling)
-- - road_type_i1, road_setting_i1, road_classification_i1
-- - length_km, population_density, build_perc
-- - ref, name
-- - score_class (Excellent/Good/Fair/Poor/Very Poor) - based on base_score
-- - Persona-specific fields (twistiness_score, lanes_count, surface, scenery_flags_count)
-- - Simplified geometry (0.0005 tolerance for z10)
--
-- To refresh after persona score updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_persona_<persona>_simplified_z10;
--
-- To use in QGIS:
-- 1. Connect to PostgreSQL database
-- 2. Add layer from database
-- 3. Select schema: vis
-- 4. Select table: map_persona_<persona>_simplified_z10
-- 5. Style by base_score or score_class
-- ============================================================================

