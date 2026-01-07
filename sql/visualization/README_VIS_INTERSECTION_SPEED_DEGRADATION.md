# Intersection Speed Degradation Visualization Views

This directory contains SQL scripts to create materialized views for visualizing intersection speed degradation test results in QGIS or other GIS tools.

## Scripts

### 1. `00_drop_all_vis_views.sql`

Drops all existing materialized views in the `vis` schema. Run this first before creating new views.

**Usage:**
```sql
\i sql/visualization/00_drop_all_vis_views.sql
```

### 2. `vis_intersection_speed_degradation_tests.sql`

Creates materialized views for all intersection speed degradation test cases. This script:
- Automatically discovers all test cases from `test_isd_*_final_results` tables
- Creates 3 views per test case (base, setting adjusted, final degradation)
- Only creates z10 views (medium detail, 0.0005 tolerance)

**Usage:**
```sql
\i sql/visualization/vis_intersection_speed_degradation_tests.sql
```

## Views Created

For each test case (e.g., `base`, `major_score_plus_10pct`), 3 views are created:

### 1. Base Degradation View
**Name:** `vis.map_isd_<test_name>_base_degradation_z10`

**Columns:**
- `osm_id`, `way_id`
- `base_degradation`: Base degradation (0.0 to 0.5)
- `intersection_count`: Total intersections
- `major_count`, `middling_count`, `minor_count`: Intersection type counts
- `calculation_method`: 'weighted_average' or 'multiplicative'
- `length_km`: Road length in kilometers
- `road_type_i1`, `road_setting_i1`, `road_classification_v2`
- `highway`: OSM highway tag
- `population_density`, `build_perc`
- `ref`, `name`: Road reference and name
- `geom`: Simplified geometry (0.0005 tolerance)

### 2. Setting Adjusted Degradation View
**Name:** `vis.map_isd_<test_name>_setting_adjusted_z10`

**Columns:**
- `osm_id`, `way_id`
- `setting_adjusted_degradation`: After setting multiplier applied
- `base_degradation`: Original base degradation
- `road_setting_i1`: Urban, SemiUrban, or Rural
- `intersection_count`
- `length_km`
- `road_type_i1`, `road_classification_v2`, `highway`
- `population_density`, `build_perc`
- `ref`, `name`
- `geom`: Simplified geometry

### 3. Final Degradation View
**Name:** `vis.map_isd_<test_name>_final_degradation_z10`

**Columns:**
- `osm_id`, `way_id`
- `final_intersection_speed_degradation`: Final value (0.0 to 0.5)
- `setting_adjusted_degradation`: After setting multiplier
- `base_degradation`: Original base degradation
- `intersection_count`, `major_count`, `middling_count`, `minor_count`
- `calculation_method`
- `length_km`
- `road_type_i1`, `road_setting_i1`, `road_classification_v2`
- `highway`, `lanes`, `oneway`
- `lanes_count`: Parsed lanes (integer)
- `is_oneway`: Boolean oneway flag
- `applied_lanes_oneway_factor`: Whether lanes+oneway factor was applied
- `population_density`, `build_perc`
- `ref`, `name`
- `geom`: Simplified geometry

## Test Cases

Views are automatically created for all test cases found in the database. Common test cases include:

- `base`: Base variable values
- `major_score_plus_10pct`: Major score +10%
- `major_score_minus_10pct`: Major score -10%
- `middling_score_plus_10pct`: Middling score +10%
- `middling_score_minus_10pct`: Middling score -10%
- `major_impact_distance_m_plus_10pct`: Major impact distance +10%
- `major_impact_distance_m_minus_10pct`: Major impact distance -10%
- `middling_impact_distance_m_plus_10pct`: Middling impact distance +10%
- `middling_impact_distance_m_minus_10pct`: Middling impact distance -10%
- `major_speed_reduction_plus_10pct`: Major speed reduction +10%
- `major_speed_reduction_minus_10pct`: Major speed reduction -10%
- `middling_speed_reduction_plus_10pct`: Middling speed reduction +10%
- `middling_speed_reduction_minus_10pct`: Middling speed reduction -10%

## Usage in QGIS

1. **Connect to PostgreSQL:**
   - Add PostgreSQL connection in QGIS
   - Connect to your database

2. **Add Views:**
   - Right-click on connection → "Add Layer"
   - Select schema: `vis`
   - Choose view: `map_isd_<test_name>_<degradation_type>_z10`

3. **Style by Degradation:**
   - Use graduated symbology
   - Column: `base_degradation`, `setting_adjusted_degradation`, or `final_intersection_speed_degradation`
   - Range: 0.0 to 0.5
   - Color ramp: Red (high degradation) to Green (low degradation)

4. **Compare Test Cases:**
   - Load multiple views for different test cases
   - Use different colors/styles to compare
   - Filter by `road_setting_i1` or `road_type_i1` to focus on specific road types

## Refreshing Views

After running new tests or updating test data, refresh the views:

```sql
-- Refresh all views for a specific test case
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_base_base_degradation_z10;
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_base_setting_adjusted_z10;
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_base_final_degradation_z10;
```

Or refresh all views:

```sql
-- List all views
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'vis' 
  AND table_name LIKE 'map_isd_%';

-- Refresh each view (run for each view)
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_isd_<test_name>_<type>_z10;
```

## Indexes

Each view has spatial and attribute indexes for fast querying:

- **Spatial index:** GIST index on `geom`
- **Attribute indexes:** On degradation values, road_setting_i1, road_type_i1

## Notes

- Views are created at **z10 zoom level only** (medium detail)
- Geometry is simplified with 0.0005 tolerance for performance
- Views automatically discover all test cases from `test_isd_*_final_results` tables
- If you add new test cases, re-run the script to create views for them
- Views join with `osm_all_roads` to get geometry and additional attributes

