-- ============================================================================
-- Validation Queries for Persona V2 Scores
-- ============================================================================
-- Run this manually after persona scoring to validate results
-- Do NOT add to automated runner - this is for manual inspection
-- ============================================================================

\echo ''
\echo '================================'
\echo 'PERSONA V2 VALIDATION REPORT'
\echo '================================'
\echo ''

-- ============================================================================
-- SECTION 1: Summary Statistics for Parameter Scores
-- ============================================================================
\echo '--- Parameter Score Summary Statistics ---'
\echo ''

SELECT 
    'score_urban_gate' AS parameter,
    COUNT(*) AS count,
    ROUND(AVG(score_urban_gate)::numeric, 4) AS avg,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_urban_gate)::numeric, 4) AS p50,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_urban_gate)::numeric, 4) AS p90,
    ROUND(MIN(score_urban_gate)::numeric, 4) AS min,
    ROUND(MAX(score_urban_gate)::numeric, 4) AS max
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_urban_gate IS NOT NULL

UNION ALL

SELECT 
    'score_cruise_road',
    COUNT(*),
    ROUND(AVG(score_cruise_road)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_cruise_road)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_cruise_road)::numeric, 4),
    ROUND(MIN(score_cruise_road)::numeric, 4),
    ROUND(MAX(score_cruise_road)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_cruise_road IS NOT NULL

UNION ALL

SELECT 
    'score_offroad',
    COUNT(*),
    ROUND(AVG(score_offroad)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_offroad)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_offroad)::numeric, 4),
    ROUND(MIN(score_offroad)::numeric, 4),
    ROUND(MAX(score_offroad)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_offroad IS NOT NULL

UNION ALL

SELECT 
    'score_calm_road',
    COUNT(*),
    ROUND(AVG(score_calm_road)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_calm_road)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_calm_road)::numeric, 4),
    ROUND(MIN(score_calm_road)::numeric, 4),
    ROUND(MAX(score_calm_road)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_calm_road IS NOT NULL

UNION ALL

SELECT 
    'score_flow',
    COUNT(*),
    ROUND(AVG(score_flow)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_flow)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_flow)::numeric, 4),
    ROUND(MIN(score_flow)::numeric, 4),
    ROUND(MAX(score_flow)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_flow IS NOT NULL

UNION ALL

SELECT 
    'score_remoteness',
    COUNT(*),
    ROUND(AVG(score_remoteness)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_remoteness)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_remoteness)::numeric, 4),
    ROUND(MIN(score_remoteness)::numeric, 4),
    ROUND(MAX(score_remoteness)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_remoteness IS NOT NULL

UNION ALL

SELECT 
    'score_twist',
    COUNT(*),
    ROUND(AVG(score_twist)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_twist)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_twist)::numeric, 4),
    ROUND(MIN(score_twist)::numeric, 4),
    ROUND(MAX(score_twist)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_twist IS NOT NULL

UNION ALL

SELECT 
    'score_scenic',
    COUNT(*),
    ROUND(AVG(score_scenic)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score_scenic)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY score_scenic)::numeric, 4),
    ROUND(MIN(score_scenic)::numeric, 4),
    ROUND(MAX(score_scenic)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND score_scenic IS NOT NULL

ORDER BY parameter;

\echo ''

-- ============================================================================
-- SECTION 2: Summary Statistics for Persona Scores
-- ============================================================================
\echo '--- Persona Score Summary Statistics ---'
\echo ''

SELECT 
    'MileMuncher' AS persona,
    COUNT(*) AS count,
    ROUND(AVG(persona_milemuncher_score)::numeric, 4) AS avg,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_milemuncher_score)::numeric, 4) AS p50,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY persona_milemuncher_score)::numeric, 4) AS p90,
    ROUND(MIN(persona_milemuncher_score)::numeric, 4) AS min,
    ROUND(MAX(persona_milemuncher_score)::numeric, 4) AS max
FROM osm_all_roads
WHERE bikable_road = TRUE AND persona_milemuncher_score IS NOT NULL

UNION ALL

SELECT 
    'CornerCraver',
    COUNT(*),
    ROUND(AVG(persona_cornercraver_score)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_cornercraver_score)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY persona_cornercraver_score)::numeric, 4),
    ROUND(MIN(persona_cornercraver_score)::numeric, 4),
    ROUND(MAX(persona_cornercraver_score)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND persona_cornercraver_score IS NOT NULL

UNION ALL

SELECT 
    'TrailBlazer',
    COUNT(*),
    ROUND(AVG(persona_trailblazer_score)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_trailblazer_score)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY persona_trailblazer_score)::numeric, 4),
    ROUND(MIN(persona_trailblazer_score)::numeric, 4),
    ROUND(MAX(persona_trailblazer_score)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND persona_trailblazer_score IS NOT NULL

UNION ALL

SELECT 
    'TranquilTraveller',
    COUNT(*),
    ROUND(AVG(persona_tranquiltraveller_score)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY persona_tranquiltraveller_score)::numeric, 4),
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY persona_tranquiltraveller_score)::numeric, 4),
    ROUND(MIN(persona_tranquiltraveller_score)::numeric, 4),
    ROUND(MAX(persona_tranquiltraveller_score)::numeric, 4)
