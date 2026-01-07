# Legacy Code Structure

This directory contains legacy implementations organized by category.

## Directory Structure

```
legacy-code/
├── README.md                          # Overview of legacy code
├── STRUCTURE.md                       # This file
├── road_curvature_classification/     # Legacy curvature v1 (entire directory)
│   ├── 01_create_separate_geom_column_as_Linestring.sql
│   ├── 02_remove_straight_roads.sql
│   ├── 03_add_node_count.sql
│   ├── 04_add_columns_for_curvature_calculation.sql
│   ├── 05_update_curvature_value_in_main_table.sql
│   ├── 051_calculate_curvature_and_update.sql
│   └── 051_resume_from_update.sql
├── 00_schema_intersection_v1.sql     # Legacy intersection density v1
├── 01_find_and_score_intersections_v1.sql
├── 02_aggregate_scores_per_way_v1.sql
├── 03_calculate_and_update_density_v1.sql
├── 07_road_classification_old_for_ref.sql  # Old road classification reference
├── 01_drop_create_india_grids.sql         # Obsolete grid table stub
├── 09_add_mdr.sql                          # Obsolete MDR classification (outdated logic)
├── write_tags_to_pbf.py                    # Legacy PBF writer (v1)
└── Lua2_RouteProcessing.lua                # Legacy Lua script (v2)
```

## Current Implementations

- **Curvature:** `sql/road_curvature_v2/` (uses twistiness_score, conflict zone suppression)
- **Intersection:** `sql/road_intersection_density/*_v2.sql` (speed degradation approach)
- **Road Classification:** `sql/road_classification/07_assign_final_road_classification.sql`

