-- Quick verification script to check if all columns used in avg_speed_kph calculation exist
-- Run this before running avg_speed_kph_run.py to verify schema compatibility

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'avg_speed_kph'
        ) THEN '✓' ELSE '✗'
    END AS has_avg_speed_kph,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'road_setting_i1'
        ) THEN '✓' ELSE '✗'
    END AS has_road_setting_i1,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'road_type_i1'
        ) THEN '✓' ELSE '✗'
    END AS has_road_type_i1,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'intersection_speed_degradation_final'
        ) THEN '✓' ELSE '✗'
    END AS has_intersection_speed_degradation_final,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'lanes'
        ) THEN '✓' ELSE '✗'
    END AS has_lanes,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'tags'
        ) THEN '✓' ELSE '✗'
    END AS has_tags,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'twistiness_score'
        ) THEN '✓' ELSE '✗'
    END AS has_twistiness_score,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'osm_all_roads' AND column_name = 'road_curvature_ratio'
        ) THEN '✓ (legacy)' ELSE '✗'
    END AS has_road_curvature_ratio;

-- Show sample values for road_setting_i1 and road_type_i1 to verify casing
SELECT DISTINCT road_setting_i1, COUNT(*) AS count
FROM osm_all_roads
WHERE road_setting_i1 IS NOT NULL
GROUP BY road_setting_i1
ORDER BY count DESC
LIMIT 10;

SELECT DISTINCT road_type_i1, COUNT(*) AS count
FROM osm_all_roads
WHERE road_type_i1 IS NOT NULL
GROUP BY road_type_i1
ORDER BY count DESC
LIMIT 10;

-- Check twistiness_score distribution
SELECT 
    COUNT(*) AS total_roads,
    COUNT(twistiness_score) AS roads_with_twistiness,
    ROUND(AVG(twistiness_score)::numeric, 4) AS avg_twistiness,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY twistiness_score)::numeric, 4) AS median_twistiness,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY twistiness_score)::numeric, 4) AS p90_twistiness,
    ROUND(MIN(twistiness_score)::numeric, 4) AS min_twistiness,
    ROUND(MAX(twistiness_score)::numeric, 4) AS max_twistiness
FROM osm_all_roads
WHERE twistiness_score IS NOT NULL;
