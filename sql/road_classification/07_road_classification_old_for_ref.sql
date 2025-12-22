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

-- Add a column to store road classification
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification_i1 VARCHAR;

-- Classify roads into Urban, NH, SH, NH_or_SH, NHSH_Adjacent, or Interior
-- Rule 1: Assign Urban classifications based on the road itself (not just the grid)
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_i1 =
    CASE
        WHEN final_road_classification_from_grid_overlap = 'UrbanH'
             AND (
                 highway IN ('motorway','trunk')
                 OR ref LIKE '%NH%'
                 OR ref LIKE '%SH%'
             )
        THEN 'UrbanH'
        WHEN final_road_classification_from_grid_overlap IN ('UrbanH','UrbanWoH')
        THEN 'UrbanWoH'
    END
WHERE final_road_classification_from_grid_overlap IN ('UrbanH','UrbanWoH')
AND bikable_road = TRUE;

-- Rule 2a: Assign NH to roads in SemiUrban_H or Rural_H with NH ref
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_i1 = 'NH'
WHERE final_road_classification_from_grid_overlap IN ('SemiUrbanH', 'RuralH')
AND ref LIKE '%NH%'
AND bikable_road = TRUE;

-- Rule 2b: Assign SH to roads in SemiUrban_H or Rural_H with SH ref
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_i1 = 'SH'
WHERE final_road_classification_from_grid_overlap IN ('SemiUrbanH', 'RuralH')
AND ref LIKE '%SH%'
AND bikable_road = TRUE;

-- Rule 2c: Assign NH_or_SH to roads in SemiUrban_H or Rural_H with motorway/trunk highway type
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_i1 = 'NHorSH'
WHERE final_road_classification_from_grid_overlap IN ('SemiUrbanH', 'RuralH')
AND road_classification_i1 IS NULL
AND highway IN ('motorway', 'trunk')
AND bikable_road = TRUE;

-- Rule 2d: Assign NHSH_Adjacent to other roads in SemiUrban_H or Rural_H
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_i1 = 'NHSHAdjacent'
WHERE final_road_classification_from_grid_overlap IN ('SemiUrbanH', 'RuralH')
AND road_classification_i1 IS NULL
AND bikable_road = TRUE;

-- Rule 3: Assign Interior classification to SemiUrban_WoH or Rural_WoH
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_i1 = 'Interior'
WHERE final_road_classification_from_grid_overlap IN ('SemiUrbanWoH', 'RuralWoH')
AND bikable_road = TRUE;

-- Step 4.1: Add a column to store base road classification for compatibility with the previous version
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification VARCHAR;

-- Rule 1: Assign NH
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification = 'NH'
WHERE road_classification_i1 IN ('NH', 'NHorSH')
AND bikable_road = TRUE;

-- Rule 2: Assign SH
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification = 'SH'
WHERE road_classification_i1 = 'SH'
AND bikable_road = TRUE;

-- Rule 3: Assign Unknown
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification = 'Unknown'
WHERE road_classification_i1 IN ('NHSHAdjacent', 'Interior')
AND bikable_road = TRUE;


-- 1) Add the v3 column (idempotent)
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification_v2 TEXT;

-- 2) Backfill v3 from v2 per your rules
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET road_classification_v2 = CASE road_classification_i1
    WHEN 'UrbanH'        THEN 'Urban'
    WHEN 'UrbanWoH'      THEN 'Urban'
    WHEN 'NH'            THEN 'NH'
    WHEN 'SH'            THEN 'SH'
    WHEN 'NHorSH'        THEN 'NH'
    WHEN 'NHSHAdjacent'  THEN 'NH'
    WHEN 'Interior'      THEN 'Interior'
    ELSE 'Unknown'
END
WHERE bikable_road = TRUE;

