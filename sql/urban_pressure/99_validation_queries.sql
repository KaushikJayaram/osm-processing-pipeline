-- Validation queries for urban pressure outputs.

-- Null counts summary.
SELECT
    COUNT(*) AS total_grids,
    COUNT(*) FILTER (WHERE pop_count IS NULL) AS pop_count_nulls,
    COUNT(*) FILTER (WHERE pop_density IS NULL) AS pop_density_nulls,
    COUNT(*) FILTER (WHERE built_up_m2 IS NULL) AS built_up_m2_nulls,
    COUNT(*) FILTER (WHERE built_up_fraction IS NULL) AS built_up_fraction_nulls,
    COUNT(*) FILTER (WHERE urban_pressure IS NULL) AS urban_pressure_nulls,
    COUNT(*) FILTER (WHERE reinforced_pressure IS NULL) AS reinforced_pressure_nulls
FROM public.india_grids;

-- Built-up fraction range checks.
SELECT
    COUNT(*) FILTER (WHERE built_up_fraction < 0 OR built_up_fraction > 1) AS built_up_fraction_out_of_range
FROM public.india_grids
WHERE built_up_fraction IS NOT NULL;

-- Pop density sanity checks (very high/very low).
SELECT
    COUNT(*) FILTER (WHERE pop_density < 0) AS pop_density_negative,
    COUNT(*) FILTER (WHERE pop_density > 200000) AS pop_density_very_high
FROM public.india_grids
WHERE pop_density IS NOT NULL;

-- Sample grids near Bangalore core (12.9716, 77.5946).
WITH target AS (
    SELECT ST_SetSRID(ST_Point(77.5946, 12.9716), 4326) AS geom
)
SELECT
    g.grid_id,
    g.pop_density,
    g.built_up_fraction,
    g.urban_pressure,
    g.reinforced_pressure
FROM public.india_grids g, target t
ORDER BY ST_Distance(g.grid_geom, t.geom)
LIMIT 5;

-- Sample grids near Mysore (12.2958, 76.6394).
WITH target AS (
    SELECT ST_SetSRID(ST_Point(76.6394, 12.2958), 4326) AS geom
)
SELECT
    g.grid_id,
    g.pop_density,
    g.built_up_fraction,
    g.urban_pressure,
    g.reinforced_pressure
FROM public.india_grids g, target t
ORDER BY ST_Distance(g.grid_geom, t.geom)
LIMIT 5;

-- Sample rural reference (13.5, 76.0).
WITH target AS (
    SELECT ST_SetSRID(ST_Point(76.0, 13.5), 4326) AS geom
)
SELECT
    g.grid_id,
    g.pop_density,
    g.built_up_fraction,
    g.urban_pressure,
    g.reinforced_pressure
FROM public.india_grids g, target t
ORDER BY ST_Distance(g.grid_geom, t.geom)
LIMIT 5;
