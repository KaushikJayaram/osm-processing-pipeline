-- Validation queries for simplified persona scoring (Phase 1)
-- Test bbox: ST_MakeEnvelope(76, 12, 78, 14, 4326) - Karnataka region

-- ============================================
-- 1. Summary Statistics
-- ============================================
SELECT 
    'MileMuncher' AS persona,
    COUNT(*) AS total_roads,
    COUNT(*) FILTER (WHERE persona_milemuncher_base_score IS NOT NULL) AS scored_roads,
    ROUND(AVG(persona_milemuncher_base_score)::numeric, 2) AS avg_score,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_milemuncher_base_score)::numeric, 2) AS median_score,
    ROUND(MIN(persona_milemuncher_base_score)::numeric, 2) AS min_score,
    ROUND(MAX(persona_milemuncher_base_score)::numeric, 2) AS max_score,
    COUNT(*) FILTER (WHERE persona_milemuncher_base_score >= 70) AS excellent_count,
    COUNT(*) FILTER (WHERE persona_milemuncher_base_score >= 50) AS good_count
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))

UNION ALL

SELECT 
    'CornerCraver' AS persona,
    COUNT(*) AS total_roads,
    COUNT(*) FILTER (WHERE persona_cornercraver_base_score IS NOT NULL) AS scored_roads,
    ROUND(AVG(persona_cornercraver_base_score)::numeric, 2) AS avg_score,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_cornercraver_base_score)::numeric, 2) AS median_score,
    ROUND(MIN(persona_cornercraver_base_score)::numeric, 2) AS min_score,
    ROUND(MAX(persona_cornercraver_base_score)::numeric, 2) AS max_score,
    COUNT(*) FILTER (WHERE persona_cornercraver_base_score >= 70) AS excellent_count,
    COUNT(*) FILTER (WHERE persona_cornercraver_base_score >= 50) AS good_count
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))

UNION ALL

SELECT 
    'TrailBlazer' AS persona,
    COUNT(*) AS total_roads,
    COUNT(*) FILTER (WHERE persona_trailblazer_base_score IS NOT NULL) AS scored_roads,
    ROUND(AVG(persona_trailblazer_base_score)::numeric, 2) AS avg_score,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_trailblazer_base_score)::numeric, 2) AS median_score,
    ROUND(MIN(persona_trailblazer_base_score)::numeric, 2) AS min_score,
    ROUND(MAX(persona_trailblazer_base_score)::numeric, 2) AS max_score,
    COUNT(*) FILTER (WHERE persona_trailblazer_base_score >= 70) AS excellent_count,
    COUNT(*) FILTER (WHERE persona_trailblazer_base_score >= 50) AS good_count
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))

UNION ALL

SELECT 
    'TranquilTraveller' AS persona,
    COUNT(*) AS total_roads,
    COUNT(*) FILTER (WHERE persona_tranquiltraveller_base_score IS NOT NULL) AS scored_roads,
    ROUND(AVG(persona_tranquiltraveller_base_score)::numeric, 2) AS avg_score,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_tranquiltraveller_base_score)::numeric, 2) AS median_score,
    ROUND(MIN(persona_tranquiltraveller_base_score)::numeric, 2) AS min_score,
    ROUND(MAX(persona_tranquiltraveller_base_score)::numeric, 2) AS max_score,
    COUNT(*) FILTER (WHERE persona_tranquiltraveller_base_score >= 70) AS excellent_count,
    COUNT(*) FILTER (WHERE persona_tranquiltraveller_base_score >= 50) AS good_count
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))

ORDER BY persona;

-- ============================================
-- 2. Top 20 Roads per Persona
-- ============================================

