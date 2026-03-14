-- 03_scenery_v2_classify.sql
-- Classifies scenery tags based on WorldCover fractions.
-- Chunked execution using grid_id ranges.

BEGIN;

-- 1. Reset existing Scenery V2 tags for rows in current chunk
-- Only reset rows that have wc_total_px > 0 (i.e., were processed in sampling step)
UPDATE osm_all_roads r
SET 
    road_scenery_primary = NULL,
    scenery_v2_forest = FALSE,
    scenery_v2_field = FALSE,
    scenery_v2_desert = FALSE,
    scenery_v2_snow = FALSE,
    scenery_v2_water = FALSE,
    scenery_v2_confidence = NULL,
    road_scenery_forest = 0,
    road_scenery_field = 0
FROM public.osm_all_roads_grid rg
WHERE r.osm_id = rg.osm_id
  AND rg.grid_id BETWEEN :grid_id_min AND :grid_id_max
  AND r.wc_total_px > 0;

-- 2. Compute classification for current chunk
WITH classification_data AS (
    SELECT 
        r.osm_id,
        r.wc_forest_frac,
        r.wc_field_frac,
        r.wc_desert_frac,
        r.wc_snow_frac,
        r.wc_water_frac,
        -- Determine max fraction
        GREATEST(
            COALESCE(r.wc_forest_frac, 0),
            COALESCE(r.wc_field_frac, 0),
            COALESCE(r.wc_desert_frac, 0),
            COALESCE(r.wc_snow_frac, 0),
            COALESCE(r.wc_water_frac, 0)
        ) as max_frac
    FROM osm_all_roads r
    JOIN public.osm_all_roads_grid rg
      ON rg.osm_id = r.osm_id
    WHERE rg.grid_id BETWEEN :grid_id_min AND :grid_id_max
      AND r.wc_total_px > 0
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
        END as primary_class,
        wc_forest_frac,
        wc_field_frac,
        wc_desert_frac,
        wc_snow_frac,
        wc_water_frac
    FROM classification_data
)
UPDATE osm_all_roads r
SET 
    scenery_v2_confidence = pd.max_frac,
    road_scenery_primary = pd.primary_class,
    -- Set booleans based on 0.35 threshold
    scenery_v2_forest = (r.wc_forest_frac >= 0.35),
    scenery_v2_field = (r.wc_field_frac >= 0.35),
    scenery_v2_desert = (r.wc_desert_frac >= 0.35),
    scenery_v2_snow = (r.wc_snow_frac >= 0.35),
    scenery_v2_water = (r.wc_water_frac >= 0.35),
    road_scenery_forest = CASE WHEN r.wc_forest_frac >= 0.35 THEN 1 ELSE 0 END,
    road_scenery_field = CASE WHEN r.wc_field_frac >= 0.35 THEN 1 ELSE 0 END
FROM primary_determination pd
WHERE r.osm_id = pd.osm_id;

COMMIT;
