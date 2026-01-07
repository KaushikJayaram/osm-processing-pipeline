## Curvature v2 mini-module

This is a **standalone** curvature pipeline inspired by the ideas described on [`roadcurvature.com`](https://roadcurvature.com/) (especially suppressing curvature near “conflict points”).

### What it computes

- **Per-way curvature buckets (meters)**: `meters_sharp`, `meters_broad`, `meters_straight`
- **Numeric twistiness**: `twistiness_score = (sharp + 0.5*broad) / total_length`
- **Class**: `straight` / `broad` / `sharp` (simple thresholds; tune as needed)
- **Conflict-zone suppression**: zero-out curvature within **30m** (along-the-way) of conflict nodes.

### Requirements

You must import OSM using the **new** flex style file:

- `scripts/Lua3_RouteProcessing_with_curvature.lua`

This creates:
- `rs_highway_way_nodes` (ordered nodes per way with lon/lat)
- `rs_conflict_nodes` (tagged conflict nodes)

### Running (standalone)

Use the runner:

- `iterative-runs/run_curvature_v2.py`

### SQL execution order

**IMPORTANT**: Validation happens automatically during OSM import (in `scripts/import_into_postgres.py`)

1. `00_validate_import.sql` - **AUTOMATIC**: Runs immediately after OSM import, validates coordinates are populated
2. `00_schema.sql` - Create tables
3. `01_prepare_inputs.sql` - **VALIDATED**: Checks for NULL coordinates, fails fast if all are NULL
4. `02_compute_vertex_angles.sql` - **VALIDATED**: Checks for NULL geometries, fails fast if all are NULL
5. `03_classify_radius_and_segment_meters.sql` - Placeholder
6. `04_conflict_zone_suppression.sql` - **VALIDATED**: Checks for cumulative distance data
7. `05_aggregate_to_way.sql` - **VALIDATED**: Checks for distance data, fails if all ways have zero length
8. (optional) `06_optional_update_osm_all_roads.sql`
9. `analysis/curvature_v2_diagnostics.sql` - Diagnostic queries for debugging (moved to analysis folder)
10. `99_validation.sql` - Validation queries to check results

### Validation & Error Handling

**Automatic validation during import:**
- `00_validate_import.sql` runs **automatically** right after OSM import completes
- **FAILS IMMEDIATELY** if coordinates are not populated (prevents wasting time on downstream processing)
- Integrated into `scripts/import_into_postgres.py` - no manual step needed

**All scripts include validation checks that will:**
- **FAIL FAST** with clear error messages if required data is missing
- **WARN** if >50% of data has issues (but still proceed)
- **NOTICE** when validation passes successfully

This prevents silent failures where the pipeline appears to run but produces invalid results.

**Common Issues:**

1. **Import validation fails: "All coordinates are NULL"**
   - **Cause**: OSM import didn't populate node coordinates (nodes not processed before ways, or cache issue, or wrong Lua script)
   - **Fix**: Re-import using `Lua3_RouteProcessing_with_curvature.lua` (not Lua2)
   - **When**: This will be caught immediately after import, before any processing starts

2. **All geometries are NULL in `rs_curvature_way_vertices`**
   - **Cause**: Source coordinates are NULL (should have been caught by import validation)
   - **Fix**: Re-run import (see issue #1)

3. **All distances are NULL in `rs_curvature_vertex_metrics`**
   - **Cause**: Geometries are NULL or invalid (should have been caught earlier)
   - **Fix**: Check previous validation steps

### Notes

- This module is intentionally **not integrated** into `scripts/add_custom_tags.py` yet.
- Conflict points include:
  - tagged controls from `rs_conflict_nodes` (traffic signals, stop, give_way, crossings, etc.)
  - derived intersections: nodes appearing in **>=2 distinct ways**


