-- 04_qc_samples.sql
-- Validation queries for Scenery V2

\echo '----------------------------------------------------------------------'
\echo 'Sample 1: Bangalore Region (Expect Urban/SemiUrban or Field/Tree mix)'
\echo '----------------------------------------------------------------------'

SELECT 
    osm_id, 
    scenery_v2_primary, 
    scenery_v2_confidence,
    road_scenery_urban,
    road_scenery_semiurban,
    wc_forest_frac, 
    wc_field_frac, 
    wc_water_frac,
    wc_total_px
FROM osm_all_roads
WHERE ST_Intersects(geometry, ST_MakeEnvelope(77.5, 12.9, 77.7, 13.1, 4326))
  AND wc_total_px > 0
ORDER BY RANDOM()
LIMIT 25;

\echo '----------------------------------------------------------------------'
\echo 'Sample 2: Western Ghats / Coorg (Expect Forest/Field)'
\echo '----------------------------------------------------------------------'

SELECT 
    osm_id, 
    scenery_v2_primary, 
    scenery_v2_confidence, 
    wc_forest_frac, 
    wc_field_frac, 
    wc_water_frac,
    wc_total_px
FROM osm_all_roads
WHERE ST_Intersects(geometry, ST_MakeEnvelope(75.5, 12.0, 76.0, 12.5, 4326))
  AND wc_total_px > 0
ORDER BY RANDOM()
LIMIT 25;

\echo '----------------------------------------------------------------------'
\echo 'Sample 3: High Confidence Forest'
\echo '----------------------------------------------------------------------'

SELECT osm_id, scenery_v2_primary, wc_forest_frac
FROM osm_all_roads
WHERE scenery_v2_primary = 'forest' AND scenery_v2_confidence > 0.8
LIMIT 10;

\echo '----------------------------------------------------------------------'
\echo 'Overall Statistics'
\echo '----------------------------------------------------------------------'

SELECT 
    scenery_v2_primary, 
    COUNT(*) as count,
    AVG(scenery_v2_confidence)::NUMERIC(10,2) as avg_conf
FROM osm_all_roads
WHERE scenery_v2_source = 'worldcover_2020_50m'
GROUP BY scenery_v2_primary;
