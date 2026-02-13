-- Zonal aggregation for population counts.

WITH pop_zonal AS (
    SELECT
        g.grid_id,
        SUM((ST_SummaryStats(ST_Clip(r.rast, g.geom_54009), 1, true)).sum) AS pop_count_sum
    FROM public.india_grids_54009 g
    JOIN public.ghs_pop_e2030_r2023a_54009_100 r
        ON ST_Intersects(r.rast, g.geom_54009)
    GROUP BY g.grid_id
)
UPDATE public.india_grids ig
SET pop_count = p.pop_count_sum
FROM pop_zonal p
WHERE ig.grid_id = p.grid_id;

-- Compute population density (people per km^2).
UPDATE public.india_grids
SET pop_density = CASE
    WHEN grid_area_m2 > 0 AND pop_count IS NOT NULL
        THEN pop_count / (grid_area_m2 / 1000000.0)
    ELSE NULL
END;
