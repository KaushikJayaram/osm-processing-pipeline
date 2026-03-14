-- Classify grid_classification_l1 based on reinforced_pressure thresholds.
-- > 0.25 => Urban
-- > 0.10 => SemiUrban
-- else   => Rural

ALTER TABLE public.india_grids
ADD COLUMN IF NOT EXISTS grid_classification_l1 VARCHAR;

UPDATE public.india_grids
SET grid_classification_l1 = CASE
    WHEN reinforced_pressure IS NULL THEN NULL
    WHEN reinforced_pressure > 0.25 THEN 'Urban'
    WHEN reinforced_pressure > 0.10 THEN 'SemiUrban'
    ELSE 'Rural'
END;
