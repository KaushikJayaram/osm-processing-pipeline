-- ============================================================================
-- Persona v2 Parameter Scores & Attributes Visualization Views (z10)
-- ============================================================================
-- This script creates materialized views for persona v2 parameter scores,
-- persona scores, and key road attributes optimized for visualization in QGIS.
-- Views are created at z10 zoom level (medium detail, 0.0005 tolerance).
--
-- This version processes all of India (no BBOX filter).
--
-- Usage: Run this script in pgAdmin Query Tool
-- The script is idempotent - safe to run multiple times.
--
-- Views created:
-- - Parameter Scores
--   - score_cruise_road, score_offroad, score_calm_road, score_flow, score_remoteness, score_twist
--   - score_scenic_wild (TrailBlazer), score_scenic_serene (TranquilTraveller), score_scenic_fast (MM/CC)
-- - 4 Persona Scores (persona_milemuncher_score, persona_cornercraver_score,
--                    persona_trailblazer_score, persona_tranquiltraveller_score)
-- - 4 Normalised Persona Scores (persona_*_score_normalised)
-- - Road Attributes (fourlane, avg_speed_kph, road_type_i1, road_setting_i1, road_classification_v2)
--
-- To refresh views after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_<view_name>_z10;
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;


-- ============================================================================
-- Drop all existing persona v2 views in vis schema (z10 only)
-- ============================================================================

-- Parameter score views
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_cruise_road_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_offroad_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_calm_road_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_flow_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_remoteness_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_twist_z10;
-- Legacy (pre-scenic-v2.1)
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_scenic_z10;
-- Scenic v2.1 (persona-specific)
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_scenic_wild_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_scenic_serene_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_scenic_fast_z10;

-- Persona score views
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_v2_z10;
-- Normalised persona score views
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_v2_norm_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_v2_norm_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_v2_norm_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_v2_norm_z10;

-- Attribute views
DROP MATERIALIZED VIEW IF EXISTS vis.map_fourlane_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_avg_speed_kph_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_type_i1_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_setting_i1_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z10;

-- ============================================================================
-- PARAMETER SCORE VIEWS
-- ============================================================================

-- Cruise Road Score
CREATE MATERIALIZED VIEW vis.map_score_cruise_road_z10 AS
SELECT 
    o.osm_id,
    o.score_cruise_road,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.avg_speed_kph,
    o.fourlane,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_cruise_road IS NULL THEN 'No Data'
        WHEN o.score_cruise_road >= 0.8 THEN 'Excellent'
        WHEN o.score_cruise_road >= 0.6 THEN 'Good'
        WHEN o.score_cruise_road >= 0.4 THEN 'Fair'
        WHEN o.score_cruise_road >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_cruise_road IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_cruise_road_z10_geom ON vis.map_score_cruise_road_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_cruise_road_z10_score ON vis.map_score_cruise_road_z10 (score_cruise_road);
CREATE INDEX IF NOT EXISTS idx_mv_score_cruise_road_z10_class ON vis.map_score_cruise_road_z10 (score_class);

-- Offroad Score
CREATE MATERIALIZED VIEW vis.map_score_offroad_z10 AS
SELECT 
    o.osm_id,
    o.score_offroad,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.tags->>'surface' AS surface,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_offroad IS NULL THEN 'No Data'
        WHEN o.score_offroad >= 0.8 THEN 'Excellent'
        WHEN o.score_offroad >= 0.6 THEN 'Good'
        WHEN o.score_offroad >= 0.4 THEN 'Fair'
        WHEN o.score_offroad >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_offroad IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_offroad_z10_geom ON vis.map_score_offroad_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_offroad_z10_score ON vis.map_score_offroad_z10 (score_offroad);
CREATE INDEX IF NOT EXISTS idx_mv_score_offroad_z10_class ON vis.map_score_offroad_z10 (score_class);

