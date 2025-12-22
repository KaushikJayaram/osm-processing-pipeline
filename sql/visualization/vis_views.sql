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
  road_curvature_classification,
  road_curvature_ratio,
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

-- 6) Helpful comment: refresh pattern
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_road_classification_i1_z6;
-- (repeat for others as needed)