-- ============================================================================
-- Visualization Views for OSM Road Data
-- ============================================================================
-- This script creates materialized views optimized for visualization in QGIS
-- or other GIS tools. Views are created at multiple zoom levels (z6, z10, z14)
-- for performance optimization.
--
-- Usage: Copy and paste this entire script into pgAdmin Query Tool and execute.
-- The script is idempotent - safe to run multiple times.
--
-- Views created:
-- 1. Base view: vis.roads_base (contains all columns)
-- 2. Road classification views (i1, v2, grid overlap)
-- 3. Curvature views (legacy v1 and v2)
-- 4. Intersection density views
-- 5. Persona score views (MileMuncher, CornerCraver, TrailBlazer, TranquilTraveller)
--
-- To refresh views after data updates:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_<view_name>_z6;
-- ============================================================================

-- 0) Schema (idempotent)
CREATE SCHEMA IF NOT EXISTS vis;

-- 1) Base view (read-only; QGIS should use vis.*)
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
  -- Intersection density
  persona_factor_intersection_density,
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
  COALESCE(geom_ls, geometry) AS geom
FROM public.osm_all_roads
WHERE bikable_road IS TRUE
  AND highway IS NOT NULL;

-- Helper: choose simplify tolerances (degrees)
-- z6 ≈ 0.002 (~200 m), z10 ≈ 0.0005 (~50 m), z14 = full

-- 2) Materialized views for road_classification_i1
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

-- Indexes to speed rendering
CREATE INDEX IF NOT EXISTS idx_mv_i1_z6_geom  ON vis.map_road_classification_i1_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z10_geom ON vis.map_road_classification_i1_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z14_geom ON vis.map_road_classification_i1_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z6_lbl   ON vis.map_road_classification_i1_z6  (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z10_lbl  ON vis.map_road_classification_i1_z10 (class_label);
CREATE INDEX IF NOT EXISTS idx_mv_i1_z14_lbl  ON vis.map_road_classification_i1_z14 (class_label);

-- 3) Materialized views for road_classification_v2
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

-- 4) Materialized views for final_road_classification_from_grid_overlap
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

-- 5) Materialized views for road_curvature_classification (if populated)
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

-- 6) Materialized views for intersection density
DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z6;
CREATE MATERIALIZED VIEW vis.map_intersection_density_z6 AS
SELECT osm_id, 
       persona_factor_intersection_density AS density_value,
       CASE 
           WHEN persona_factor_intersection_density IS NULL THEN 'No Data'
           WHEN persona_factor_intersection_density >= 0.8 THEN 'Very High'
           WHEN persona_factor_intersection_density >= 0.6 THEN 'High'
           WHEN persona_factor_intersection_density >= 0.4 THEN 'Medium'
           WHEN persona_factor_intersection_density >= 0.2 THEN 'Low'
           ELSE 'Very Low'
       END AS density_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.002) AS geom
FROM vis.roads_base
WHERE persona_factor_intersection_density IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z10;
CREATE MATERIALIZED VIEW vis.map_intersection_density_z10 AS
SELECT osm_id, 
       persona_factor_intersection_density AS density_value,
       CASE 
           WHEN persona_factor_intersection_density IS NULL THEN 'No Data'
           WHEN persona_factor_intersection_density >= 0.8 THEN 'Very High'
           WHEN persona_factor_intersection_density >= 0.6 THEN 'High'
           WHEN persona_factor_intersection_density >= 0.4 THEN 'Medium'
           WHEN persona_factor_intersection_density >= 0.2 THEN 'Low'
           ELSE 'Very Low'
       END AS density_class,
       population_density, build_perc,
       ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.roads_base
WHERE persona_factor_intersection_density IS NOT NULL;

DROP MATERIALIZED VIEW IF EXISTS vis.map_intersection_density_z14;
CREATE MATERIALIZED VIEW vis.map_intersection_density_z14 AS
SELECT osm_id, 
       persona_factor_intersection_density AS density_value,
       CASE 
           WHEN persona_factor_intersection_density IS NULL THEN 'No Data'
           WHEN persona_factor_intersection_density >= 0.8 THEN 'Very High'
           WHEN persona_factor_intersection_density >= 0.6 THEN 'High'
           WHEN persona_factor_intersection_density >= 0.4 THEN 'Medium'
           WHEN persona_factor_intersection_density >= 0.2 THEN 'Low'
           ELSE 'Very Low'
       END AS density_class,
       population_density, build_perc,
       geom
FROM vis.roads_base
WHERE persona_factor_intersection_density IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mv_intdens_z6_geom  ON vis.map_intersection_density_z6  USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z10_geom ON vis.map_intersection_density_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z14_geom ON vis.map_intersection_density_z14 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z6_val   ON vis.map_intersection_density_z6  (density_value);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z10_val  ON vis.map_intersection_density_z10 (density_value);
CREATE INDEX IF NOT EXISTS idx_mv_intdens_z14_val  ON vis.map_intersection_density_z14 (density_value);

-- 7) Materialized views for curvature v2 (twistiness)
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

-- 8) Materialized views for persona scores (MileMuncher)
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

-- 9) Materialized views for persona scores (CornerCraver)
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

-- 10) Materialized views for persona scores (TrailBlazer)
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

-- 11) Materialized views for persona scores (TranquilTraveller)
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

-- 12) Helpful comment: refresh pattern
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_road_classification_i1_z6;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_intersection_density_z6;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_curvature_v2_z6;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_persona_milemuncher_z6;
-- (repeat for others as needed)