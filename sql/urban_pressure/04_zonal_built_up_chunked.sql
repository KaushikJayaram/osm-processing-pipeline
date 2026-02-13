-- Zonal aggregation for built-up surface area (m^2), chunked by grid_id.
-- Params: :grid_id_min, :grid_id_max

WITH built_zonal AS (
    SELECT
        g.grid_id,
        SUM((ST_SummaryStats(ST_Clip(r.rast, g.geom_54009), 1, true)).sum) AS built_m2_sum
    FROM public.india_grids_54009 g
    JOIN public.ghs_built_s_e2030_r2023a_54009_100 r
        ON ST_Intersects(r.rast, g.geom_54009)
    WHERE g.grid_id BETWEEN :grid_id_min AND :grid_id_max
    GROUP BY g.grid_id
)
UPDATE public.india_grids ig
SET built_up_m2 = b.built_m2_sum
FROM built_zonal b
WHERE ig.grid_id = b.grid_id
  AND ig.grid_id BETWEEN :grid_id_min AND :grid_id_max;

-- Compute built-up fraction (0..1).
UPDATE public.india_grids
SET built_up_fraction = CASE
    WHEN grid_area_m2 > 0 AND built_up_m2 IS NOT NULL
        THEN LEAST(built_up_m2 / grid_area_m2, 1.0)
    ELSE NULL
END
WHERE grid_id BETWEEN :grid_id_min AND :grid_id_max;