-- Calm Road Score
CREATE MATERIALIZED VIEW vis.map_score_calm_road_z10 AS
SELECT 
    o.osm_id,
    o.score_calm_road,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_calm_road IS NULL THEN 'No Data'
        WHEN o.score_calm_road >= 0.8 THEN 'Excellent'
        WHEN o.score_calm_road >= 0.6 THEN 'Good'
        WHEN o.score_calm_road >= 0.4 THEN 'Fair'
        WHEN o.score_calm_road >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_calm_road IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_calm_road_z10_geom ON vis.map_score_calm_road_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_calm_road_z10_score ON vis.map_score_calm_road_z10 (score_calm_road);
CREATE INDEX IF NOT EXISTS idx_mv_score_calm_road_z10_class ON vis.map_score_calm_road_z10 (score_class);

-- Flow Score
CREATE MATERIALIZED VIEW vis.map_score_flow_z10 AS
SELECT 
    o.osm_id,
    o.score_flow,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.avg_speed_kph,
    o.twistiness_score,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_flow IS NULL THEN 'No Data'
        WHEN o.score_flow >= 0.8 THEN 'Excellent'
        WHEN o.score_flow >= 0.6 THEN 'Good'
        WHEN o.score_flow >= 0.4 THEN 'Fair'
        WHEN o.score_flow >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_flow IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_flow_z10_geom ON vis.map_score_flow_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_flow_z10_score ON vis.map_score_flow_z10 (score_flow);
CREATE INDEX IF NOT EXISTS idx_mv_score_flow_z10_class ON vis.map_score_flow_z10 (score_class);

-- Remoteness Score
CREATE MATERIALIZED VIEW vis.map_score_remoteness_z10 AS
SELECT 
    o.osm_id,
    o.score_remoteness,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_remoteness IS NULL THEN 'No Data'
        WHEN o.score_remoteness >= 0.8 THEN 'Excellent'
        WHEN o.score_remoteness >= 0.6 THEN 'Good'
        WHEN o.score_remoteness >= 0.4 THEN 'Fair'
        WHEN o.score_remoteness >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_remoteness IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_remoteness_z10_geom ON vis.map_score_remoteness_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_remoteness_z10_score ON vis.map_score_remoteness_z10 (score_remoteness);
CREATE INDEX IF NOT EXISTS idx_mv_score_remoteness_z10_class ON vis.map_score_remoteness_z10 (score_class);

-- Twist Score
CREATE MATERIALIZED VIEW vis.map_score_twist_z10 AS
SELECT 
    o.osm_id,
    o.score_twist,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.twistiness_score,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_twist IS NULL THEN 'No Data'
        WHEN o.score_twist >= 0.8 THEN 'Excellent'
        WHEN o.score_twist >= 0.6 THEN 'Good'
        WHEN o.score_twist >= 0.4 THEN 'Fair'
        WHEN o.score_twist >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_twist IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_twist_z10_geom ON vis.map_score_twist_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_twist_z10_score ON vis.map_score_twist_z10 (score_twist);
CREATE INDEX IF NOT EXISTS idx_mv_score_twist_z10_class ON vis.map_score_twist_z10 (score_class);

-- Scenic Score (Wild) - TrailBlazer
CREATE MATERIALIZED VIEW vis.map_score_scenic_wild_z10 AS
SELECT 
    o.osm_id,
    o.score_scenic_wild,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.scenery_v2_confidence,
    o.wc_forest_frac,
    o.wc_field_frac,
    COALESCE(o.road_scenery_hill, 0) AS road_scenery_hill,
    COALESCE(o.road_scenery_river, 0) AS road_scenery_river,
    COALESCE(o.road_scenery_lake, 0) AS road_scenery_lake,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_scenic_wild IS NULL THEN 'No Data'
        WHEN o.score_scenic_wild >= 0.8 THEN 'Excellent'
        WHEN o.score_scenic_wild >= 0.6 THEN 'Good'
        WHEN o.score_scenic_wild >= 0.4 THEN 'Fair'
        WHEN o.score_scenic_wild >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_scenic_wild IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_wild_z10_geom ON vis.map_score_scenic_wild_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_wild_z10_score ON vis.map_score_scenic_wild_z10 (score_scenic_wild);
CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_wild_z10_class ON vis.map_score_scenic_wild_z10 (score_class);

