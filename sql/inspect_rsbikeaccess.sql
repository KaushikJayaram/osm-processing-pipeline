-- Inspect rsbikeaccess='no' by highway classification
-- Count of roads and total length (km) where rsbikeaccess = 'no'

-- Option 1: Detailed breakdown by highway type
SELECT 
    highway,
    COUNT(*) AS road_count,
    ROUND(SUM(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS total_length_km,
    ROUND(AVG(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS avg_length_km,
    ROUND(MIN(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS min_length_km,
    ROUND(MAX(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS max_length_km
FROM osm_all_roads
WHERE rsbikeaccess = 'no'
    AND geometry IS NOT NULL
    AND highway IS NOT NULL
GROUP BY highway
ORDER BY total_length_km DESC;

-- Option 2: Summary with grand totals (fixed UNION query)
SELECT 
    highway,
    road_count,
    total_length_km
FROM (
    SELECT 
        highway,
        COUNT(*) AS road_count,
        ROUND(SUM(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS total_length_km,
        0 AS sort_order
    FROM osm_all_roads
    WHERE rsbikeaccess = 'no'
        AND geometry IS NOT NULL
        AND highway IS NOT NULL
    GROUP BY highway

    UNION ALL

    SELECT 
        'TOTAL' AS highway,
        COUNT(*) AS road_count,
        ROUND(SUM(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS total_length_km,
        1 AS sort_order
    FROM osm_all_roads
    WHERE rsbikeaccess = 'no'
        AND geometry IS NOT NULL
        AND highway IS NOT NULL
) AS combined
ORDER BY sort_order, total_length_km DESC;

-- ============================================================================
-- Fix rsbikeaccess: Set to 'yes' for highway types that should not have 'no'
-- ============================================================================
-- rsbikeaccess should only be 'no' for:
--   motorway, motorway_link, trunk, trunk_link, proposed, construction
-- All other highway types with rsbikeaccess='no' should be set to 'yes'

-- Step 1: Preview what will be changed (run this first to verify)
SELECT 
    highway,
    COUNT(*) AS road_count,
    ROUND(SUM(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS total_length_km
FROM osm_all_roads
WHERE rsbikeaccess = 'no'
    AND highway IS NOT NULL
    AND highway NOT IN ('motorway', 'motorway_link', 'trunk', 'trunk_link', 'proposed', 'construction')
GROUP BY highway
ORDER BY total_length_km DESC;

-- Step 2: Update rsbikeaccess to 'yes' for invalid highway types
UPDATE osm_all_roads
SET rsbikeaccess = 'yes'
WHERE rsbikeaccess = 'no'
    AND highway IS NOT NULL
    AND highway NOT IN ('motorway', 'motorway_link', 'trunk', 'trunk_link', 'proposed', 'construction');

-- Step 3: Verify the fix (should return 0 rows or only the allowed highway types)
SELECT 
    highway,
    COUNT(*) AS road_count,
    ROUND(SUM(ST_Length(geometry::geography) / 1000.0)::numeric, 2) AS total_length_km
FROM osm_all_roads
WHERE rsbikeaccess = 'no'
    AND geometry IS NOT NULL
    AND highway IS NOT NULL
GROUP BY highway
ORDER BY total_length_km DESC;
