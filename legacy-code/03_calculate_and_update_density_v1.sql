-- Road Intersection Density: Calculate density with length adjustment, progressive capping, and congestion factor
-- Uses geography casting for length (same as persona SQL files which work successfully)
-- This avoids the ST_Transform library loading issue
--
-- Improvements:
-- - Length adjustment factor to reduce impact of very short roads
-- - Progressive capping based on length buckets to prevent extreme values
-- - Congestion factor (0-1) for GraphHopper custom models
-- - Intersection scores are weighted by road hierarchy and urban/rural setting in step 02

-- First, ensure all bikable roads have values (set NULL to 0.0)
UPDATE osm_all_roads
SET intersection_density_per_km = 0.0,
    intersection_congestion_factor = 1.0  -- 1.0 = no congestion (multiply speed by 1.0 = no penalty)
WHERE bikable_road = TRUE
  AND (intersection_density_per_km IS NULL OR intersection_congestion_factor IS NULL);

-- Create temp table with calculated densities and congestion factors
DROP TABLE IF EXISTS temp_intersection_densities;
CREATE TEMP TABLE temp_intersection_densities (
    osm_id BIGINT PRIMARY KEY,
    length_km DOUBLE PRECISION,
    raw_density DOUBLE PRECISION,
    adjusted_density DOUBLE PRECISION,
    capped_density DOUBLE PRECISION,
    congestion_factor DOUBLE PRECISION
);

-- Calculate raw density, apply length adjustment, progressive capping, and congestion factor
WITH way_lengths AS (
    SELECT 
        o.osm_id,
        ST_Length(o.geometry::geography) / 1000.0 AS length_km
    FROM osm_all_roads o
    WHERE o.bikable_road = TRUE
),
percentiles AS (
    -- Calculate percentiles for capping (using all roads with intersections)
    SELECT 
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY 
            w.total_intersection_score / GREATEST(l.length_km, 0.05)
        ) AS p95_density,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY 
            w.total_intersection_score / GREATEST(l.length_km, 0.05)
        ) AS p90_density,
        PERCENTILE_CONT(0.85) WITHIN GROUP (ORDER BY 
            w.total_intersection_score / GREATEST(l.length_km, 0.05)
        ) AS p85_density
    FROM temp_way_intersection_scores w
    JOIN way_lengths l ON w.way_id = l.osm_id
    WHERE w.total_intersection_score > 0
),
density_calculations AS (
    SELECT 
        l.osm_id,
        l.length_km,
        w.total_intersection_score,
        -- Raw density (with minimum length threshold)
        CASE
            WHEN w.total_intersection_score IS NULL OR w.total_intersection_score = 0 THEN 0.0
            ELSE w.total_intersection_score / GREATEST(l.length_km, 0.05)
        END AS raw_density,
        -- Adjusted density (length adjustment factor to reduce impact of short roads)
        CASE
            WHEN w.total_intersection_score IS NULL OR w.total_intersection_score = 0 THEN 0.0
            ELSE
                w.total_intersection_score / GREATEST(
                    l.length_km * 
                    CASE
                        -- Length adjustment factor: reduce effective density for short roads
                        WHEN l.length_km < 0.1 THEN 1.5  -- <100m: multiply length by 1.5
                        WHEN l.length_km < 0.5 THEN 1.3  -- 100-500m: multiply length by 1.3
                        WHEN l.length_km < 1.0 THEN 1.1  -- 500m-1km: multiply length by 1.1
                        ELSE 1.0  -- >1km: no adjustment
                    END,
                    0.05
                )
        END AS adjusted_density,
        -- Cap value based on length
        CASE
            WHEN l.length_km >= 1.0 THEN p.p95_density  -- >1km: cap at 95th percentile
            WHEN l.length_km >= 0.5 THEN p.p90_density  -- 500m-1km: cap at 90th percentile
            WHEN l.length_km >= 0.1 THEN p.p85_density  -- 100-500m: cap at 85th percentile
            ELSE p.p85_density  -- <100m: cap at 85th percentile
        END AS cap_value
    FROM temp_way_intersection_scores w
    JOIN way_lengths l ON w.way_id = l.osm_id
    CROSS JOIN percentiles p
    WHERE l.osm_id IN (SELECT osm_id FROM osm_all_roads WHERE bikable_road = TRUE)
)
INSERT INTO temp_intersection_densities (osm_id, length_km, raw_density, adjusted_density, capped_density, congestion_factor)
SELECT 
    osm_id,
    length_km,
    raw_density,
    adjusted_density,
    -- Capped density (progressive capping based on length buckets)
    CASE
        WHEN total_intersection_score IS NULL OR total_intersection_score = 0 THEN 0.0
        ELSE LEAST(adjusted_density, cap_value)
    END AS capped_density,
    -- Congestion factor (0-1): higher density = lower factor (for speed multiplier: speed * factor)
    -- 1.0 = no congestion (multiply speed by 1.0 = no penalty)
    -- 0.5 = high congestion (multiply speed by 0.5 = 50% penalty)
    CASE
        WHEN total_intersection_score IS NULL OR total_intersection_score = 0 THEN 1.0  -- No intersections = no congestion
        ELSE GREATEST(0.5, LEAST(1.0,
            CASE
                WHEN LEAST(adjusted_density, cap_value) < 1.0 THEN 1.0  -- <1: no congestion
                WHEN LEAST(adjusted_density, cap_value) < 2.0 THEN 0.95  -- 1-2: slightly congested
                WHEN LEAST(adjusted_density, cap_value) < 3.0 THEN 0.87  -- 2-3: low congestion
                ELSE GREATEST(0.5, 1.0 - (LEAST(adjusted_density, cap_value) - 3.0) * 0.1)  -- >3: progressive decrease, min 0.5
            END
        ))
    END AS congestion_factor
FROM density_calculations;

-- Update from temp table
UPDATE osm_all_roads o
SET intersection_density_per_km = d.capped_density,
    intersection_congestion_factor = d.congestion_factor
FROM temp_intersection_densities d
WHERE o.osm_id = d.osm_id;

-- Clean up temp tables
DROP TABLE IF EXISTS temp_intersection_node_scores;
DROP TABLE IF EXISTS temp_way_intersection_scores;
DROP TABLE IF EXISTS temp_intersection_densities;

