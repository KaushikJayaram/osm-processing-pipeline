-- Curvature v2: lightweight validation / sanity queries.

-- 1) Count output rows
SELECT
    COUNT(*) AS ways_scored,
    AVG(total_length_m) AS avg_len_m,
    AVG(twistiness_score) AS avg_twistiness
FROM rs_curvature_way_summary;

-- 2) Distribution by highway type
SELECT
    o.highway,
    COUNT(*) AS ways,
    AVG(s.twistiness_score) AS avg_twistiness,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.twistiness_score) AS p50_twistiness,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY s.twistiness_score) AS p90_twistiness
FROM rs_curvature_way_summary AS s
JOIN osm_all_roads AS o ON o.osm_id = s.way_id
GROUP BY o.highway
ORDER BY ways DESC;

-- 3) Top twisty ways (spot check on a map)
SELECT
    s.way_id,
    o.name,
    o.ref,
    o.highway,
    s.total_length_m,
    s.meters_sharp,
    s.meters_broad,
    s.twistiness_score,
    s.twistiness_class
FROM rs_curvature_way_summary AS s
JOIN osm_all_roads AS o ON o.osm_id = s.way_id
WHERE s.total_length_m > 500 -- ignore tiny segments
ORDER BY s.twistiness_score DESC
LIMIT 50;


