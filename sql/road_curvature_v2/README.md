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

- `scripts/run_curvature_v2.py`

### SQL execution order

1. `00_schema.sql`
2. `01_prepare_inputs.sql`
3. `02_compute_vertex_angles.sql`
4. `03_classify_radius_and_segment_meters.sql`
5. `04_conflict_zone_suppression.sql`
6. `05_aggregate_to_way.sql`
7. (optional) `06_optional_update_osm_all_roads.sql`

### Notes

- This module is intentionally **not integrated** into `scripts/add_custom_tags.py` yet.
- Conflict points include:
  - tagged controls from `rs_conflict_nodes` (traffic signals, stop, give_way, crossings, etc.)
  - derived intersections: nodes appearing in **>=2 distinct ways**


