-- Analysis of Unique Road Classification Combinations
-- This query shows all unique combinations of classification attributes
-- and the count of roads for each combination
-- Includes ALL roads in osm_all_roads (not just bikable roads)

SELECT 
    bikable_road,
    final_road_classification_from_grid_overlap,
    road_setting_i1,
    road_type_i1,
    road_classification_i1,
    road_classification,
    road_classification_v2,
    final_mdr_status,
    COUNT(*) as road_count,
    SUM(ST_Length(geometry::geography))/1000 as total_length_km
FROM osm_all_roads
WHERE geometry IS NOT NULL
GROUP BY 
    bikable_road,
    final_road_classification_from_grid_overlap,
    road_setting_i1,
    road_type_i1,
    road_classification_i1,
    road_classification,
    road_classification_v2,
    final_mdr_status
ORDER BY 
    bikable_road DESC,
    final_road_classification_from_grid_overlap,
    road_setting_i1,
    road_type_i1,
    road_classification_i1,
    road_classification,
    road_classification_v2,
    final_mdr_status;

-- Summary: Total number of unique combinations and road counts
SELECT 
    COUNT(*) as total_unique_combinations,
    SUM(road_count) as total_roads,
    SUM(CASE WHEN bikable_road = TRUE THEN road_count ELSE 0 END) as bikable_roads,
    SUM(CASE WHEN bikable_road = FALSE OR bikable_road IS NULL THEN road_count ELSE 0 END) as non_bikable_roads,
    SUM(total_length_meters) as total_length_meters,
    SUM(CASE WHEN bikable_road = TRUE THEN total_length_meters ELSE 0 END) as bikable_roads_length_meters,
    SUM(CASE WHEN bikable_road = FALSE OR bikable_road IS NULL THEN total_length_meters ELSE 0 END) as non_bikable_roads_length_meters
FROM (
    SELECT 
        bikable_road,
        final_road_classification_from_grid_overlap,
        road_setting_i1,
        road_type_i1,
        road_classification_i1,
        road_classification,
        road_classification_v2,
        final_mdr_status,
        COUNT(*) as road_count,
        SUM(ST_Length(geometry::geography)) as total_length_meters
    FROM osm_all_roads
    WHERE geometry IS NOT NULL
    GROUP BY 
        bikable_road,
        final_road_classification_from_grid_overlap,
        road_setting_i1,
        road_type_i1,
        road_classification_i1,
        road_classification,
        road_classification_v2,
        final_mdr_status
) subquery;

-- Verify total matches osm_all_roads count and length
-- This helps identify if roads are missing from classification
SELECT 
    COUNT(*) as total_roads_in_table,
    COUNT(*) FILTER (WHERE bikable_road = TRUE) as bikable_roads_in_table,
    COUNT(*) FILTER (WHERE bikable_road = FALSE OR bikable_road IS NULL) as non_bikable_roads_in_table,
    COUNT(*) FILTER (WHERE geometry IS NOT NULL) as roads_with_geometry,
    SUM(ST_Length(geometry::geography)) FILTER (WHERE geometry IS NOT NULL) as total_length_meters_in_table,
    -- Check for roads missing classification
    COUNT(*) FILTER (WHERE bikable_road = TRUE AND final_road_classification_from_grid_overlap IS NULL) as bikable_roads_missing_grid_classification,
    COUNT(*) FILTER (WHERE bikable_road = TRUE AND road_setting_i1 IS NULL) as bikable_roads_missing_road_setting_i1,
    COUNT(*) FILTER (WHERE bikable_road = TRUE AND road_type_i1 IS NULL) as bikable_roads_missing_road_type_i1,
    COUNT(*) FILTER (WHERE bikable_road = TRUE AND road_classification_i1 IS NULL) as bikable_roads_missing_i1_classification,
    COUNT(*) FILTER (WHERE bikable_road = TRUE AND road_classification_v2 IS NULL) as bikable_roads_missing_v2_classification,
    SUM(ST_Length(geometry::geography)) FILTER (WHERE bikable_road = TRUE AND final_road_classification_from_grid_overlap IS NULL AND geometry IS NOT NULL) as bikable_roads_missing_grid_classification_length_meters,
    SUM(ST_Length(geometry::geography)) FILTER (WHERE bikable_road = TRUE AND road_setting_i1 IS NULL AND geometry IS NOT NULL) as bikable_roads_missing_road_setting_i1_length_meters,
    SUM(ST_Length(geometry::geography)) FILTER (WHERE bikable_road = TRUE AND road_type_i1 IS NULL AND geometry IS NOT NULL) as bikable_roads_missing_road_type_i1_length_meters,
    SUM(ST_Length(geometry::geography)) FILTER (WHERE bikable_road = TRUE AND road_classification_i1 IS NULL AND geometry IS NOT NULL) as bikable_roads_missing_i1_classification_length_meters
FROM osm_all_roads;

