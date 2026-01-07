-- ============================================================================
-- Visualization Views for OSM Road Data - CHUNKED VERSION
-- ============================================================================
-- This script is split into chunks to avoid disk space issues.
-- Run each chunk separately and check disk space between chunks.
-- The script is idempotent - safe to run multiple times.
--
-- IMPORTANT: Check disk space before running each chunk:
--   df -h /System/Volumes/Data
--
-- If disk space is low (< 10GB free), clean up before continuing.
-- ============================================================================

-- ============================================================================
-- CHUNK 0: Setup (Always run this first)
-- ============================================================================
-- Schema and base view (lightweight, no materialized views)
CREATE SCHEMA IF NOT EXISTS vis;

-- Note: Using CREATE OR REPLACE VIEW to preserve dependencies
-- Adding intersection_density_per_km at the end to avoid column position conflicts
CREATE OR REPLACE VIEW vis.roads_base AS
SELECT
  osm_id,
  way_id,
  highway,
  ref,
  name,
  bikable_road,
  road_setting_i1,
  road_type_i1,
  road_classification_i1,
  road_classification_v2,
  road_classification, -- legacy
  final_road_classification_from_grid_overlap,
  -- Curvature metrics (legacy v1)
  road_curvature_classification,
  road_curvature_ratio,
  -- Curvature metrics (v2)
  twistiness_score,
  twistiness_class,
  meters_sharp,
  meters_broad,
  meters_straight,
  -- Intersection density (keep existing column position for compatibility)
  persona_factor_intersection_density,  -- Normalized factor (0-1, inverted: high density = low score)
  -- Persona scores
  persona_milemuncher_base_score,
  persona_milemuncher_corridor_km,
  persona_milemuncher_final_score,
  persona_cornercraver_base_score,
  persona_cornercraver_corridor_km,
  persona_cornercraver_final_score,
  persona_trailblazer_base_score,
  persona_trailblazer_corridor_km,
  persona_trailblazer_final_score,
  persona_tranquiltraveller_base_score,
  persona_tranquiltraveller_corridor_km,
  persona_tranquiltraveller_final_score,
  -- Persona factors
  persona_factor_low_pop_score,
  persona_factor_low_build_score,
  persona_factor_urban_stress,
  persona_factor_twist_norm,
  persona_factor_twist_extreme,
  persona_factor_scenery_score,
  persona_factor_surface_good,
  persona_factor_hadj_penalty,
  persona_factor_speed_kph,
  persona_factor_speed_norm,
  persona_factor_major_road_score,
  persona_factor_exploration_score,
  -- Environment
  population_density,
  build_perc,
  COALESCE(geom_ls, geometry) AS geom,
  -- Intersection density raw value (added at end to avoid dependency issues)
  intersection_density_per_km  -- Raw density (weighted by intersection type)
FROM public.osm_all_roads
WHERE bikable_road IS TRUE
  AND highway IS NOT NULL;

-- Helper: choose simplify tolerances (degrees)
-- z6 ≈ 0.002 (~200 m), z10 ≈ 0.0005 (~50 m), z14 = full

-- ============================================================================
-- CHUNK 1: Road Classification i1 (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)
-- Run this chunk, then check disk space before proceeding

DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_i1_z6;
CREATE MATERIALIZED VIEW vis.map_road_classification_i1_z6 AS
SELECT osm_id, road_classification_i1 AS class_label,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE road_classification_i1 IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_i1_z10;
CREATE MATERIALIZED VIEW vis.map_road_classification_i1_z10 AS
SELECT osm_id, road_classification_i1 AS class_label,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE road_classification_i1 IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_i1_z14;
CREATE MATERIALIZED VIEW vis.map_road_classification_i1_z14 AS
SELECT osm_id, road_classification_i1 AS class_label,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE road_classification_i1 IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_i1_z6_geom  ON vis.map_road_classification_i1_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z10_geom ON vis.map_road_classification_i1_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z14_geom ON vis.map_road_classification_i1_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z6_lbl   ON vis.map_road_classification_i1_z6  (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z10_lbl  ON vis.map_road_classification_i1_z10 (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z14_lbl  ON vis.map_road_classification_i1_z14 (class_label);

-- ============================================================================
-- CHUNK 2: Road Classification v2 (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z6;
CREATE MATERIALIZED VIEW vis.map_road_classification_v2_z6 AS
SELECT osm_id, road_classification_v2 AS class_label,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE road_classification_v2 IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z10;
CREATE MATERIALIZED VIEW vis.map_road_classification_v2_z10 AS
SELECT osm_id, road_classification_v2 AS class_label,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE road_classification_v2 IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_road_classification_v2_z14;
CREATE MATERIALIZED VIEW vis.map_road_classification_v2_z14 AS
SELECT osm_id, road_classification_v2 AS class_label,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE road_classification_v2 IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_v2_z6_geom  ON vis.map_road_classification_v2_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_v2_z10_geom ON vis.map_road_classification_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_v2_z14_geom ON vis.map_road_classification_v2_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_v2_z6_lbl   ON vis.map_road_classification_v2_z6  (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_v2_z10_lbl  ON vis.map_road_classification_v2_z10 (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_v2_z14_lbl  ON vis.map_road_classification_v2_z14 (class_label);

-- ============================================================================
-- CHUNK 3: Grid Overlap Classification (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_grid_overlap_z6;
CREATE MATERIALIZED VIEW vis.map_grid_overlap_z6 AS
SELECT osm_id, final_road_classification_from_grid_overlap AS class_label,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE final_road_classification_from_grid_overlap IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_grid_overlap_z10;
CREATE MATERIALIZED VIEW vis.map_grid_overlap_z10 AS
SELECT osm_id, final_road_classification_from_grid_overlap AS class_label,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE final_road_classification_from_grid_overlap IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_grid_overlap_z14;
CREATE MATERIALIZED VIEW vis.map_grid_overlap_z14 AS
SELECT osm_id, final_road_classification_from_grid_overlap AS class_label,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE final_road_classification_from_grid_overlap IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_grid_z6_geom  ON vis.map_grid_overlap_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_grid_z10_geom ON vis.map_grid_overlap_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_grid_z14_geom ON vis.map_grid_overlap_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_grid_z6_lbl   ON vis.map_grid_overlap_z6  (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_grid_z10_lbl  ON vis.map_grid_overlap_z10 (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_grid_z14_lbl  ON vis.map_grid_overlap_z14 (class_label);

-- ============================================================================
-- CHUNK 4: Curvature v1 (Legacy) (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_z6;
CREATE MATERIALIZED VIEW vis.map_curvature_z6 AS
SELECT osm_id, road_curvature_classification AS class_label,
       population_density, build_perc, road_curvature_ratio,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE road_curvature_classification IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_z10;
CREATE MATERIALIZED VIEW vis.map_curvature_z10 AS
SELECT osm_id, road_curvature_classification AS class_label,
       population_density, build_perc, road_curvature_ratio,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE road_curvature_classification IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_z14;
CREATE MATERIALIZED VIEW vis.map_curvature_z14 AS
SELECT osm_id, road_curvature_classification AS class_label,
       population_density, build_perc, road_curvature_ratio,
       geom
FROM vis.roads_base
WHERE road_curvature_classification IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_curv_z6_geom  ON vis.map_curvature_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_curv_z10_geom ON vis.map_curvature_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_curv_z14_geom ON vis.map_curvature_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_curv_z6_lbl   ON vis.map_curvature_z6  (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_curv_z10_lbl  ON vis.map_curvature_z10 (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_curv_z14_lbl  ON vis.map_curvature_z14 (class_label);

-- ============================================================================
-- CHUNK 5: Intersection Density (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z6;
CREATE MATERIALIZED VIEW vis.map_intersection_density_z6 AS
SELECT osm_id, 
       intersection_density_per_km AS density_per_km,  -- Raw density value
       persona_factor_intersection_density AS density_factor,  -- Normalized factor (0-1, inverted)
       CASE 
           WHEN intersection_density_per_km IS NULL THEN 'No Data'
           WHEN intersection_density_per_km = 0 THEN 'None'
           WHEN intersection_density_per_km <= 1.0 THEN 'Very Low'
           WHEN intersection_density_per_km <= 5.0 THEN 'Low'
           WHEN intersection_density_per_km <= 15.0 THEN 'Medium'
           WHEN intersection_density_per_km <= 30.0 THEN 'High'
           ELSE 'Very High'
       END AS density_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE intersection_density_per_km IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z10;
CREATE MATERIALIZED VIEW vis.map_intersection_density_z10 AS
SELECT osm_id, 
       intersection_density_per_km AS density_per_km,  -- Raw density value
       persona_factor_intersection_density AS density_factor,  -- Normalized factor (0-1, inverted)
       CASE 
           WHEN intersection_density_per_km IS NULL THEN 'No Data'
           WHEN intersection_density_per_km = 0 THEN 'None'
           WHEN intersection_density_per_km <= 1.0 THEN 'Very Low'
           WHEN intersection_density_per_km <= 5.0 THEN 'Low'
           WHEN intersection_density_per_km <= 15.0 THEN 'Medium'
           WHEN intersection_density_per_km <= 30.0 THEN 'High'
           ELSE 'Very High'
       END AS density_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE intersection_density_per_km IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z14;
CREATE MATERIALIZED VIEW vis.map_intersection_density_z14 AS
SELECT osm_id, 
       intersection_density_per_km AS density_per_km,  -- Raw density value
       persona_factor_intersection_density AS density_factor,  -- Normalized factor (0-1, inverted)
       CASE 
           WHEN intersection_density_per_km IS NULL THEN 'No Data'
           WHEN intersection_density_per_km = 0 THEN 'None'
           WHEN intersection_density_per_km <= 1.0 THEN 'Very Low'
           WHEN intersection_density_per_km <= 5.0 THEN 'Low'
           WHEN intersection_density_per_km <= 15.0 THEN 'Medium'
           WHEN intersection_density_per_km <= 30.0 THEN 'High'
           ELSE 'Very High'
       END AS density_class,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE intersection_density_per_km IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_intdens_z6_geom  ON vis.map_intersection_density_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z10_geom ON vis.map_intersection_density_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z14_geom ON vis.map_intersection_density_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z6_density ON vis.map_intersection_density_z6  (density_per_km);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z10_density ON vis.map_intersection_density_z10 (density_per_km);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z14_density ON vis.map_intersection_density_z14 (density_per_km);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z6_class ON vis.map_intersection_density_z6  (density_class);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z10_class ON vis.map_intersection_density_z10 (density_class);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z14_class ON vis.map_intersection_density_z14 (density_class);

-- ============================================================================
-- CHUNK 6: Curvature v2 (Twistiness) (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_v2_z6;
CREATE MATERIALIZED VIEW vis.map_curvature_v2_z6 AS
SELECT osm_id, 
       twistiness_score,
       twistiness_class,
       meters_sharp,
       meters_broad,
       meters_straight,
       road_curvature_ratio AS curvature_ratio_v1,  -- Legacy for comparison
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE twistiness_score IS NOT NULL OR twistiness_class IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_v2_z10;
CREATE MATERIALIZED VIEW vis.map_curvature_v2_z10 AS
SELECT osm_id, 
       twistiness_score,
       twistiness_class,
       meters_sharp,
       meters_broad,
       meters_straight,
       road_curvature_ratio AS curvature_ratio_v1,  -- Legacy for comparison
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE twistiness_score IS NOT NULL OR twistiness_class IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_curvature_v2_z14;
CREATE MATERIALIZED VIEW vis.map_curvature_v2_z14 AS
SELECT osm_id, 
       twistiness_score,
       twistiness_class,
       meters_sharp,
       meters_broad,
       meters_straight,
       road_curvature_ratio AS curvature_ratio_v1,  -- Legacy for comparison
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE twistiness_score IS NOT NULL OR twistiness_class IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_curv2_z6_geom  ON vis.map_curvature_v2_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_curv2_z10_geom ON vis.map_curvature_v2_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_curv2_z14_geom ON vis.map_curvature_v2_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_curv2_z6_class ON vis.map_curvature_v2_z6  (twistiness_class);
CREATE INDEX IF NOT EXISTS idx_mv_curv2_z10_class ON vis.map_curvature_v2_z10 (twistiness_class);
CREATE INDEX IF NOT EXISTS idx_mv_curv2_z14_class ON vis.map_curvature_v2_z14 (twistiness_class);

-- ============================================================================
-- CHUNK 7: Persona MileMuncher (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_z6;
CREATE MATERIALIZED VIEW vis.map_persona_milemuncher_z6 AS
SELECT osm_id, 
       persona_milemuncher_base_score,
       persona_milemuncher_corridor_km,
       persona_milemuncher_final_score,
       CASE 
           WHEN persona_milemuncher_final_score IS NULL THEN 'No Data'
           WHEN persona_milemuncher_final_score >= 80 THEN 'Excellent'
           WHEN persona_milemuncher_final_score >= 60 THEN 'Good'
           WHEN persona_milemuncher_final_score >= 40 THEN 'Fair'
           WHEN persona_milemuncher_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE persona_milemuncher_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_z10;
CREATE MATERIALIZED VIEW vis.map_persona_milemuncher_z10 AS
SELECT osm_id, 
       persona_milemuncher_base_score,
       persona_milemuncher_corridor_km,
       persona_milemuncher_final_score,
       CASE 
           WHEN persona_milemuncher_final_score IS NULL THEN 'No Data'
           WHEN persona_milemuncher_final_score >= 80 THEN 'Excellent'
           WHEN persona_milemuncher_final_score >= 60 THEN 'Good'
           WHEN persona_milemuncher_final_score >= 40 THEN 'Fair'
           WHEN persona_milemuncher_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE persona_milemuncher_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_milemuncher_z14;
CREATE MATERIALIZED VIEW vis.map_persona_milemuncher_z14 AS
SELECT osm_id, 
       persona_milemuncher_base_score,
       persona_milemuncher_corridor_km,
       persona_milemuncher_final_score,
       CASE 
           WHEN persona_milemuncher_final_score IS NULL THEN 'No Data'
           WHEN persona_milemuncher_final_score >= 80 THEN 'Excellent'
           WHEN persona_milemuncher_final_score >= 60 THEN 'Good'
           WHEN persona_milemuncher_final_score >= 40 THEN 'Fair'
           WHEN persona_milemuncher_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE persona_milemuncher_final_score IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_mm_z6_geom  ON vis.map_persona_milemuncher_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_z10_geom ON vis.map_persona_milemuncher_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_z14_geom ON vis.map_persona_milemuncher_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_mm_z6_score ON vis.map_persona_milemuncher_z6  (persona_milemuncher_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_mm_z10_score ON vis.map_persona_milemuncher_z10 (persona_milemuncher_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_mm_z14_score ON vis.map_persona_milemuncher_z14 (persona_milemuncher_final_score);

-- ============================================================================
-- CHUNK 8: Persona CornerCraver (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_z6;
CREATE MATERIALIZED VIEW vis.map_persona_cornercraver_z6 AS
SELECT osm_id, 
       persona_cornercraver_base_score,
       persona_cornercraver_corridor_km,
       persona_cornercraver_final_score,
       CASE 
           WHEN persona_cornercraver_final_score IS NULL THEN 'No Data'
           WHEN persona_cornercraver_final_score >= 80 THEN 'Excellent'
           WHEN persona_cornercraver_final_score >= 60 THEN 'Good'
           WHEN persona_cornercraver_final_score >= 40 THEN 'Fair'
           WHEN persona_cornercraver_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE persona_cornercraver_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_z10;
CREATE MATERIALIZED VIEW vis.map_persona_cornercraver_z10 AS
SELECT osm_id, 
       persona_cornercraver_base_score,
       persona_cornercraver_corridor_km,
       persona_cornercraver_final_score,
       CASE 
           WHEN persona_cornercraver_final_score IS NULL THEN 'No Data'
           WHEN persona_cornercraver_final_score >= 80 THEN 'Excellent'
           WHEN persona_cornercraver_final_score >= 60 THEN 'Good'
           WHEN persona_cornercraver_final_score >= 40 THEN 'Fair'
           WHEN persona_cornercraver_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE persona_cornercraver_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_cornercraver_z14;
CREATE MATERIALIZED VIEW vis.map_persona_cornercraver_z14 AS
SELECT osm_id, 
       persona_cornercraver_base_score,
       persona_cornercraver_corridor_km,
       persona_cornercraver_final_score,
       CASE 
           WHEN persona_cornercraver_final_score IS NULL THEN 'No Data'
           WHEN persona_cornercraver_final_score >= 80 THEN 'Excellent'
           WHEN persona_cornercraver_final_score >= 60 THEN 'Good'
           WHEN persona_cornercraver_final_score >= 40 THEN 'Fair'
           WHEN persona_cornercraver_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE persona_cornercraver_final_score IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_cc_z6_geom  ON vis.map_persona_cornercraver_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_z10_geom ON vis.map_persona_cornercraver_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_z14_geom ON vis.map_persona_cornercraver_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_cc_z6_score ON vis.map_persona_cornercraver_z6  (persona_cornercraver_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_cc_z10_score ON vis.map_persona_cornercraver_z10 (persona_cornercraver_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_cc_z14_score ON vis.map_persona_cornercraver_z14 (persona_cornercraver_final_score);

-- ============================================================================
-- CHUNK 9: Persona TrailBlazer (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_z6;
CREATE MATERIALIZED VIEW vis.map_persona_trailblazer_z6 AS
SELECT osm_id, 
       persona_trailblazer_base_score,
       persona_trailblazer_corridor_km,
       persona_trailblazer_final_score,
       CASE 
           WHEN persona_trailblazer_final_score IS NULL THEN 'No Data'
           WHEN persona_trailblazer_final_score >= 80 THEN 'Excellent'
           WHEN persona_trailblazer_final_score >= 60 THEN 'Good'
           WHEN persona_trailblazer_final_score >= 40 THEN 'Fair'
           WHEN persona_trailblazer_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE persona_trailblazer_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_z10;
CREATE MATERIALIZED VIEW vis.map_persona_trailblazer_z10 AS
SELECT osm_id, 
       persona_trailblazer_base_score,
       persona_trailblazer_corridor_km,
       persona_trailblazer_final_score,
       CASE 
           WHEN persona_trailblazer_final_score IS NULL THEN 'No Data'
           WHEN persona_trailblazer_final_score >= 80 THEN 'Excellent'
           WHEN persona_trailblazer_final_score >= 60 THEN 'Good'
           WHEN persona_trailblazer_final_score >= 40 THEN 'Fair'
           WHEN persona_trailblazer_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE persona_trailblazer_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_trailblazer_z14;
CREATE MATERIALIZED VIEW vis.map_persona_trailblazer_z14 AS
SELECT osm_id, 
       persona_trailblazer_base_score,
       persona_trailblazer_corridor_km,
       persona_trailblazer_final_score,
       CASE 
           WHEN persona_trailblazer_final_score IS NULL THEN 'No Data'
           WHEN persona_trailblazer_final_score >= 80 THEN 'Excellent'
           WHEN persona_trailblazer_final_score >= 60 THEN 'Good'
           WHEN persona_trailblazer_final_score >= 40 THEN 'Fair'
           WHEN persona_trailblazer_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE persona_trailblazer_final_score IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tb_z6_geom  ON vis.map_persona_trailblazer_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_z10_geom ON vis.map_persona_trailblazer_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_z14_geom ON vis.map_persona_trailblazer_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tb_z6_score ON vis.map_persona_trailblazer_z6  (persona_trailblazer_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_tb_z10_score ON vis.map_persona_trailblazer_z10 (persona_trailblazer_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_tb_z14_score ON vis.map_persona_trailblazer_z14 (persona_trailblazer_final_score);

-- ============================================================================
-- CHUNK 10: Persona TranquilTraveller (3 views: z6, z10, z14)
-- ============================================================================
-- Estimated disk usage: Medium (3 materialized views)
-- LAST CHUNK - Check disk space before running

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_z6;
CREATE MATERIALIZED VIEW vis.map_persona_tranquiltraveller_z6 AS
SELECT osm_id, 
       persona_tranquiltraveller_base_score,
       persona_tranquiltraveller_corridor_km,
       persona_tranquiltraveller_final_score,
       CASE 
           WHEN persona_tranquiltraveller_final_score IS NULL THEN 'No Data'
           WHEN persona_tranquiltraveller_final_score >= 80 THEN 'Excellent'
           WHEN persona_tranquiltraveller_final_score >= 60 THEN 'Good'
           WHEN persona_tranquiltraveller_final_score >= 40 THEN 'Fair'
           WHEN persona_tranquiltraveller_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE persona_tranquiltraveller_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_z10;
CREATE MATERIALIZED VIEW vis.map_persona_tranquiltraveller_z10 AS
SELECT osm_id, 
       persona_tranquiltraveller_base_score,
       persona_tranquiltraveller_corridor_km,
       persona_tranquiltraveller_final_score,
       CASE 
           WHEN persona_tranquiltraveller_final_score IS NULL THEN 'No Data'
           WHEN persona_tranquiltraveller_final_score >= 80 THEN 'Excellent'
           WHEN persona_tranquiltraveller_final_score >= 60 THEN 'Good'
           WHEN persona_tranquiltraveller_final_score >= 40 THEN 'Fair'
           WHEN persona_tranquiltraveller_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE persona_tranquiltraveller_final_score IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_persona_tranquiltraveller_z14;
CREATE MATERIALIZED VIEW vis.map_persona_tranquiltraveller_z14 AS
SELECT osm_id, 
       persona_tranquiltraveller_base_score,
       persona_tranquiltraveller_corridor_km,
       persona_tranquiltraveller_final_score,
       CASE 
           WHEN persona_tranquiltraveller_final_score IS NULL THEN 'No Data'
           WHEN persona_tranquiltraveller_final_score >= 80 THEN 'Excellent'
           WHEN persona_tranquiltraveller_final_score >= 60 THEN 'Good'
           WHEN persona_tranquiltraveller_final_score >= 40 THEN 'Fair'
           WHEN persona_tranquiltraveller_final_score >= 20 THEN 'Poor'
           ELSE 'Very Poor'
       END AS score_class,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE persona_tranquiltraveller_final_score IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_tt_z6_geom  ON vis.map_persona_tranquiltraveller_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_z10_geom ON vis.map_persona_tranquiltraveller_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_z14_geom ON vis.map_persona_tranquiltraveller_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_tt_z6_score ON vis.map_persona_tranquiltraveller_z6  (persona_tranquiltraveller_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_tt_z10_score ON vis.map_persona_tranquiltraveller_z10 (persona_tranquiltraveller_final_score);
CREATE INDEX IF NOT EXISTS idx_mv_tt_z14_score ON vis.map_persona_tranquiltraveller_z14 (persona_tranquiltraveller_final_score);

-- ============================================================================
-- Refresh pattern (for future updates):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_road_classification_i1_z6;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_intersection_density_z6;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_curvature_v2_z6;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_persona_milemuncher_z6;
-- (repeat for others as needed)
-- ============================================================================

