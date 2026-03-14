-- ============================================================================
-- Normalize 4 Persona Scores for Persona V2 Framework
-- ============================================================================
-- This script normalizes persona scores to 0-1 using global min/max values
-- computed across all bikable roads.
-- 
-- Expected placeholders:
--   :grid_id_min, :grid_id_max - for chunked execution
--   :mm_min, :mm_max - global min/max for MileMuncher
--   :cc_min, :cc_max - global min/max for CornerCraver
--   :tb_min, :tb_max - global min/max for TrailBlazer
--   :tt_min, :tt_max - global min/max for TranquilTraveller
--   :mm_identity_norm, :cc_identity_norm, :tb_identity_norm, :tt_identity_norm
--     - efficiency flags (1=copy raw score, 0=compute normalization)
--
-- Prerequisites:
--   - All persona scores must be computed first (02_compute_persona_scores.sql)
--   - Global min/max values must be computed by the runner and passed as params
-- ============================================================================

UPDATE osm_all_roads r
SET
    -- Normalize MileMuncher score
    persona_milemuncher_score_normalised = CASE
        WHEN :mm_identity_norm = 1 THEN COALESCE(persona_milemuncher_score, 0.0)
        ELSE COALESCE(GREATEST(0.0, LEAST(1.0,
            (COALESCE(persona_milemuncher_score, 0.0) - :mm_min) /
            NULLIF(:mm_max - :mm_min, 0)
        )), 0.0)
    END,
    
    -- Normalize CornerCraver score
    persona_cornercraver_score_normalised = CASE
        WHEN :cc_identity_norm = 1 THEN COALESCE(persona_cornercraver_score, 0.0)
        ELSE COALESCE(GREATEST(0.0, LEAST(1.0,
            (COALESCE(persona_cornercraver_score, 0.0) - :cc_min) /
            NULLIF(:cc_max - :cc_min, 0)
        )), 0.0)
    END,
    
    -- Normalize TrailBlazer score
    persona_trailblazer_score_normalised = CASE
        WHEN :tb_identity_norm = 1 THEN COALESCE(persona_trailblazer_score, 0.0)
        ELSE COALESCE(GREATEST(0.0, LEAST(1.0,
            (COALESCE(persona_trailblazer_score, 0.0) - :tb_min) /
            NULLIF(:tb_max - :tb_min, 0)
        )), 0.0)
    END,
    
    -- Normalize TranquilTraveller score
    persona_tranquiltraveller_score_normalised = CASE
        WHEN :tt_identity_norm = 1 THEN COALESCE(persona_tranquiltraveller_score, 0.0)
        ELSE COALESCE(GREATEST(0.0, LEAST(1.0,
            (COALESCE(persona_tranquiltraveller_score, 0.0) - :tt_min) /
            NULLIF(:tt_max - :tt_min, 0)
        )), 0.0)
    END

WHERE r.bikable_road = TRUE
  AND r.geometry IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM public.osm_all_roads_grid rg 
      WHERE rg.osm_id = r.osm_id 
        AND rg.grid_id >= :grid_id_min 
        AND rg.grid_id <= :grid_id_max
  );
