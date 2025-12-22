ALTER TABLE osm_all_roads
ADD COLUMN mdr TEXT;

-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET mdr = 'TRUE'
WHERE ref ILIKE '%MDR%'
AND bikable_road = TRUE;

ALTER TABLE osm_all_roads
  ADD COLUMN IF NOT EXISTS maybe_mdr_secondary text;

ALTER TABLE osm_all_roads
  ADD COLUMN IF NOT EXISTS maybe_mdr_primary text;

-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET maybe_mdr_secondary = CASE
    WHEN highway = 'secondary'
     AND road_classification_i1 = 'Interior'
     AND final_road_classification_from_grid_overlap IN
         ('SemiUrbanH','SemiUrbanWoH','RuralH','RuralWoH')
    THEN 'TRUE'
    ELSE 'FALSE'
END
WHERE mdr IS DISTINCT FROM 'TRUE'  -- don't override known MDRs
AND bikable_road = TRUE;

-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET maybe_mdr_primary = CASE
    WHEN highway = 'primary'
     AND road_classification_i1 = 'Interior'
     AND final_road_classification_from_grid_overlap IN
         ('SemiUrbanH','SemiUrbanWoH','RuralH','RuralWoH')
    THEN 'TRUE'
    ELSE 'FALSE'
END
WHERE mdr IS DISTINCT FROM 'TRUE'  -- don't override known MDRs
AND bikable_road = TRUE;

ALTER TABLE osm_all_roads
  ADD COLUMN IF NOT EXISTS final_mdr_status text;

-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_mdr_status = CASE
    WHEN mdr = 'TRUE' THEN 'mdr'
    WHEN maybe_mdr_primary = 'TRUE' THEN 'maybe_mdr_primary'
    WHEN maybe_mdr_secondary = 'TRUE' THEN 'maybe_mdr_secondary'
    ELSE 'not_mdr'
END
WHERE bikable_road = TRUE;