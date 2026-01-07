-- Road Intersection Speed Degradation: Calculate final degradation with setting and infrastructure factors (v2)
--
-- Step 1: Apply setting multiplier
--   - Urban: 1.0 (no reduction)
--   - SemiUrban: 0.75 (25% reduction)
--   - Rural: 0.5 (50% reduction)
--
-- Step 2: Apply lanes+oneway factor (Rural only)
--   - Condition: oneway = yes AND lanes > 2 AND setting = Rural
--   - Additional reduction: 20% (multiply by 0.8)
--
-- Final degradation is capped at 0.0 to 0.5
--
-- IMPORTANT: intersection_speed_degradation_final is stored as a MULTIPLIER (1.0 - degradation)
--   for direct use in GraphHopper multiply_by operations.
--   - Degradation of 0.3 (30% reduction) → Stored as 0.7 (multiply_by 0.7 = 70% of original speed)
--   - Degradation of 0.0 (no reduction) → Stored as 1.0 (multiply_by 1.0 = 100% of original speed)
--   - Degradation of 0.5 (50% reduction) → Stored as 0.5 (multiply_by 0.5 = 50% of original speed)
--   Range: 0.5 to 1.0 (where 1.0 = no degradation, 0.5 = maximum degradation)

-- First, ensure all bikable roads have values
-- TEST BBOX FILTER: Commented out to process all of India
UPDATE osm_all_roads
SET intersection_speed_degradation_base = 0.0,
    intersection_speed_degradation_setting_adjusted = 0.0,
    intersection_speed_degradation_final = 1.0  -- 1.0 = no degradation (multiplier format)
WHERE bikable_road = TRUE
  AND (intersection_speed_degradation_base IS NULL 
       OR intersection_speed_degradation_setting_adjusted IS NULL
       OR intersection_speed_degradation_final IS NULL);
  -- TEST BBOX FILTER: Commented out to process all of India
  -- AND ST_Intersects(geometry, ST_SetSRID(ST_MakeEnvelope(76.0, 12.0, 78.0, 14.0, 4326), 4326));

-- Calculate and update final degradation
WITH way_data AS (
    SELECT 
        o.osm_id,
        o.osm_id AS way_id,
        o.road_setting_i1,
        b.base_degradation,
        -- Parse lanes
        CASE 
            WHEN o.lanes ~ '^[0-9]+$' THEN (o.lanes)::INTEGER
            WHEN o.lanes ~ '^[0-9]+-[0-9]+$' THEN 
                (SPLIT_PART(o.lanes, '-', 2))::INTEGER
            ELSE NULL
        END AS lanes_count,
        -- Check if oneway
        CASE 
            WHEN UPPER(COALESCE(o.tags->>'oneway', '')) IN ('YES', 'TRUE', '1', '-1') THEN TRUE
            ELSE FALSE
        END AS is_oneway
    FROM osm_all_roads o
    LEFT JOIN temp_way_base_degradation b ON o.osm_id = b.way_id
    WHERE o.bikable_road = TRUE
      -- TEST BBOX FILTER: Commented out to process all of India
      -- AND ST_Intersects(o.geometry, ST_SetSRID(ST_MakeEnvelope(76.0, 12.0, 78.0, 14.0, 4326), 4326))
),
final_calc AS (
    SELECT 
        osm_id,
        COALESCE(base_degradation, 0.0) AS base_degradation,
        -- Apply setting multiplier
        COALESCE(base_degradation, 0.0) * 
            CASE 
                WHEN road_setting_i1 = 'Urban' THEN 1.0
                WHEN road_setting_i1 = 'SemiUrban' THEN 0.75
                WHEN road_setting_i1 = 'Rural' THEN 0.5
                ELSE 1.0
            END AS setting_adjusted_degradation,
        -- Check if lanes+oneway factor applies
        (road_setting_i1 = 'Rural' 
         AND is_oneway = TRUE 
         AND lanes_count IS NOT NULL 
         AND lanes_count > 2) AS applied_lanes_oneway_factor
    FROM way_data
)
UPDATE osm_all_roads o
SET 
    intersection_speed_degradation_base = f.base_degradation,
    intersection_speed_degradation_setting_adjusted = f.setting_adjusted_degradation,
    intersection_speed_degradation_final = 
        -- Convert degradation to multiplier (1.0 - degradation) for GraphHopper multiply_by
        -- Apply lanes+oneway factor if applicable, then convert to multiplier
        1.0 - (
            CASE 
                WHEN f.applied_lanes_oneway_factor THEN 
                    GREATEST(0.0, LEAST(0.5, f.setting_adjusted_degradation * 0.8))
                ELSE 
                    GREATEST(0.0, LEAST(0.5, f.setting_adjusted_degradation))
            END
        )
FROM final_calc f
WHERE o.osm_id = f.osm_id;

-- Clean up temp tables
DROP TABLE IF EXISTS temp_intersection_nodes_v2;
DROP TABLE IF EXISTS temp_way_intersections_v2;
DROP TABLE IF EXISTS temp_way_base_degradation;

