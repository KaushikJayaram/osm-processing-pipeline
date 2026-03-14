-- ============================================================================
-- Compute Parameter Scores for Persona V2 Framework
-- ============================================================================
-- This script computes intermediate scoring parameters (all 0-1 scale)
-- 
-- Expected placeholders:
--   :lat_min, :lat_max, :lon_min, :lon_max - bounding box
--   :grid_id_min, :grid_id_max - for chunked execution
--
-- Tunable constant:
--   TWIST_SAT = 0.54 (p95 for twistiness_score normalization)
-- ============================================================================

UPDATE osm_all_roads r
SET
    -- A1) UrbanGate: Hard filter for urban roads
    score_urban_gate = CASE 
        WHEN COALESCE(road_scenery_urban, 0) = 1 THEN 0.0
        ELSE 1.0
    END,
    
    -- A2) CruiseRoadScore: Highway/major road preference
    score_cruise_road = (
        CASE road_type_i1
            WHEN 'NH' THEN 1.0
            WHEN 'SH' THEN 0.9
            WHEN 'OH' THEN 0.9
            WHEN 'MDR' THEN 0.9
            WHEN 'WoH' THEN 0.2
            WHEN 'Res' THEN 0.2
            WHEN 'HAdj' THEN 0.6
            WHEN 'Track' THEN 0.0
            WHEN 'Path' THEN 0.0
            ELSE 0.25
        END
    ) * (
        CASE WHEN COALESCE(fourlane, 'no') = 'yes' THEN 1.0 ELSE 0.8 END
    ),
    
    -- A3) OffRoadScore: Track/path/rural preference
    score_offroad = (
        CASE road_type_i1
            WHEN 'NH' THEN 0.2
            WHEN 'SH' THEN 0.2
            WHEN 'OH' THEN 0.2
            WHEN 'MDR' THEN 0.2
            WHEN 'WoH' THEN 0.8
            WHEN 'Res' THEN 0.4
            WHEN 'HAdj' THEN 0.4
            WHEN 'Track' THEN 1.0
            WHEN 'Path' THEN 0.9
            ELSE 0.2
        END
    ) * (
        CASE WHEN COALESCE(fourlane, 'no') = 'yes' THEN 0.2 ELSE 1.0 END
    ) * (
        CASE WHEN COALESCE(road_scenery_semiurban, 0) = 1 THEN 0.8 ELSE 1.0 END
    ),
    
    -- A4) CalmRoadScore: Peaceful, lower-tier roads
    score_calm_road = (
        CASE road_type_i1
            WHEN 'NH' THEN 0.3
            WHEN 'SH' THEN 0.8
            WHEN 'OH' THEN 0.9
            WHEN 'MDR' THEN 1.0
            WHEN 'WoH' THEN 0.5
            WHEN 'Res' THEN 0.3
            WHEN 'HAdj' THEN 0.3
            WHEN 'Track' THEN 0.3
            WHEN 'Path' THEN 0.1
            ELSE 0.5
        END
    ) * (
        CASE WHEN COALESCE(fourlane, 'no') = 'yes' THEN 0.9 ELSE 1.0 END
    ) * (
        CASE WHEN COALESCE(road_scenery_semiurban, 0) = 1 THEN 0.8 ELSE 1.0 END
    ),
    
    -- A5) FlowScore: Intersection speed degradation (mapped from 0.5-1.0 to 0-1)
    score_flow = POWER(GREATEST(0.0, LEAST(1.0, 2.0 * COALESCE(intersection_speed_degradation_final, 1.0) - 1.0)), 3),
    
    -- A6) RemotenessScore: Inverse of urban pressure, squared for emphasis
    score_remoteness = POWER(GREATEST(0.0, LEAST(1.0, 1.0 - COALESCE(reinforced_pressure, 0.0))), 2),
    
    -- A7) TwistScore: Normalized twistiness with hill boost (TWIST_SAT = 0.54)
    score_twist = LEAST(1.0,
        (LEAST(COALESCE(twistiness_score, 0.0) / 0.54, 1.0)) * 
        (CASE WHEN COALESCE(road_scenery_hill, 0) = 1 THEN 1.0 ELSE 0.8 END)
    ),
    
    -- A8.1) ScenicWild: For TrailBlazer - emphasizes forest, hills, remote nature
    score_scenic_wild = LEAST(1.0,
        (
            -- Base score
            0.9 * COALESCE(wc_forest_frac, 0.0) +
            0.1 * COALESCE(wc_field_frac, 0.0) +
            0.2 * COALESCE(road_scenery_hill, 0) +
            0.1 * COALESCE(road_scenery_river, 0) +
            0.1 * COALESCE(road_scenery_lake, 0) +
            -- Synergy bonuses
            (CASE WHEN COALESCE(wc_forest_frac, 0) >= 0.35 AND COALESCE(road_scenery_hill, 0) = 1 THEN 0.25 ELSE 0.0 END) +
            (CASE WHEN COALESCE(wc_forest_frac, 0) >= 0.35 AND COALESCE(road_scenery_river, 0) = 1 THEN 0.18 ELSE 0.0 END) +
            (CASE WHEN COALESCE(road_scenery_lake, 0) = 1 AND 
                       (COALESCE(road_scenery_hill, 0) = 1 OR COALESCE(wc_field_frac, 0) >= 0.35) THEN 0.12 ELSE 0.0 END)
        ) --*
        -- Confidence multiplier
        --(CASE 
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.90 THEN 1.00
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.80 THEN 0.92
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.70 THEN 0.85
        --    WHEN COALESCE(scenery_v2_confidence, 0) > 0.00 THEN 0.75
        --    ELSE 0.70
        --END)
    ),
    
    -- A8.2) ScenicSerene: For TranquilTraveller - emphasizes lakes, calm water
    score_scenic_serene = LEAST(1.0,
        (
            -- Base score
            0.35 * COALESCE(road_scenery_lake, 0) +
            0.25 * COALESCE(road_scenery_river, 0) +
            0.15 * COALESCE(road_scenery_hill, 0) +
            0.10 * COALESCE(wc_field_frac, 0.0) +
            0.05 * COALESCE(wc_forest_frac, 0.0) +
            -- Synergy bonuses
            (CASE WHEN COALESCE(road_scenery_lake, 0) = 1 THEN 0.15 ELSE 0.0 END) +
            (CASE WHEN COALESCE(road_scenery_river, 0) = 1 AND 
                       (COALESCE(road_scenery_hill, 0) = 1 OR COALESCE(wc_forest_frac, 0) >= 0.35) THEN 0.10 ELSE 0.0 END) +
            (CASE WHEN COALESCE(wc_field_frac, 0) >= 0.35 AND 
                       (COALESCE(road_scenery_lake, 0) = 1 OR COALESCE(road_scenery_river, 0) = 1) THEN 0.08 ELSE 0.0 END)
        ) --* 
        -- Confidence multiplier
        --(CASE 
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.90 THEN 1.00
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.80 THEN 0.92
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.70 THEN 0.85
        --    WHEN COALESCE(scenery_v2_confidence, 0) > 0.00 THEN 0.75
        --    ELSE 0.70
        --END)
    ),
    
    -- A8.3) ScenicFast: For MileMuncher/CornerCraver - emphasizes dramatic features
    score_scenic_fast = LEAST(1.0,
        (
            -- Base score
            0.35 * COALESCE(road_scenery_hill, 0) +
            0.30 * COALESCE(road_scenery_river, 0) +
            0.25 * COALESCE(road_scenery_lake, 0) +
            0.10 * COALESCE(wc_forest_frac, 0.0)
        ) --* 
        -- Confidence multiplier (gentler for fast riding)
        --(CASE 
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.90 THEN 1.00
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.80 THEN 0.95
        --    WHEN COALESCE(scenery_v2_confidence, 0) >= 0.70 THEN 0.90
        --    WHEN COALESCE(scenery_v2_confidence, 0) > 0.00 THEN 0.85
        --    ELSE 0.80
        --END)
    )

WHERE r.bikable_road = TRUE
  AND r.geometry IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM public.osm_all_roads_grid rg 
      WHERE rg.osm_id = r.osm_id 
        AND rg.grid_id >= :grid_id_min 
        AND rg.grid_id <= :grid_id_max
  );
