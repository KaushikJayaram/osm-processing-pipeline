-- Compute normalized components and urban_pressure.
-- Uses :pd_sat as saturation threshold for population density.

UPDATE public.india_grids
SET
    pd_norm = CASE
        WHEN pop_density IS NULL THEN NULL
        ELSE LEAST(pop_density / :pd_sat, 1.0)
    END,
    bu_norm = built_up_fraction;

UPDATE public.india_grids
SET urban_pressure = CASE
    WHEN pd_norm IS NULL OR bu_norm IS NULL THEN NULL
    ELSE 1.0 - (1.0 - pd_norm) * (1.0 - bu_norm)
END;
