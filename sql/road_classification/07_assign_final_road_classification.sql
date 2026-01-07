-- Add a column for final road classification
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS final_road_classification_from_grid_overlap VARCHAR;

-- Assign final_road_classification_from_grid_overlap when multi_grid is FALSE
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_road_classification_from_grid_overlap = 
    CASE
        WHEN length_Urban_WoH > 0 THEN 'UrbanWoH'
        WHEN length_Urban_H > 0 THEN 'UrbanH'
        WHEN length_SemiUrban_WoH > 0 THEN 'SemiUrbanWoH'
        WHEN length_SemiUrban_H > 0 THEN 'SemiUrbanH'
        WHEN length_Rural_WoH > 0 THEN 'RuralWoH'
        WHEN length_Rural_H > 0 THEN 'RuralH'
    END
WHERE multi_grid = FALSE
AND bikable_road = TRUE;

-- Assign final_road_classification_from_grid_overlap when multi_grid is TRUE
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_road_classification_from_grid_overlap = 
    CASE
        -- Updated Priority: Urban_WoH or Urban_H
        WHEN length_Urban_WoH > 0 OR length_Urban_H > 0 THEN
            CASE
                WHEN length_Urban_WoH >= length_Urban_H THEN 'UrbanWoH'
                ELSE 'UrbanH'
            END
        
        -- Next priority: SemiUrban_H or Rural_H (take the one with the larger length)
        WHEN length_SemiUrban_H > 0 OR length_Rural_H > 0 THEN 
            CASE
                WHEN length_SemiUrban_H >= length_Rural_H THEN 'SemiUrbanH'
                ELSE 'RuralH'
            END

        -- Last priority: SemiUrban_WoH or Rural_WoH (take the one with the larger length)
        ELSE
            CASE
                WHEN length_SemiUrban_WoH >= length_Rural_WoH THEN 'SemiUrbanWoH'
                ELSE 'RuralWoH'
            END
    END
WHERE multi_grid = TRUE
AND bikable_road = TRUE;

-- Catch-all: Assign any remaining NULL values as 'RuralWoH' (default classification)
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_road_classification_from_grid_overlap = 'RuralWoH'
WHERE final_road_classification_from_grid_overlap IS NULL
AND bikable_road = TRUE;

-- Ensure classification columns exist (idempotent)
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification_i1 VARCHAR,
ADD COLUMN IF NOT EXISTS road_setting_i1 VARCHAR,
ADD COLUMN IF NOT EXISTS road_type_i1 VARCHAR;

-- Derive:
-- 1) road_setting_i1: Urban/SemiUrban/Rural (from final_road_classification_from_grid_overlap)
-- 2) road_type_i1: NH/SH/MDR/OH/HAdj/WoH (from highway + ref only)
-- 3) road_classification_i1: road_setting_i1 || road_type_i1 (e.g., RuralSH)
--
-- This fixes the conflation where '*WoH' (a grid/context label) previously overrode road type,
-- leading to cases like road_classification_i1='RuralWoH' with highway='primary'.
UPDATE osm_all_roads r
SET
  road_setting_i1 = d.road_setting_i1,
  road_type_i1 = d.road_type_i1,
  -- Only overwrite when we have a setting (i.e., the road intersected a grid).
  road_classification_i1 = COALESCE(d.road_classification_i1, r.road_classification_i1)
