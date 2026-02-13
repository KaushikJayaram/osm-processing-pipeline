-- Classify urban class based on reinforced_pressure thresholds.
-- > 0.25 => urban
-- > 0.10 => semi_urban
-- else   => rural

UPDATE public.india_grids
SET urban_class = CASE
    WHEN reinforced_pressure IS NULL THEN NULL
    WHEN reinforced_pressure > 0.25 THEN 'urban'
    WHEN reinforced_pressure > 0.10 THEN 'semi_urban'
    ELSE 'rural'
END;
