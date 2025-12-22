-- Assign urban, semiurban and rural scenery

UPDATE osm_all_roads
SET road_scenery_urban = 1
WHERE final_road_classification_from_grid_overlap IN ('UrbanWoH', 'UrbanH');

UPDATE osm_all_roads
SET road_scenery_semiurban = 1
WHERE final_road_classification_from_grid_overlap IN ('SemiUrbanH', 'SemiUrbanWoH');

UPDATE osm_all_roads
SET road_scenery_rural = 1
WHERE final_road_classification_from_grid_overlap IN ('RuralH', 'RuralWoH');