-- Scenic Score (Serene) - TranquilTraveller
CREATE MATERIALIZED VIEW vis.map_score_scenic_serene_z10 AS
SELECT 
    o.osm_id,
    o.score_scenic_serene,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.scenery_v2_confidence,
    o.wc_forest_frac,
    o.wc_field_frac,
    COALESCE(o.road_scenery_hill, 0) AS road_scenery_hill,
    COALESCE(o.road_scenery_river, 0) AS road_scenery_river,
    COALESCE(o.road_scenery_lake, 0) AS road_scenery_lake,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_scenic_serene IS NULL THEN 'No Data'
        WHEN o.score_scenic_serene >= 0.8 THEN 'Excellent'
        WHEN o.score_scenic_serene >= 0.6 THEN 'Good'
        WHEN o.score_scenic_serene >= 0.4 THEN 'Fair'
        WHEN o.score_scenic_serene >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_scenic_serene IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_serene_z10_geom ON vis.map_score_scenic_serene_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_serene_z10_score ON vis.map_score_scenic_serene_z10 (score_scenic_serene);
CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_serene_z10_class ON vis.map_score_scenic_serene_z10 (score_class);

-- Scenic Score (Fast) - MileMuncher / CornerCraver
CREATE MATERIALIZED VIEW vis.map_score_scenic_fast_z10 AS
SELECT 
    o.osm_id,
    o.score_scenic_fast,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.scenery_v2_confidence,
    o.wc_forest_frac,
    COALESCE(o.road_scenery_hill, 0) AS road_scenery_hill,
    COALESCE(o.road_scenery_river, 0) AS road_scenery_river,
    COALESCE(o.road_scenery_lake, 0) AS road_scenery_lake,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.score_scenic_fast IS NULL THEN 'No Data'
        WHEN o.score_scenic_fast >= 0.8 THEN 'Excellent'
        WHEN o.score_scenic_fast >= 0.6 THEN 'Good'
        WHEN o.score_scenic_fast >= 0.4 THEN 'Fair'
        WHEN o.score_scenic_fast >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.score_scenic_fast IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_fast_z10_geom ON vis.map_score_scenic_fast_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_fast_z10_score ON vis.map_score_scenic_fast_z10 (score_scenic_fast);
CREATE INDEX IF NOT EXISTS idx_mv_score_scenic_fast_z10_class ON vis.map_score_scenic_fast_z10 (score_class);

-- ============================================================================
-- PERSONA SCORE VIEWS (V2)
-- ============================================================================

-- MileMuncher Persona v2
CREATE MATERIALIZED VIEW vis.map_persona_milemuncher_v2_z10 AS
SELECT 
    o.osm_id,
    o.persona_milemuncher_score,
    o.persona_milemuncher_score_normalised,
    o.score_urban_gate,
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
    NULLIF(REGEXP_REPLACE(COALESCE(o.lanes, ''), '[^0-9]', '', 'g'), '')::INTEGER AS lanes_count,
    CASE 
        WHEN o.persona_milemuncher_score IS NULL THEN 'No Data'
        WHEN o.persona_milemuncher_score >= 0.8 THEN 'Excellent'
        WHEN o.persona_milemuncher_score >= 0.6 THEN 'Good'
        WHEN o.persona_milemuncher_score >= 0.4 THEN 'Fair'
        WHEN o.persona_milemuncher_score >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_milemuncher_score IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_z10_geom ON vis.map_persona_milemuncher_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_z10_score ON vis.map_persona_milemuncher_v2_z10 (persona_milemuncher_score);
CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_z10_class ON vis.map_persona_milemuncher_v2_z10 (score_class);

-- CornerCraver Persona v2
CREATE MATERIALIZED VIEW vis.map_persona_cornercraver_v2_z10 AS
SELECT 
    o.osm_id,
    o.persona_cornercraver_score,
    o.persona_cornercraver_score_normalised,
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
    CASE 
        WHEN o.persona_cornercraver_score IS NULL THEN 'No Data'
        WHEN o.persona_cornercraver_score >= 0.8 THEN 'Excellent'
        WHEN o.persona_cornercraver_score >= 0.6 THEN 'Good'
        WHEN o.persona_cornercraver_score >= 0.4 THEN 'Fair'
        WHEN o.persona_cornercraver_score >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_cornercraver_score IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_z10_geom ON vis.map_persona_cornercraver_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_z10_score ON vis.map_persona_cornercraver_v2_z10 (persona_cornercraver_score);
CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_z10_class ON vis.map_persona_cornercraver_v2_z10 (score_class);

-- TrailBlazer Persona v2
CREATE MATERIALIZED VIEW vis.map_persona_trailblazer_v2_z10 AS
SELECT 
    o.osm_id,
    o.persona_trailblazer_score,
    o.persona_trailblazer_score_normalised,
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
    (
        COALESCE(o.road_scenery_hill, 0) +
        COALESCE(o.road_scenery_lake, 0) +
        COALESCE(o.road_scenery_beach, 0) +
        COALESCE(o.road_scenery_river, 0) +
        COALESCE(o.road_scenery_forest, 0) +
        COALESCE(o.road_scenery_field, 0)
    ) AS scenery_flags_count,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.persona_trailblazer_score IS NULL THEN 'No Data'
        WHEN o.persona_trailblazer_score >= 0.8 THEN 'Excellent'
        WHEN o.persona_trailblazer_score >= 0.6 THEN 'Good'
        WHEN o.persona_trailblazer_score >= 0.4 THEN 'Fair'
        WHEN o.persona_trailblazer_score >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_trailblazer_score IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_z10_geom ON vis.map_persona_trailblazer_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_z10_score ON vis.map_persona_trailblazer_v2_z10 (persona_trailblazer_score);
CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_z10_class ON vis.map_persona_trailblazer_v2_z10 (score_class);

-- TranquilTraveller Persona v2
CREATE MATERIALIZED VIEW vis.map_persona_tranquiltraveller_v2_z10 AS
SELECT 
    o.osm_id,
    o.persona_tranquiltraveller_score,
    o.persona_tranquiltraveller_score_normalised,
    o.score_calm_road,
    o.score_remoteness,
    o.score_scenic_serene,
    o.scenery_v2_confidence,
    o.wc_forest_frac,
    o.wc_field_frac,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    (
        COALESCE(o.road_scenery_hill, 0) +
        COALESCE(o.road_scenery_lake, 0) +
        COALESCE(o.road_scenery_beach, 0) +
        COALESCE(o.road_scenery_river, 0) +
        COALESCE(o.road_scenery_forest, 0) +
        COALESCE(o.road_scenery_field, 0)
    ) AS scenery_flags_count,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.persona_tranquiltraveller_score IS NULL THEN 'No Data'
        WHEN o.persona_tranquiltraveller_score >= 0.8 THEN 'Excellent'
        WHEN o.persona_tranquiltraveller_score >= 0.6 THEN 'Good'
        WHEN o.persona_tranquiltraveller_score >= 0.4 THEN 'Fair'
        WHEN o.persona_tranquiltraveller_score >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_tranquiltraveller_score IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_z10_geom ON vis.map_persona_tranquiltraveller_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_z10_score ON vis.map_persona_tranquiltraveller_v2_z10 (persona_tranquiltraveller_score);
CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_z10_class ON vis.map_persona_tranquiltraveller_v2_z10 (score_class);

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
    CASE 
        WHEN o.persona_milemuncher_score_normalised IS NULL THEN 'No Data'
        WHEN o.persona_milemuncher_score_normalised >= 0.8 THEN 'Excellent'
        WHEN o.persona_milemuncher_score_normalised >= 0.6 THEN 'Good'
        WHEN o.persona_milemuncher_score_normalised >= 0.4 THEN 'Fair'
        WHEN o.persona_milemuncher_score_normalised >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_milemuncher_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_norm_z10_geom ON vis.map_persona_milemuncher_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_norm_z10_score ON vis.map_persona_milemuncher_v2_norm_z10 (persona_milemuncher_score_normalised);
