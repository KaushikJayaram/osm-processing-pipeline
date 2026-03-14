-- ============================================================================
-- Compute 4 Persona Scores for Persona V2 Framework
-- ============================================================================
-- This script computes final persona scores from the parameter scores
-- All formulas produce 0-1 scale output with urban gate enforcement
-- 
-- Expected placeholders:
--   :lat_min, :lat_max, :lon_min, :lon_max - bounding box
--   :grid_id_min, :grid_id_max - for chunked execution
--
-- Prerequisites:
--   - All parameter scores must be computed first (01_compute_parameter_scores.sql)
-- ============================================================================

UPDATE osm_all_roads r
SET
    -- B1) MileMuncher: Cruise + Flow, penalize Twist, modest scenic/remoteness modulation
    -- MM = U * Cruise * Flow * (1 - 0.35*Twist) * (0.92 + 0.08*ScenicFast) * (0.70 + 0.30*(1-Remoteness))
    persona_milemuncher_score = GREATEST(0.0, LEAST(1.0,
        COALESCE(score_urban_gate, 0.0) *
        COALESCE(score_cruise_road, 0.0) *
        COALESCE(score_flow, 1.0) *
        (1.0 - 0.35 * COALESCE(score_twist, 0.0)) *
        (0.92 + 0.08 * COALESCE(score_scenic_fast, 0.0)) *
        (0.70 + 0.30 * (1.0 - COALESCE(score_remoteness, 0.0)))
    )),
    
    -- B2) CornerCraver: Twist primary, Flow helps, penalize highways, slight scenic/remoteness boost
    -- CC = U * Twist * (0.80 + 0.20*Flow) * (1 - 0.15*Cruise) * (0.94 + 0.06*ScenicFast) * (0.60 + 0.40*Remoteness)
    persona_cornercraver_score = GREATEST(0.0, LEAST(1.0,
        COALESCE(score_urban_gate, 0.0) *
        COALESCE(score_twist, 0.0) *
        (0.80 + 0.20 * COALESCE(score_flow, 1.0)) *
        (1.0 - 0.50 * COALESCE(score_offroad, 0.0)) *
        (0.94 + 0.06 * COALESCE(score_scenic_fast, 0.0)) *
        (0.60 + 0.40 * COALESCE(score_remoteness, 0.0))
    )),
    
    -- B3) TrailBlazer: Offroad + Remoteness + ScenicWild, penalize Flow
    -- TB = U * Offroad * Remoteness * (0.2 + 0.8*ScenicWild)
    persona_trailblazer_score = GREATEST(0.0, LEAST(1.0,
        COALESCE(score_urban_gate, 0.0) *
        (0.3 + 0.7 * COALESCE(score_offroad, 0.0)) *
        COALESCE(score_remoteness, 0.0) *
        (0.2 + 0.8 * COALESCE(score_scenic_wild, 0.0)) 
    )),
    
    -- B4) TranquilTraveller: Calm + Flow + ScenicSerene, slight Remoteness boost
    -- TT = U * Calm * (0.50 + 0.50*Flow) * (0.50 + 0.50*ScenicSerene) * (0.60 + 0.40*Remoteness)
    persona_tranquiltraveller_score = GREATEST(0.0, LEAST(1.0,
        COALESCE(score_urban_gate, 0.0) *
        COALESCE(score_calm_road, 0.0) *
        (0.50 + 0.50 * COALESCE(score_flow, 1.0)) *
        (0.50 + 0.50 * COALESCE(score_scenic_serene, 0.0)) *
        (0.60 + 0.40 * COALESCE(score_remoteness, 0.0))
    ))

WHERE r.bikable_road = TRUE
  AND r.geometry IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM public.osm_all_roads_grid rg 
      WHERE rg.osm_id = r.osm_id 
        AND rg.grid_id >= :grid_id_min 
        AND rg.grid_id <= :grid_id_max
  );
