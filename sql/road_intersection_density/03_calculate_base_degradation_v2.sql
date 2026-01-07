-- Road Intersection Speed Degradation: Calculate base speed degradation per way (v2)
-- 
-- Calculation Logic:
-- - For ways >= max impact distance: Use weighted average
-- - For ways < max impact distance: Use multiplicative stacking
--
-- Base degradation is calculated before applying setting and infrastructure multipliers

DROP TABLE IF EXISTS temp_way_base_degradation;
CREATE TEMP TABLE temp_way_base_degradation (
    way_id BIGINT PRIMARY KEY,
    base_degradation DOUBLE PRECISION,
    calculation_method TEXT  -- 'weighted_average' or 'multiplicative'
);

WITH way_lengths AS (
    SELECT 
        o.osm_id AS way_id,
        ST_Length(o.geometry::geography) AS length_m
    FROM osm_all_roads o
    WHERE o.bikable_road = TRUE
      -- TEST BBOX FILTER: Commented out to process all of India
      -- AND ST_Intersects(o.geometry, ST_SetSRID(ST_MakeEnvelope(76.0, 12.0, 78.0, 14.0, 4326), 4326))
),
way_intersection_summary AS (
    SELECT 
        w.way_id,
        COUNT(*) AS intersection_count,
        MAX(w.impact_distance_m) AS max_impact_distance
    FROM temp_way_intersections_v2 w
    GROUP BY w.way_id
),
degradation_calc AS (
    SELECT 
        l.way_id,
        l.length_m,
        COALESCE(s.intersection_count, 0) AS intersection_count,
        COALESCE(s.max_impact_distance, 0) AS max_impact_distance,
        CASE 
            -- No intersections
            WHEN COALESCE(s.intersection_count, 0) = 0 THEN 0.0
            -- Way is longer than max impact distance: use weighted average
            WHEN l.length_m >= COALESCE(s.max_impact_distance, 0) THEN
                -- Sum of (impact_distance × speed_reduction) / total_length
                COALESCE((
                    SELECT SUM(w.impact_distance_m * w.speed_reduction) / GREATEST(l.length_m, 1.0)
                    FROM temp_way_intersections_v2 w
                    WHERE w.way_id = l.way_id
                ), 0.0)
            -- Way is shorter: use multiplicative stacking
            ELSE
                -- Calculate: 1 - product of (1 - speed_reduction) for each intersection
                GREATEST(0.0, LEAST(0.5, 
                    1.0 - COALESCE((
                        SELECT EXP(SUM(LN(GREATEST(0.0001, 1.0 - w.speed_reduction))))
                        FROM temp_way_intersections_v2 w
                        WHERE w.way_id = l.way_id
                          AND w.speed_reduction > 0
                    ), 1.0)
                ))
        END AS base_degradation,
        CASE 
            WHEN l.length_m >= COALESCE(s.max_impact_distance, 0) THEN 'weighted_average'
            ELSE 'multiplicative'
        END AS calculation_method
    FROM way_lengths l
    LEFT JOIN way_intersection_summary s ON l.way_id = s.way_id
)
INSERT INTO temp_way_base_degradation (way_id, base_degradation, calculation_method)
SELECT 
    way_id,
    base_degradation,
    calculation_method
FROM degradation_calc;

