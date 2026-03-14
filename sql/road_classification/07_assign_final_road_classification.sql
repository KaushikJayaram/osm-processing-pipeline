-- Chunk params: :osm_id_min, :osm_id_max
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
  road_type_i1 = d.road_type_i1
FROM (
  SELECT
    osm_id,
    final_road_classification_from_grid_overlap AS road_setting_i1,
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
        THEN 'WoH'
      WHEN highway = 'track'
        THEN 'Track'
      WHEN highway = 'path'
        THEN 'Path'
      WHEN highway = 'residential'
        THEN 'Res'
      ELSE 'WoH'
    END AS road_type_i1
  FROM osm_all_roads
  WHERE bikable_road = TRUE
    AND road_type_i1 IS NULL
  :osm_id_filter_clause
) d
WHERE r.osm_id = d.osm_id
  AND r.bikable_road = TRUE
  AND r.road_type_i1 IS NULL
  AND r.osm_id BETWEEN :osm_id_min AND :osm_id_max
  :osm_id_filter_clause_r;

UPDATE osm_all_roads r
SET
  road_classification_i1 = r.road_setting_i1 || r.road_type_i1
WHERE r.bikable_road = TRUE
  AND r.road_type_i1 IS NULL
  AND r.osm_id BETWEEN :osm_id_min AND :osm_id_max
  :osm_id_filter_clause_r;

-- Upgrade eligible tertiary/tertiary_link roads from WoH to HAdj.
-- Use geom_3857 and existing indexes (no per-chunk highway temp table).
DROP TABLE IF EXISTS tmp_road_endpoints;
CREATE TEMP TABLE tmp_road_endpoints AS
SELECT
  osm_id,
  ST_StartPoint(geom_3857) AS start_geom,
  ST_EndPoint(geom_3857) AS end_geom
FROM osm_all_roads
WHERE bikable_road = TRUE
  AND road_type_i1 IS NULL
  AND highway IN ('tertiary','tertiary_link')
  AND osm_id BETWEEN :osm_id_min AND :osm_id_max
  :osm_id_filter_clause;
CREATE INDEX ON tmp_road_endpoints USING GIST (start_geom);
CREATE INDEX ON tmp_road_endpoints USING GIST (end_geom);

UPDATE osm_all_roads r
SET
  road_type_i1 = 'HAdj',
  road_classification_i1 = r.road_setting_i1 || 'HAdj'
FROM tmp_road_endpoints e
WHERE r.osm_id = e.osm_id
  AND EXISTS (
    SELECT 1
    FROM osm_all_roads h
    WHERE h.bikable_road = TRUE
      AND h.road_type_i1 IN ('NH', 'SH', 'MDR', 'OH')
      AND ST_DWithin(e.start_geom, h.geom_3857, 50)
  )
  AND EXISTS (
    SELECT 1
    FROM osm_all_roads h
    WHERE h.bikable_road = TRUE
      AND h.road_type_i1 IN ('NH', 'SH', 'MDR', 'OH')
      AND ST_DWithin(e.end_geom, h.geom_3857, 50)
  );

