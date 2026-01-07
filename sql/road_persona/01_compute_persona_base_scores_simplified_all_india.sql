-- Simplified Persona Scoring: Phase 1 Implementation - ALL OF INDIA
-- 
-- This script implements the simplified framework for ALL of India:
-- - 2-3 key factors per persona
-- - Simple 0-1 scoring for each factor
-- - Weighted average combination
-- - Direct scaling to 0-100 (no percentile normalization)
-- - Only base_score columns (no corridor_km or final_score in Phase 1)
-- - Urban hard gate: All personas get 0 score for Urban roads
-- - SemiUrban penalty: All personas get 25% reduction for SemiUrban roads
--
-- IMPORTANT: Run 00_add_simplified_persona_columns.sql first if columns don't exist!

-- Helper function to parse lanes from text
CREATE OR REPLACE FUNCTION parse_lanes(lanes_text TEXT) RETURNS INTEGER AS $$
BEGIN
    RETURN NULLIF(REGEXP_REPLACE(COALESCE(lanes_text, ''), '[^0-9]', '', 'g'), '')::INTEGER;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

WITH factors AS (
    SELECT
        o.osm_id,
        
        -- ============================================
        -- FACTOR 1: Road Quality (for MileMuncher)
        -- ============================================
        CASE
            WHEN o.road_type_i1 NOT IN ('NH', 'SH', 'MDR', 'OH') THEN 0.0  -- Hard gate: only highways
            WHEN o.road_type_i1 = 'NH' AND parse_lanes(o.lanes) >= 2 THEN 1.0
            WHEN o.road_type_i1 = 'NH' THEN 0.8
            WHEN o.road_type_i1 = 'SH' AND parse_lanes(o.lanes) >= 2 THEN 0.7
            WHEN o.road_type_i1 = 'SH' THEN 0.6
            WHEN o.road_type_i1 IN ('MDR', 'OH') AND parse_lanes(o.lanes) >= 2 THEN 0.5
            WHEN o.road_type_i1 IN ('MDR', 'OH') THEN 0.4
            ELSE 0.0
        END AS road_quality,
        
        -- ============================================
        -- FACTOR 2: Straightness (for MileMuncher)
        -- ============================================
        CASE
            WHEN o.twistiness_score IS NULL THEN 0.5  -- Neutral if unknown
            ELSE GREATEST(0.0, 1.0 - LEAST(1.0, o.twistiness_score / 0.20))  -- Cap at 0.20 twistiness = 0 score
        END AS straightness,
        
        -- ============================================
        -- FACTOR 3: Low Stress (for all personas)
        -- ============================================
        CASE
            WHEN o.road_setting_i1 = 'Rural' THEN 1.0
            WHEN o.road_setting_i1 = 'SemiUrban' THEN 0.6
            WHEN o.road_setting_i1 = 'Urban' THEN 0.2
            ELSE 0.5  -- Unknown
        END AS low_stress,
        
        -- ============================================
        -- FACTOR 4: Twistiness (for CornerCraver)
        -- ============================================
        CASE
            WHEN o.twistiness_score IS NULL THEN 0.0  -- No curves = bad for CornerCraver
            ELSE LEAST(1.0, o.twistiness_score / 0.15)  -- Normalize: 0.15+ = max score
        END AS twistiness,
        
        -- ============================================
        -- FACTOR 5: Surface Quality (for CornerCraver)
        -- ============================================
        -- Penalize unknown surface more, especially for short roads
        CASE
            WHEN o.tags->>'surface' IS NULL AND (ST_Length(o.geometry::geography) / 1000.0) < 0.5 THEN 0.3  -- Short + unknown = penalize
            WHEN o.tags->>'surface' IS NULL THEN 0.5  -- Unknown = moderate penalty
            WHEN LOWER(o.tags->>'surface') IN ('asphalt', 'paved', 'concrete', 'concrete:lanes', 'concrete:plates') THEN 1.0
            WHEN LOWER(o.tags->>'surface') IN ('paving_stones', 'sett', 'cobblestone') THEN 0.7
            WHEN LOWER(o.tags->>'surface') IN ('compacted', 'fine_gravel', 'gravel') THEN 0.4
            WHEN LOWER(o.tags->>'surface') IN ('dirt', 'earth', 'ground', 'mud', 'sand', 'unpaved') THEN 0.1
            ELSE 0.5  -- Unknown = moderate penalty
        END AS surface_quality,
        
        -- ============================================
        -- FACTOR 6: Exploration (for TrailBlazer)
        -- ============================================
        CASE
            WHEN o.road_type_i1 IN ('Track', 'Path') THEN 1.0
            WHEN o.road_type_i1 = 'WoH' THEN 0.6
            WHEN o.road_type_i1 IN ('MDR', 'OH') THEN 0.5
            WHEN o.road_type_i1 = 'SH' THEN 0.3
            WHEN o.road_type_i1 = 'NH' THEN 0.1
            WHEN o.road_type_i1 = 'HAdj' THEN 0.2
            ELSE 0.5
        END AS exploration,
        
        -- ============================================
        -- FACTOR 7: Scenery (for TrailBlazer and TranquilTraveller)
        -- ============================================
        -- Require at least 2 scenery flags for high scores (prevents NH with single flag from scoring high)
        CASE
            WHEN (
                COALESCE(o.road_scenery_forest, 0) +
                COALESCE(o.road_scenery_hill, 0) +
                COALESCE(o.road_scenery_lake, 0) +
                COALESCE(o.road_scenery_river, 0) +
                COALESCE(o.road_scenery_mountainpass, 0) +
                COALESCE(o.road_scenery_field, 0) +
                COALESCE(o.road_scenery_beach, 0) +
                COALESCE(o.road_scenery_desert, 0) +
                COALESCE(o.road_scenery_saltflat, 0) +
                COALESCE(o.road_scenery_snowcappedmountain, 0) +
                COALESCE(o.road_scenery_plantation, 0) +
                COALESCE(o.road_scenery_backwater, 0)
            ) >= 2 THEN LEAST(1.0, (
                COALESCE(o.road_scenery_forest, 0) +
                COALESCE(o.road_scenery_hill, 0) +
                COALESCE(o.road_scenery_lake, 0) +
                COALESCE(o.road_scenery_river, 0) +
                COALESCE(o.road_scenery_mountainpass, 0) +
                COALESCE(o.road_scenery_field, 0) +
                COALESCE(o.road_scenery_beach, 0) +
                COALESCE(o.road_scenery_desert, 0) +
                COALESCE(o.road_scenery_saltflat, 0) +
                COALESCE(o.road_scenery_snowcappedmountain, 0) +
                COALESCE(o.road_scenery_plantation, 0) +
                COALESCE(o.road_scenery_backwater, 0)
            ) / 3.0)  -- 3+ flags = max score
            WHEN (
                COALESCE(o.road_scenery_forest, 0) +
                COALESCE(o.road_scenery_hill, 0) +
                COALESCE(o.road_scenery_lake, 0) +
                COALESCE(o.road_scenery_river, 0) +
                COALESCE(o.road_scenery_mountainpass, 0) +
                COALESCE(o.road_scenery_field, 0) +
                COALESCE(o.road_scenery_beach, 0) +
                COALESCE(o.road_scenery_desert, 0) +
                COALESCE(o.road_scenery_saltflat, 0) +
                COALESCE(o.road_scenery_snowcappedmountain, 0) +
                COALESCE(o.road_scenery_plantation, 0) +
                COALESCE(o.road_scenery_backwater, 0)
            ) = 1 THEN 0.3  -- Single flag = low score
            ELSE 0.0  -- No scenery = 0
        END AS scenery,
        
        -- ============================================
        -- FACTOR 8: Moderate Roads (for TranquilTraveller)
        -- ============================================
        CASE
            WHEN o.road_type_i1 = 'WoH' THEN 0.0  -- Hard exclude
            WHEN o.road_type_i1 = 'NH' THEN 0.3   -- Too major
            WHEN o.road_type_i1 IN ('MDR', 'SH', 'OH') THEN 1.0  -- Perfect
            WHEN o.road_type_i1 = 'HAdj' THEN 0.4
            WHEN o.road_type_i1 IN ('Track', 'Path') THEN 0.6
            ELSE 0.5
        END AS moderate_roads,
        
        -- Store road_setting_i1 for hard gates in scoring
        COALESCE(o.road_setting_i1, '') AS road_setting_i1_value
        
    FROM osm_all_roads AS o
    WHERE o.bikable_road = TRUE  -- Process all bikable roads in India
),
raw_scores AS (
    SELECT
        f.*,
        
        -- ============================================
        -- MileMuncher: Road Quality (60%) + Straightness (20%) + Low Stress (20%)
        -- Hard gate: Urban roads get 0 score
        -- ============================================
        CASE
            -- Hard gate: Urban roads get 0 score
            WHEN f.road_setting_i1_value = 'Urban' THEN 0.0
            ELSE (
                0.60 * f.road_quality +
                0.20 * f.straightness +
                0.20 * f.low_stress
            )
        END AS milemuncher_raw,
        
        -- ============================================
        -- CornerCraver: Twistiness (40%) + Road Quality (45%) + Low Stress (10%) + Surface Quality (5%)
        -- Hard gate: Urban roads get 0 score
        -- ============================================
        CASE
            -- Hard gate: Urban roads get 0 score
            WHEN f.road_setting_i1_value = 'Urban' THEN 0.0
            ELSE (
                0.40 * f.twistiness +
                0.45 * f.road_quality +  -- Highways are fast, corners are fun when fast
                0.10 * f.low_stress +
                0.05 * f.surface_quality
            )
        END AS cornercraver_raw,
        
        -- ============================================
        -- TrailBlazer: Exploration (50%) + Scenery (25%) + Low Stress (25%)
        -- Hard gate: Urban roads get 0 score
        -- ============================================
        CASE
            -- Hard gate: Urban roads get 0 score
            WHEN f.road_setting_i1_value = 'Urban' THEN 0.0
            ELSE (
                0.50 * f.exploration +
                0.25 * f.scenery +
                0.25 * f.low_stress
            )
        END AS trailblazer_raw,
        
        -- ============================================
        -- TranquilTraveller: Scenery (45%) + Low Stress (30%) + Moderate Roads (25%)
        -- Hard gate: Urban roads get 0 score
        -- ============================================
        CASE
            -- Hard gate: Urban roads get 0 score
            WHEN f.road_setting_i1_value = 'Urban' THEN 0.0
            ELSE (
                0.45 * f.scenery +
                0.30 * f.low_stress +
                0.25 * f.moderate_roads
            )
        END AS tranquiltraveller_raw
        
    FROM factors AS f
),
normalized_scores AS (
    SELECT
        r.*,
        
        -- Direct scaling to 0-100 (Option 2 from framework)
        -- Since raw scores are already 0-1, just multiply by 100
        -- Apply 25% reduction for SemiUrban setting (multiply by 0.75)
        CASE
            WHEN r.road_setting_i1_value = 'SemiUrban' THEN 
                LEAST(100.0, GREATEST(0.0, r.milemuncher_raw * 100.0 * 0.75))
            ELSE 
                LEAST(100.0, GREATEST(0.0, r.milemuncher_raw * 100.0))
        END AS milemuncher_base_score,
        
        CASE
            WHEN r.road_setting_i1_value = 'SemiUrban' THEN 
                LEAST(100.0, GREATEST(0.0, r.cornercraver_raw * 100.0 * 0.75))
            ELSE 
                LEAST(100.0, GREATEST(0.0, r.cornercraver_raw * 100.0))
        END AS cornercraver_base_score,
        
        CASE
            WHEN r.road_setting_i1_value = 'SemiUrban' THEN 
                LEAST(100.0, GREATEST(0.0, r.trailblazer_raw * 100.0 * 0.75))
            ELSE 
                LEAST(100.0, GREATEST(0.0, r.trailblazer_raw * 100.0))
        END AS trailblazer_base_score,
        
        CASE
            WHEN r.road_setting_i1_value = 'SemiUrban' THEN 
                LEAST(100.0, GREATEST(0.0, r.tranquiltraveller_raw * 100.0 * 0.75))
            ELSE 
                LEAST(100.0, GREATEST(0.0, r.tranquiltraveller_raw * 100.0))
        END AS tranquiltraveller_base_score
        
    FROM raw_scores AS r
)
UPDATE osm_all_roads AS o
SET
    persona_milemuncher_base_score = n.milemuncher_base_score,
    persona_cornercraver_base_score = n.cornercraver_base_score,
    persona_trailblazer_base_score = n.trailblazer_base_score,
    persona_tranquiltraveller_base_score = n.tranquiltraveller_base_score