CREATE INDEX IF NOT EXISTS idx_mv_mm_v2_norm_z10_class ON vis.map_persona_milemuncher_v2_norm_z10 (score_class);

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
    CASE 
        WHEN o.persona_cornercraver_score_normalised IS NULL THEN 'No Data'
        WHEN o.persona_cornercraver_score_normalised >= 0.8 THEN 'Excellent'
        WHEN o.persona_cornercraver_score_normalised >= 0.6 THEN 'Good'
        WHEN o.persona_cornercraver_score_normalised >= 0.4 THEN 'Fair'
        WHEN o.persona_cornercraver_score_normalised >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_cornercraver_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_norm_z10_geom ON vis.map_persona_cornercraver_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_norm_z10_score ON vis.map_persona_cornercraver_v2_norm_z10 (persona_cornercraver_score_normalised);
CREATE INDEX IF NOT EXISTS idx_mv_cc_v2_norm_z10_class ON vis.map_persona_cornercraver_v2_norm_z10 (score_class);

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
    CASE 
        WHEN o.persona_trailblazer_score_normalised IS NULL THEN 'No Data'
        WHEN o.persona_trailblazer_score_normalised >= 0.8 THEN 'Excellent'
        WHEN o.persona_trailblazer_score_normalised >= 0.6 THEN 'Good'
        WHEN o.persona_trailblazer_score_normalised >= 0.4 THEN 'Fair'
        WHEN o.persona_trailblazer_score_normalised >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_trailblazer_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_norm_z10_geom ON vis.map_persona_trailblazer_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_norm_z10_score ON vis.map_persona_trailblazer_v2_norm_z10 (persona_trailblazer_score_normalised);
CREATE INDEX IF NOT EXISTS idx_mv_tb_v2_norm_z10_class ON vis.map_persona_trailblazer_v2_norm_z10 (score_class);

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
    CASE 
        WHEN o.persona_tranquiltraveller_score_normalised IS NULL THEN 'No Data'
        WHEN o.persona_tranquiltraveller_score_normalised >= 0.8 THEN 'Excellent'
        WHEN o.persona_tranquiltraveller_score_normalised >= 0.6 THEN 'Good'
        WHEN o.persona_tranquiltraveller_score_normalised >= 0.4 THEN 'Fair'
        WHEN o.persona_tranquiltraveller_score_normalised >= 0.2 THEN 'Poor'
        ELSE 'Very Poor'
    END AS score_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.persona_tranquiltraveller_score_normalised IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_norm_z10_geom ON vis.map_persona_tranquiltraveller_v2_norm_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_norm_z10_score ON vis.map_persona_tranquiltraveller_v2_norm_z10 (persona_tranquiltraveller_score_normalised);
CREATE INDEX IF NOT EXISTS idx_mv_tt_v2_norm_z10_class ON vis.map_persona_tranquiltraveller_v2_norm_z10 (score_class);

-- ============================================================================
-- ROAD ATTRIBUTE VIEWS
-- ============================================================================

-- Four Lane Classification
CREATE MATERIALIZED VIEW vis.map_fourlane_z10 AS
SELECT 
    o.osm_id,
    o.fourlane,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    NULLIF(REGEXP_REPLACE(COALESCE(o.lanes, ''), '[^0-9]', '', 'g'), '')::INTEGER AS lanes_count,
    UPPER(COALESCE(o.tags->>'oneway', '')) IN ('YES', 'TRUE', '1', '-1') AS is_oneway,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.fourlane IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_fourlane_z10_geom ON vis.map_fourlane_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_fourlane_z10_fourlane ON vis.map_fourlane_z10 (fourlane);

-- Average Speed KPH
CREATE MATERIALIZED VIEW vis.map_avg_speed_kph_z10 AS
SELECT 
    o.osm_id,
    o.avg_speed_kph,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.fourlane,
    NULLIF(REGEXP_REPLACE(COALESCE(o.lanes, ''), '[^0-9]', '', 'g'), '')::INTEGER AS lanes_count,
    o.twistiness_score,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    CASE 
        WHEN o.avg_speed_kph IS NULL THEN 'No Data'
        WHEN o.avg_speed_kph >= 80 THEN 'Very High (80+)'
        WHEN o.avg_speed_kph >= 60 THEN 'High (60-80)'
        WHEN o.avg_speed_kph >= 40 THEN 'Medium (40-60)'
        WHEN o.avg_speed_kph >= 20 THEN 'Low (20-40)'
        ELSE 'Very Low (<20)'
    END AS speed_class,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.avg_speed_kph IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_avg_speed_z10_geom ON vis.map_avg_speed_kph_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_avg_speed_z10_speed ON vis.map_avg_speed_kph_z10 (avg_speed_kph);
