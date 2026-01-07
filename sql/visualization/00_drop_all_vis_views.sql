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

-- ============================================================================
-- Summary
-- ============================================================================
-- All existing materialized views in vis schema have been dropped.
-- You can now create new visualization views.