FROM (
  SELECT
    osm_id,
    CASE
      WHEN final_road_classification_from_grid_overlap LIKE 'Urban%' THEN 'Urban'
      WHEN final_road_classification_from_grid_overlap LIKE 'SemiUrban%' THEN 'SemiUrban'
      WHEN final_road_classification_from_grid_overlap LIKE 'Rural%' THEN 'Rural'
      ELSE NULL
    END AS road_setting_i1,
    CASE
      WHEN COALESCE(ref,'') ILIKE '%NH%'
        OR (COALESCE(ref,'') NOT ILIKE '%SH%' AND COALESCE(ref,'') NOT ILIKE '%MDR%' AND highway IN ('trunk','trunk_link','motorway','motorway_link'))
        THEN 'NH'
      WHEN COALESCE(ref,'') ILIKE '%SH%'
        OR (COALESCE(ref,'') NOT ILIKE '%MDR%' AND highway IN ('primary','primary_link'))
        THEN 'SH'
      WHEN COALESCE(ref,'') ILIKE '%MDR%'
        OR highway IN ('secondary','secondary_link')
        THEN 'MDR'
      WHEN highway IN (
        'primary','primary_link',
        'secondary','secondary_link'
      )
        THEN 'OH'
      WHEN highway IN ('tertiary','tertiary_link')
        THEN 'HAdj'
      WHEN highway = 'track'
        THEN 'Track'
      WHEN highway = 'path'
        THEN 'Path'
      ELSE 'WoH'
    END AS road_type_i1,
    (
      CASE
        WHEN final_road_classification_from_grid_overlap LIKE 'Urban%' THEN 'Urban'
        WHEN final_road_classification_from_grid_overlap LIKE 'SemiUrban%' THEN 'SemiUrban'
        WHEN final_road_classification_from_grid_overlap LIKE 'Rural%' THEN 'Rural'
        ELSE NULL
      END
      ||
      CASE
        WHEN COALESCE(ref,'') ILIKE '%NH%'
          OR (COALESCE(ref,'') NOT ILIKE '%SH%' AND COALESCE(ref,'') NOT ILIKE '%MDR%' AND highway IN ('trunk','trunk_link','motorway','motorway_link'))
          THEN 'NH'
        WHEN COALESCE(ref,'') ILIKE '%SH%'
          OR (COALESCE(ref,'') NOT ILIKE '%MDR%' AND highway IN ('primary','primary_link'))
          THEN 'SH'
        WHEN COALESCE(ref,'') ILIKE '%MDR%'
          OR highway IN ('secondary','secondary_link')
          THEN 'MDR'
        WHEN highway IN (
          'primary','primary_link',
          'secondary','secondary_link'
        )
          THEN 'OH'
        WHEN highway IN ('tertiary','tertiary_link')
          THEN 'HAdj'
        WHEN highway = 'track'
          THEN 'Track'
        WHEN highway = 'path'
          THEN 'Path'
        ELSE 'WoH'
      END
    ) AS road_classification_i1
  FROM osm_all_roads
  WHERE bikable_road = TRUE
) d
WHERE r.osm_id = d.osm_id
  AND r.bikable_road = TRUE;

-- Step 4.1: Add a column to store base road classification for compatibility with the previous version
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification VARCHAR;


-- 1) Add more granular road classification
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification_v2 TEXT;

UPDATE osm_all_roads
SET
  road_classification_v2 = CASE road_classification_i1
    WHEN 'UrbanNH'         THEN 'NH'
    WHEN 'UrbanSH'         THEN 'SH'
    WHEN 'UrbanMDR'        THEN 'Urban'
    WHEN 'UrbanOH'         THEN 'Urban'
    WHEN 'UrbanHAdj'       THEN 'Urban'
    WHEN 'UrbanTrack'      THEN 'Urban'
    WHEN 'UrbanPath'       THEN 'Urban'
    WHEN 'UrbanWoH'        THEN 'Urban'
    WHEN 'SemiUrbanNH'     THEN 'NH'
    WHEN 'SemiUrbanSH'     THEN 'SH'
    WHEN 'SemiUrbanMDR'    THEN 'SH'
    WHEN 'SemiUrbanOH'     THEN 'SH'
    WHEN 'SemiUrbanHAdj'   THEN 'Service'
    WHEN 'SemiUrbanTrack'  THEN 'Interior'
    WHEN 'SemiUrbanPath'   THEN 'Interior'
    WHEN 'SemiUrbanWoH'    THEN 'Interior'
    WHEN 'RuralNH'         THEN 'NH'
    WHEN 'RuralSH'         THEN 'SH'
    WHEN 'RuralMDR'        THEN 'SH'
    WHEN 'RuralOH'         THEN 'SH'
    WHEN 'RuralHAdj'       THEN 'Service'
    WHEN 'RuralTrack'      THEN 'Interior'
    WHEN 'RuralPath'       THEN 'Interior'
    WHEN 'RuralWoH'        THEN 'Interior'
    ELSE road_classification_v2
  END,
  -- Legacy 3-bucket classification
  road_classification = CASE
    WHEN road_type_i1 = 'NH' THEN 'NH'
    WHEN road_type_i1 = 'SH' THEN 'SH'
    WHEN road_type_i1 IS NOT NULL THEN 'UNKNOWN'
    ELSE road_classification
  END
WHERE bikable_road = TRUE;


