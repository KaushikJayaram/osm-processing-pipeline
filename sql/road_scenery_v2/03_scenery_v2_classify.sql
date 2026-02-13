-- 03_scenery_v2_classify.sql
-- Classifies scenery tags based on WorldCover fractions.

BEGIN;

-- 1. Reset existing Scenery V2 tags for rows that will be re-processed
-- This ensures clean state if running multiple times.
-- We only touch rows where scenery_v2_source is 'worldcover_2020_50m' OR NULL.
UPDATE osm_all_roads
SET 
    scenery_v2_primary = NULL,
    scenery_v2_forest = FALSE,
    scenery_v2_field = FALSE,
    scenery_v2_desert = FALSE,
    scenery_v2_snow = FALSE,
    scenery_v2_water = FALSE,
    scenery_v2_confidence = NULL
WHERE scenery_v2_source = 'worldcover_2020_50m' OR scenery_v2_source IS NULL;

-- 2. Compute classification
-- We ignore roads that are already Urban or Semi-urban
WITH classification_data AS (
    SELECT 
        osm_id,
        wc_forest_frac,
        wc_field_frac,
        wc_desert_frac,
        wc_snow_frac,
        wc_water_frac,
        -- Determine max fraction
        GREATEST(
            COALESCE(wc_forest_frac, 0),
            COALESCE(wc_field_frac, 0),
            COALESCE(wc_desert_frac, 0),
            COALESCE(wc_snow_frac, 0),
            COALESCE(wc_water_frac, 0)
        ) as max_frac
    FROM osm_all_roads
    WHERE wc_total_px > 0
),
primary_determination AS (
    SELECT 
        osm_id,
        max_frac,
        CASE 
            WHEN max_frac < 0.8 THEN NULL -- No primary if below threshold
            WHEN max_frac = COALESCE(wc_forest_frac, 0) THEN 'forest'
            WHEN max_frac = COALESCE(wc_field_frac, 0) THEN 'field'
            WHEN max_frac = COALESCE(wc_desert_frac, 0) THEN 'desert'
            WHEN max_frac = COALESCE(wc_snow_frac, 0) THEN 'snow'
            WHEN max_frac = COALESCE(wc_water_frac, 0) THEN 'water'
            ELSE NULL
        END as primary_class
    FROM classification_data
)
UPDATE osm_all_roads r
SET 
    scenery_v2_confidence = pd.max_frac,
    scenery_v2_primary = pd.primary_class,
    -- Set booleans based on 0.20 threshold
    scenery_v2_forest = (r.wc_forest_frac >= 0.35),
    scenery_v2_field = (r.wc_field_frac >= 0.35),
    scenery_v2_desert = (r.wc_desert_frac >= 0.35),
    scenery_v2_snow = (r.wc_snow_frac >= 0.35),
    scenery_v2_water = (r.wc_water_frac >= 0.35),
    scenery_v2_source = 'worldcover_2020_50m'
FROM primary_determination pd
WHERE r.osm_id = pd.osm_id;

COMMIT;
