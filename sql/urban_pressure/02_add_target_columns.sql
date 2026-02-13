-- Add target columns to india_grids and backfill grid_area_m2/centroid.

ALTER TABLE public.india_grids
    ADD COLUMN IF NOT EXISTS grid_area_m2 numeric,
    ADD COLUMN IF NOT EXISTS centroid geometry(Point, 4326),
    ADD COLUMN IF NOT EXISTS pop_count numeric,
    ADD COLUMN IF NOT EXISTS pop_density numeric,
    ADD COLUMN IF NOT EXISTS built_up_m2 numeric,
    ADD COLUMN IF NOT EXISTS built_up_fraction numeric,
    ADD COLUMN IF NOT EXISTS urban_pressure numeric,
    ADD COLUMN IF NOT EXISTS reinforced_pressure numeric,
    ADD COLUMN IF NOT EXISTS urban_class text,
    ADD COLUMN IF NOT EXISTS pd_norm numeric,
    ADD COLUMN IF NOT EXISTS bu_norm numeric;

-- Backfill grid_area_m2 from the 54009 overlay (if available).
UPDATE public.india_grids g
SET grid_area_m2 = g540.grid_area_m2
FROM public.india_grids_54009 g540
WHERE g.grid_id = g540.grid_id
  AND g.grid_area_m2 IS NULL;

-- Backfill centroid in native SRID.
UPDATE public.india_grids g
SET centroid = ST_PointOnSurface(g.grid_geom)
WHERE g.centroid IS NULL;