FROM normalized_scores AS n
WHERE o.osm_id = n.osm_id;

-- Log how many rows were updated
DO $$
DECLARE
    v_update_count INTEGER;
BEGIN
    GET DIAGNOSTICS v_update_count = ROW_COUNT;
    RAISE NOTICE 'UPDATE: Updated persona scores for % roads (all of India)', v_update_count;
END $$;

-- Log summary statistics for all of India
DO $$
DECLARE
    v_mm_count INTEGER;
    v_mm_avg DOUBLE PRECISION;
    v_cc_count INTEGER;
    v_cc_avg DOUBLE PRECISION;
    v_tb_count INTEGER;
    v_tb_avg DOUBLE PRECISION;
    v_tt_count INTEGER;
    v_tt_avg DOUBLE PRECISION;
BEGIN
    SELECT 
        COUNT(*),
        AVG(persona_milemuncher_base_score)
    INTO v_mm_count, v_mm_avg
    FROM osm_all_roads
    WHERE bikable_road = TRUE
      AND persona_milemuncher_base_score IS NOT NULL;
    
    SELECT 
        COUNT(*),
        AVG(persona_cornercraver_base_score)
    INTO v_cc_count, v_cc_avg
    FROM osm_all_roads
    WHERE bikable_road = TRUE
      AND persona_cornercraver_base_score IS NOT NULL;
    
    SELECT 
        COUNT(*),
        AVG(persona_trailblazer_base_score)
    INTO v_tb_count, v_tb_avg
    FROM osm_all_roads
    WHERE bikable_road = TRUE
      AND persona_trailblazer_base_score IS NOT NULL;
    
    SELECT 
        COUNT(*),
        AVG(persona_tranquiltraveller_base_score)
    INTO v_tt_count, v_tt_avg
    FROM osm_all_roads
    WHERE bikable_road = TRUE
      AND persona_tranquiltraveller_base_score IS NOT NULL;
    
    RAISE NOTICE 'Simplified Persona Scoring - Phase 1 Complete (All of India)';
    RAISE NOTICE 'MileMuncher: % roads scored, avg score: %.2f', v_mm_count, v_mm_avg;
    RAISE NOTICE 'CornerCraver: % roads scored, avg score: %.2f', v_cc_count, v_cc_avg;
    RAISE NOTICE 'TrailBlazer: % roads scored, avg score: %.2f', v_tb_count, v_tb_avg;
    RAISE NOTICE 'TranquilTraveller: % roads scored, avg score: %.2f', v_tt_count, v_tt_avg;
END $$;