CREATE INDEX IF NOT EXISTS idx_mv_avg_speed_z10_class ON vis.map_avg_speed_kph_z10 (speed_class);

-- Road Type I1
CREATE MATERIALIZED VIEW vis.map_road_type_i1_z10 AS
SELECT 
    o.osm_id,
    o.road_type_i1,
    o.road_setting_i1,
    o.road_classification_v2,
    o.highway,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.road_type_i1 IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_road_type_z10_geom ON vis.map_road_type_i1_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_road_type_z10_type ON vis.map_road_type_i1_z10 (road_type_i1);

-- Road Setting I1
CREATE MATERIALIZED VIEW vis.map_road_setting_i1_z10 AS
SELECT 
    o.osm_id,
    o.road_setting_i1,
    o.road_type_i1,
    o.road_classification_v2,
    o.population_density,
    o.build_perc,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.road_setting_i1 IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_road_setting_z10_geom ON vis.map_road_setting_i1_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_road_setting_z10_setting ON vis.map_road_setting_i1_z10 (road_setting_i1);

-- Road Classification V2
CREATE MATERIALIZED VIEW vis.map_road_classification_v2_z10 AS
SELECT 
    o.osm_id,
    o.road_classification_v2,
    o.road_type_i1,
    o.road_setting_i1,
    o.highway,
    o.avg_speed_kph,
    o.fourlane,
    ST_Length(o.geometry::geography) / 1000.0 AS length_km,
    o.ref,
    o.name,
    ST_SimplifyPreserveTopology(o.geometry, 0.0005) AS geom
FROM osm_all_roads o
WHERE o.bikable_road = TRUE 
  AND o.road_classification_v2 IS NOT NULL
  AND o.geometry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_road_class_v2_z10_geom ON vis.map_road_classification_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_road_class_v2_z10_class ON vis.map_road_classification_v2_z10 (road_classification_v2);

-- ============================================================================
-- Summary
-- ============================================================================
-- Created 22 materialized views at z10 zoom level:
--
-- PARAMETER SCORES (9 views):
-- - vis.map_score_cruise_road_z10
-- - vis.map_score_offroad_z10
-- - vis.map_score_calm_road_z10
-- - vis.map_score_flow_z10
-- - vis.map_score_remoteness_z10
-- - vis.map_score_twist_z10
-- - vis.map_score_scenic_wild_z10
-- - vis.map_score_scenic_serene_z10
-- - vis.map_score_scenic_fast_z10
--
-- PERSONA SCORES V2 (4 views):
-- - vis.map_persona_milemuncher_v2_z10
-- - vis.map_persona_cornercraver_v2_z10
-- - vis.map_persona_trailblazer_v2_z10
-- - vis.map_persona_tranquiltraveller_v2_z10
--
-- PERSONA SCORES V2 (NORMALISED) (4 views):
-- - vis.map_persona_milemuncher_v2_norm_z10
-- - vis.map_persona_cornercraver_v2_norm_z10
-- - vis.map_persona_trailblazer_v2_norm_z10
-- - vis.map_persona_tranquiltraveller_v2_norm_z10
--
-- ROAD ATTRIBUTES (5 views):
-- - vis.map_fourlane_z10
-- - vis.map_avg_speed_kph_z10
-- - vis.map_road_type_i1_z10
-- - vis.map_road_setting_i1_z10
-- - vis.map_road_classification_v2_z10
--
-- Each view includes:
-- - Relevant score/attribute value
-- - Supporting contextual fields
-- - Simplified geometry (0.0005 tolerance for z10)
-- - Score/value classification where applicable
-- - Spatial and attribute indexes for performance
--
-- To refresh after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_<view_name>_z10;
--
-- To use in QGIS:
-- 1. Connect to PostgreSQL database
-- 2. Add layer from database
-- 3. Select schema: vis
-- 4. Select table: map_<view_name>_z10
-- 5. Style by score/attribute or classification
-- ============================================================================