-- Top MileMuncher roads
SELECT 
    'Top MileMuncher Roads' AS query_type,
    osm_id,
    ref,
    name,
    road_type_i1,
    road_setting_i1,
    ROUND((ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS length_km,
    ROUND(persona_milemuncher_base_score::numeric, 2) AS score,
    ROUND(COALESCE(twistiness_score, 0)::numeric, 4) AS twistiness,
    NULLIF(REGEXP_REPLACE(COALESCE(lanes, ''), '[^0-9]', '', 'g'), '')::INTEGER AS lanes_count
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_milemuncher_base_score IS NOT NULL
ORDER BY persona_milemuncher_base_score DESC
LIMIT 20;

-- Top CornerCraver roads
SELECT 
    'Top CornerCraver Roads' AS query_type,
    osm_id,
    ref,
    name,
    road_type_i1,
    road_setting_i1,
    ROUND((ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS length_km,
    ROUND(persona_cornercraver_base_score::numeric, 2) AS score,
    ROUND(COALESCE(twistiness_score, 0)::numeric, 4) AS twistiness,
    tags->>'surface' AS surface
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_cornercraver_base_score IS NOT NULL
ORDER BY persona_cornercraver_base_score DESC
LIMIT 20;

-- Top TrailBlazer roads
SELECT 
    'Top TrailBlazer Roads' AS query_type,
    osm_id,
    ref,
    name,
    road_type_i1,
    road_setting_i1,
    ROUND((ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS length_km,
    ROUND(persona_trailblazer_base_score::numeric, 2) AS score,
    (
        COALESCE(road_scenery_forest, 0) +
        COALESCE(road_scenery_hill, 0) +
        COALESCE(road_scenery_lake, 0) +
        COALESCE(road_scenery_river, 0)
    ) AS scenery_flags
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_trailblazer_base_score IS NOT NULL
ORDER BY persona_trailblazer_base_score DESC
LIMIT 20;

-- Top TranquilTraveller roads
SELECT 
    'Top TranquilTraveller Roads' AS query_type,
    osm_id,
    ref,
    name,
    road_type_i1,
    road_setting_i1,
    ROUND((ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS length_km,
    ROUND(persona_tranquiltraveller_base_score::numeric, 2) AS score,
    (
        COALESCE(road_scenery_forest, 0) +
        COALESCE(road_scenery_hill, 0) +
        COALESCE(road_scenery_lake, 0) +
        COALESCE(road_scenery_river, 0)
    ) AS scenery_flags
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_tranquiltraveller_base_score IS NOT NULL
ORDER BY persona_tranquiltraveller_base_score DESC
LIMIT 20;

-- ============================================
-- 3. Score Distribution by Road Type
-- ============================================
SELECT 
    'MileMuncher by Road Type' AS query_type,
    road_type_i1,
    COUNT(*) AS count,
    ROUND(AVG(persona_milemuncher_base_score)::numeric, 2) AS avg_score,
    ROUND(MIN(persona_milemuncher_base_score)::numeric, 2) AS min_score,
    ROUND(MAX(persona_milemuncher_base_score)::numeric, 2) AS max_score
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_milemuncher_base_score IS NOT NULL
GROUP BY road_type_i1
ORDER BY avg_score DESC;

SELECT 
    'CornerCraver by Road Type' AS query_type,
    road_type_i1,
    COUNT(*) AS count,
    ROUND(AVG(persona_cornercraver_base_score)::numeric, 2) AS avg_score,
    ROUND(MIN(persona_cornercraver_base_score)::numeric, 2) AS min_score,
    ROUND(MAX(persona_cornercraver_base_score)::numeric, 2) AS max_score
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_cornercraver_base_score IS NOT NULL
GROUP BY road_type_i1
ORDER BY avg_score DESC;

-- ============================================
-- 4. Score Distribution by Setting
-- ============================================
SELECT 
    'MileMuncher by Setting' AS query_type,
    road_setting_i1,
    COUNT(*) AS count,
    ROUND(AVG(persona_milemuncher_base_score)::numeric, 2) AS avg_score
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_milemuncher_base_score IS NOT NULL
GROUP BY road_setting_i1
ORDER BY avg_score DESC;

SELECT 
    'CornerCraver by Setting' AS query_type,
    road_setting_i1,
    COUNT(*) AS count,
    ROUND(AVG(persona_cornercraver_base_score)::numeric, 2) AS avg_score
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_cornercraver_base_score IS NOT NULL
GROUP BY road_setting_i1
ORDER BY avg_score DESC;

-- ============================================
-- 5. Check for Zero Scores (MileMuncher should only score highways)
-- ============================================
SELECT 
    'MileMuncher Zero Scores' AS query_type,
    road_type_i1,
    COUNT(*) AS count
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND ST_Intersects(geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
  AND persona_milemuncher_base_score = 0.0
GROUP BY road_type_i1
ORDER BY count DESC;

