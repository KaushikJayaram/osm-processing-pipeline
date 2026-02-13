-- ============================================================================
-- Visualization Views for Urban Pressure Grid Classification
-- ============================================================================
-- Creates materialized views for grid-level urban classification and factors.
-- Usage: Run in pgAdmin or psql. Safe to re-run (drops and recreates views).
-- ============================================================================

-- Ensure visualization schema exists
CREATE SCHEMA IF NOT EXISTS vis;

-- Base view for grid-level attributes
CREATE OR REPLACE VIEW vis.urban_grids_base AS
SELECT
  grid_id,
  grid_geom AS geom,
  grid_area_m2,
  centroid,
  pop_count,
  pop_density,
  built_up_m2,
  built_up_fraction,
  pd_norm,
  bu_norm,
  urban_pressure,
  reinforced_pressure,
  urban_class
FROM public.india_grids
WHERE grid_geom IS NOT NULL;


-- z10 (~50m)
DROP MATERIALIZED VIEW IF EXISTS vis.map_urban_grids_z10;
CREATE MATERIALIZED VIEW vis.map_urban_grids_z10 AS
SELECT
  grid_id,
  urban_class AS class_label,
  pop_density,
  built_up_fraction,
  urban_pressure,
  reinforced_pressure,
  ST_SimplifyPreserveTopology(geom, 0.0005) AS geom
FROM vis.urban_grids_base
WHERE urban_class IS NOT NULL;


-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_mv_urban_grids_z10_geom ON vis.map_urban_grids_z10 USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_mv_urban_grids_z10_lbl  ON vis.map_urban_grids_z10 (class_label);

