# Legacy Code Archive

This directory contains legacy implementations that have been replaced by newer v2 versions.

**Status:** These files are kept for reference only. They are **NOT** used in the current pipeline.

---

## Contents

### Road Curvature v1 (Legacy)
**Directory:** `road_curvature_classification/`

**Status:** Replaced by `sql/road_curvature_v2/`

**Files:**
- `01_create_separate_geom_column_as_Linestring.sql`
- `02_remove_straight_roads.sql`
- `03_add_node_count.sql`
- `04_add_columns_for_curvature_calculation.sql`
- `05_update_curvature_value_in_main_table.sql`
- `051_calculate_curvature_and_update.sql`
- `051_resume_from_update.sql`

**Current Implementation:** `sql/road_curvature_v2/` (uses twistiness_score, conflict zone suppression)

---

### Intersection Density v1 (Legacy)
**Files:**
- `00_schema_intersection_v1.sql` - Legacy schema (replaced by `00_schema_v2.sql`)
- `01_find_and_score_intersections_v1.sql` - Legacy intersection finding (replaced by `01_find_and_categorize_intersections_v2.sql`)
- `02_aggregate_scores_per_way_v1.sql` - Legacy aggregation (replaced by `02_map_intersections_to_ways_v2.sql`)
- `03_calculate_and_update_density_v1.sql` - Legacy density calculation (replaced by `03_calculate_base_degradation_v2.sql` and `04_calculate_final_degradation_v2.sql`)

**Status:** Replaced by Intersection Speed Degradation (v2) in `sql/road_intersection_density/*_v2.sql`

**Old Output:** `intersection_density_per_km`, `intersection_congestion_factor`  
**New Output:** `intersection_speed_degradation_base`, `intersection_speed_degradation_setting_adjusted`, `intersection_speed_degradation_final`

---

### Road Classification (Old Reference)
**File:** `07_road_classification_old_for_ref.sql`

**Status:** Old version kept for reference only. Current implementation: `sql/road_classification/07_assign_final_road_classification.sql`

---

### Scripts (Legacy)
**Files:**
- `write_tags_to_pbf.py` - Old PBF writer (replaced by `scripts/write_tags_to_pbf_2.py`)
- `Lua2_RouteProcessing.lua` - Legacy Lua script (replaced by `scripts/Lua3_RouteProcessing_with_curvature.lua`)

**Status:** Legacy versions kept for reference only. Current implementations are in `scripts/` directory.

---

### Road Classification (Obsolete SQL)
**Files:**
- `01_drop_create_india_grids.sql` - Minimal table creation stub (replaced by `01_create_india_grids.sql` which does full grid generation)
- `09_add_mdr.sql` - Obsolete MDR classification script (commented out, uses outdated `road_classification_i1 = 'Interior'` logic that doesn't exist in current system)

**Status:** Obsolete scripts kept for reference only. Not used in current pipeline.

---

## Notes

- These files are **archived for historical reference only**
- Do **NOT** use these in production
- Current implementations are in their respective `sql/` directories with `_v2` suffix or `v2` directory
- If you need to reference old logic, check git history or these files

