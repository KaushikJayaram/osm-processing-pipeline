-- One-time finalization for road classification outputs.
-- Run AFTER the chunked road classification steps are complete.

-- Add scenery setting flags based on road_setting_i1
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_scenery_urban INTEGER,
ADD COLUMN IF NOT EXISTS road_scenery_semiurban INTEGER,
ADD COLUMN IF NOT EXISTS road_scenery_rural INTEGER;

UPDATE osm_all_roads
SET
  road_scenery_urban = CASE WHEN road_setting_i1 = 'Urban' THEN 1 ELSE 0 END,
  road_scenery_semiurban = CASE WHEN road_setting_i1 = 'SemiUrban' THEN 1 ELSE 0 END,
  road_scenery_rural = CASE WHEN road_setting_i1 = 'Rural' THEN 1 ELSE 0 END
WHERE bikable_road = TRUE;

-- Add a column to store base road classification for compatibility with the previous version
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS road_classification VARCHAR;

-- Add more granular road classification
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
    WHEN 'UrbanRes'        THEN 'Interior'
    WHEN 'SemiUrbanNH'     THEN 'NH'
    WHEN 'SemiUrbanSH'     THEN 'SH'
    WHEN 'SemiUrbanMDR'    THEN 'SH'
    WHEN 'SemiUrbanOH'     THEN 'SH'
    WHEN 'SemiUrbanHAdj'   THEN 'Service'
    WHEN 'SemiUrbanTrack'  THEN 'Interior'
    WHEN 'SemiUrbanPath'   THEN 'Interior'
    WHEN 'SemiUrbanWoH'    THEN 'Interior'
    WHEN 'SemiUrbanRes'    THEN 'Interior'
    WHEN 'RuralNH'         THEN 'NH'
    WHEN 'RuralSH'         THEN 'SH'
    WHEN 'RuralMDR'        THEN 'SH'
    WHEN 'RuralOH'         THEN 'SH'
    WHEN 'RuralHAdj'       THEN 'Service'
    WHEN 'RuralTrack'      THEN 'Interior'
    WHEN 'RuralPath'       THEN 'Interior'
    WHEN 'RuralWoH'        THEN 'Interior'
    WHEN 'RuralRes'        THEN 'Interior'
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