FROM osm_all_roads
WHERE bikable_road = TRUE AND persona_tranquiltraveller_score IS NOT NULL

ORDER BY persona;

\echo ''

-- ============================================================================
-- SECTION 3: Urban Gate Validation (should be 0 for all personas when urban=1)
-- ============================================================================
\echo '--- Urban Gate Validation (Check for violations) ---'
\echo ''

SELECT 
    COUNT(*) AS urban_roads_count,
    COUNT(CASE WHEN persona_milemuncher_score > 0 THEN 1 END) AS mm_violations,
    COUNT(CASE WHEN persona_cornercraver_score > 0 THEN 1 END) AS cc_violations,
    COUNT(CASE WHEN persona_trailblazer_score > 0 THEN 1 END) AS tb_violations,
    COUNT(CASE WHEN persona_tranquiltraveller_score > 0 THEN 1 END) AS tt_violations
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND road_scenery_urban = 1;

\echo 'Expected: All violation counts should be 0'
\echo ''

-- ============================================================================
-- SECTION 4: Top 5 Roads by MileMuncher Score
-- ============================================================================
\echo '--- Top 5 Roads: MileMuncher ---'
\echo ''

SELECT 
    osm_id,
    COALESCE(name, 'Unnamed') AS road_name,
    road_type_i1,
    ROUND(persona_milemuncher_score::numeric, 4) AS mm_score,
    ROUND(score_cruise_road::numeric, 3) AS cruise,
    ROUND(score_flow::numeric, 3) AS flow,
    ROUND(score_twist::numeric, 3) AS twist
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND persona_milemuncher_score IS NOT NULL
ORDER BY persona_milemuncher_score DESC
LIMIT 5;

\echo ''

-- ============================================================================
-- SECTION 5: Top 5 Roads by CornerCraver Score
-- ============================================================================
\echo '--- Top 5 Roads: CornerCraver ---'
\echo ''

SELECT 
    osm_id,
    COALESCE(name, 'Unnamed') AS road_name,
    road_type_i1,
    ROUND(persona_cornercraver_score::numeric, 4) AS cc_score,
    ROUND(score_twist::numeric, 3) AS twist,
    ROUND(score_flow::numeric, 3) AS flow,
    ROUND(score_scenic::numeric, 3) AS scenic
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND persona_cornercraver_score IS NOT NULL
ORDER BY persona_cornercraver_score DESC
LIMIT 5;

\echo ''

-- ============================================================================
-- SECTION 6: Top 5 Roads by TrailBlazer Score
-- ============================================================================
\echo '--- Top 5 Roads: TrailBlazer ---'
\echo ''

SELECT 
    osm_id,
    COALESCE(name, 'Unnamed') AS road_name,
    road_type_i1,
    ROUND(persona_trailblazer_score::numeric, 4) AS tb_score,
    ROUND(score_offroad::numeric, 3) AS offroad,
    ROUND(score_scenic::numeric, 3) AS scenic,
    ROUND(score_remoteness::numeric, 3) AS remote
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND persona_trailblazer_score IS NOT NULL
ORDER BY persona_trailblazer_score DESC
LIMIT 5;

\echo ''

-- ============================================================================
-- SECTION 7: Top 5 Roads by TranquilTraveller Score
-- ============================================================================
\echo '--- Top 5 Roads: TranquilTraveller ---'
\echo ''

SELECT 
    osm_id,
    COALESCE(name, 'Unnamed') AS road_name,
    road_type_i1,
    ROUND(persona_tranquiltraveller_score::numeric, 4) AS tt_score,
    ROUND(score_calm_road::numeric, 3) AS calm,
    ROUND(score_scenic::numeric, 3) AS scenic,
    ROUND(score_flow::numeric, 3) AS flow
FROM osm_all_roads
WHERE bikable_road = TRUE 
  AND persona_tranquiltraveller_score IS NOT NULL
ORDER BY persona_tranquiltraveller_score DESC
LIMIT 5;

\echo ''

-- ============================================================================
-- SECTION 8: Score Distribution by Road Type
-- ============================================================================
\echo '--- Score Distribution by Road Type ---'
\echo ''

SELECT 
    road_type_i1,
    COUNT(*) AS roads,
    ROUND(AVG(persona_milemuncher_score)::numeric, 3) AS avg_mm,
    ROUND(AVG(persona_cornercraver_score)::numeric, 3) AS avg_cc,
    ROUND(AVG(persona_trailblazer_score)::numeric, 3) AS avg_tb,
    ROUND(AVG(persona_tranquiltraveller_score)::numeric, 3) AS avg_tt
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND persona_milemuncher_score IS NOT NULL
GROUP BY road_type_i1
ORDER BY roads DESC;

\echo ''
\echo '================================'
\echo 'VALIDATION REPORT COMPLETE'
\echo '================================'
