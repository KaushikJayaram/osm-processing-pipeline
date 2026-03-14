-- ============================================================================
-- Drop All Visualization Materialized Views
-- ============================================================================
-- This script drops all existing materialized views in the vis schema.
-- Run this before creating new visualization views.
--
-- Usage: Run this script in pgAdmin Query Tool
-- ============================================================================

-- Ensure schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- Drop all existing materialized views in vis schema
DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_congestion_factor_z10;

-- Persona scores
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_z14;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_z14;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_z14;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_z14;

-- Road classification
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_i1_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_i1_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_i1_z14;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z14;

-- Grid overlap
DROP MATERIALIZED VIEW IF EXISTS vis.map_grid_overlap_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_grid_overlap_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_grid_overlap_z14;

-- Curvature
DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_z14;
DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_v2_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_v2_z14;

-- Intersection density
DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z6;
DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z14;

-- Persona v2 parameter scores
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_urban_gate_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_cruise_road_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_offroad_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_calm_road_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_flow_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_remoteness_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_twist_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_score_scenic_z10;

-- Persona v2 scores
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_v2_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_v2_z10;

-- Road attributes
DROP MATERIALIZED VIEW IF EXISTS vis.map_fourlane_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_avg_speed_kph_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_type_i1_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_setting_i1_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z10;

-- Simplified persona scores
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_simplified_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_simplified_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_simplified_z10;
DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_simplified_z10;

-- Urban grids
DROP MATERIALIZED VIEW IF EXISTS vis.map_urban_grids_z10;

-- ============================================================================
-- Summary
-- ============================================================================
-- All existing materialized views in vis schema have been dropped.
-- You can now create new visualization views.

