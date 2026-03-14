# Persona V2 Parameter & Attribute Visualization Views

## Overview

This documentation describes the visualization views created for Persona V2 system, including parameter scores, persona scores, and key road attributes. These views are optimized for visualization in QGIS or other GIS tools at z10 zoom level.

## File

- **`vis_persona_v2_parameters_z10.sql`** - Creates all persona v2 related visualization views

## Views Created

### 1. Parameter Score Views (8 views)

These views display the individual parameter scores that feed into the persona scoring system:

| View Name | Column Visualized | Score Range | Description |
|-----------|-------------------|-------------|-------------|
| `vis.map_score_urban_gate_z10` | `score_urban_gate` | 0-1 | Urban connectivity and gateway access |
| `vis.map_score_cruise_road_z10` | `score_cruise_road` | 0-1 | High-speed cruising capability |
| `vis.map_score_offroad_z10` | `score_offroad` | 0-1 | Off-road and unpaved road capability |
| `vis.map_score_calm_road_z10` | `score_calm_road` | 0-1 | Low-traffic, peaceful road conditions |
| `vis.map_score_flow_z10` | `score_flow` | 0-1 | Road flow and continuity |
| `vis.map_score_remoteness_z10` | `score_remoteness` | 0-1 | Isolation from populated areas |
| `vis.map_score_twist_z10` | `score_twist` | 0-1 | Road curvature and twistiness |
| `vis.map_score_scenic_z10` | `score_scenic` | 0-1 | Scenic quality (forest, hills, lakes, etc.) |

**Score Classifications:**
- **Excellent**: >= 0.8
- **Good**: 0.6 - 0.8
- **Fair**: 0.4 - 0.6
- **Poor**: 0.2 - 0.4
- **Very Poor**: < 0.2

**Common Fields in Parameter Score Views:**
- `osm_id`: Road identifier
- `score_*`: Parameter score value (0-1)
- `score_class`: Text classification (Excellent/Good/Fair/Poor/Very Poor)
- `road_type_i1`: Road type classification
- `road_setting_i1`: Road setting (urban/rural/etc.)
- `road_classification_v2`: Road classification v2
- `length_km`: Road segment length in kilometers
- `ref`: Road reference number (e.g., NH48)
- `name`: Road name
- `geom`: Simplified geometry (0.0005 tolerance)

**Parameter-Specific Fields:**
- **urban_gate**: None
- **cruise_road**: `avg_speed_kph`, `fourlane`
- **offroad**: `surface`
- **calm_road**: `population_density`, `build_perc`
- **flow**: `avg_speed_kph`, `twistiness_score`
- **remoteness**: `population_density`, `build_perc`
- **twist**: `twistiness_score`
- **scenic**: `scenery_flags_count` (total scenic flags)

### 2. Persona Score Views V2 (4 views)

These views display the composite persona scores combining multiple parameters:

| View Name | Column Visualized | Description |
|-----------|-------------------|-------------|
| `vis.map_persona_milemuncher_v2_z10` | `persona_milemuncher_score` | Highway cruisers (urban_gate + cruise_road + flow) |
| `vis.map_persona_cornercraver_v2_z10` | `persona_cornercraver_score` | Twisty road enthusiasts (twist + flow + offroad) |
| `vis.map_persona_trailblazer_v2_z10` | `persona_trailblazer_score` | Adventure seekers (offroad + remoteness + scenic) |
| `vis.map_persona_tranquiltraveller_v2_z10` | `persona_tranquiltraveller_score` | Peaceful explorers (calm_road + remoteness + scenic) |

**Fields per Persona:**

**MileMuncher:**
- `persona_milemuncher_score`: Overall score (0-1)
- `score_urban_gate`, `score_cruise_road`, `score_flow`: Component scores
- `avg_speed_kph`, `fourlane`, `lanes_count`: Speed/capacity attributes
- Standard fields: osm_id, road_type_i1, road_setting_i1, road_classification_v2, length_km, ref, name, score_class, geom

**CornerCraver:**
- `persona_cornercraver_score`: Overall score (0-1)
- `score_twist`, `score_flow`, `score_offroad`: Component scores
- `twistiness_score`, `surface`: Curvature attributes
- Standard fields (same as above)

**TrailBlazer:**
- `persona_trailblazer_score`: Overall score (0-1)
- `score_offroad`, `score_remoteness`, `score_scenic`: Component scores
- `surface`, `scenery_flags_count`: Surface and scenery attributes
- Standard fields (same as above)

**TranquilTraveller:**
- `persona_tranquiltraveller_score`: Overall score (0-1)
- `score_calm_road`, `score_remoteness`, `score_scenic`: Component scores
- `population_density`, `build_perc`, `scenery_flags_count`: Calmness attributes
- Standard fields (same as above)

### 3. Road Attribute Views (5 views)

These views visualize key road attributes used in scoring:

| View Name | Column Visualized | Description |
|-----------|-------------------|-------------|
| `vis.map_fourlane_z10` | `fourlane` | Four-lane classification ('yes'/'no') |
| `vis.map_avg_speed_kph_z10` | `avg_speed_kph` | Average speed estimate (km/h) |
| `vis.map_road_type_i1_z10` | `road_type_i1` | Road type classification |
| `vis.map_road_setting_i1_z10` | `road_setting_i1` | Road setting (urban/rural) |
| `vis.map_road_classification_v2_z10` | `road_classification_v2` | Road classification v2 |

**Attribute-Specific Details:**

**Four Lane:**
- `fourlane`: 'yes' or 'no' classification
- `lanes_count`: Number of lanes (integer)
- `is_oneway`: Boolean indicating if road is one-way

**Average Speed:**
- `avg_speed_kph`: Speed estimate in km/h
- `speed_class`: Text classification:
  - Very High (80+)
  - High (60-80)
  - Medium (40-60)
  - Low (20-40)
  - Very Low (<20)
- `fourlane`, `lanes_count`, `twistiness_score`: Speed factors

**Road Type, Setting, Classification:**
- Primary field (road_type_i1, road_setting_i1, or road_classification_v2)
- Supporting fields: highway, population_density, build_perc
- Additional context: avg_speed_kph, fourlane (for classification v2)

## Usage

### 1. Creating the Views

Run the SQL script in pgAdmin or psql:

```sql
\i osm-processing-pipeline/sql/visualization/vis_persona_v2_parameters_z10.sql
```

Or execute the file contents directly in pgAdmin Query Tool.

### 2. Refreshing Views After Data Updates

After updating the underlying data (running persona v2 scoring, updating attributes, etc.), refresh the materialized views:

```sql
-- Refresh a specific view
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_score_urban_gate_z10;

-- Or refresh all persona v2 views
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_score_urban_gate_z10;
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_score_cruise_road_z10;
-- ... (repeat for all views)
```

**Note:** The `CONCURRENTLY` option allows queries to continue accessing the view while it's being refreshed, but requires unique indexes (which are created by the script).

### 3. Using in QGIS

1. **Connect to Database:**
   - Layer → Add Layer → Add PostGIS Layers
   - Create a new connection to your PostgreSQL database
   - Test connection

2. **Add View as Layer:**
   - Select your database connection
   - Click "Connect"
   - Schema dropdown → Select `vis`
   - Find the view you want (e.g., `map_score_urban_gate_z10`)
   - Select the view and click "Add"

3. **Styling by Score:**
   - Right-click layer → Properties → Symbology
   - Change from "Single Symbol" to "Graduated"
   - Column: Select the score column (e.g., `score_urban_gate`)
   - Color ramp: Choose a gradient (e.g., red to green)
   - Mode: Equal Interval or Quantile
   - Classes: 5 (matching score_class categories)
   - Click "Classify" then "Apply"

4. **Styling by Classification:**
   - Use "Categorized" symbology type
   - Column: `score_class` or `speed_class`
   - Click "Classify" to auto-generate categories
   - Customize colors for each category:
     - Excellent: Dark green
     - Good: Light green
     - Fair: Yellow
     - Poor: Orange
     - Very Poor: Red
     - No Data: Gray

### 4. Example Queries

**Find excellent urban gate roads:**
```sql
SELECT osm_id, road_type_i1, score_urban_gate, ref, name
FROM vis.map_score_urban_gate_z10
WHERE score_class = 'Excellent'
ORDER BY score_urban_gate DESC
LIMIT 20;
```

**Find high-speed four-lane roads:**
```sql
SELECT osm_id, avg_speed_kph, fourlane, road_classification_v2, ref, name
FROM vis.map_avg_speed_kph_z10
WHERE fourlane = 'yes' 
  AND avg_speed_kph >= 80
ORDER BY avg_speed_kph DESC;
```

**Compare persona scores for a specific road:**
```sql
SELECT 
    mm.osm_id,
    mm.name,
    mm.persona_milemuncher_score,
    cc.persona_cornercraver_score,
    tb.persona_trailblazer_score,
    tt.persona_tranquiltraveller_score
FROM vis.map_persona_milemuncher_v2_z10 mm
LEFT JOIN vis.map_persona_cornercraver_v2_z10 cc ON mm.osm_id = cc.osm_id
LEFT JOIN vis.map_persona_trailblazer_v2_z10 tb ON mm.osm_id = tb.osm_id
LEFT JOIN vis.map_persona_tranquiltraveller_v2_z10 tt ON mm.osm_id = tt.osm_id
WHERE mm.ref = 'NH 48'
ORDER BY mm.persona_milemuncher_score DESC;
```

**Find twisty, scenic roads with low traffic:**
```sql
SELECT t.osm_id, t.score_twist, s.score_scenic, c.score_calm_road, t.ref, t.name
FROM vis.map_score_twist_z10 t
JOIN vis.map_score_scenic_z10 s ON t.osm_id = s.osm_id
JOIN vis.map_score_calm_road_z10 c ON t.osm_id = c.osm_id
WHERE t.score_twist >= 0.7 
  AND s.score_scenic >= 0.7 
  AND c.score_calm_road >= 0.7
ORDER BY (t.score_twist + s.score_scenic + c.score_calm_road) DESC
LIMIT 50;
```

## Performance Considerations

### View Size
Each materialized view:
- Includes only `bikable_road = TRUE` roads
- Applies test bbox filter (76-78° lon, 12-14° lat) - **Remove for production**
- Uses geometry simplification (0.0005 tolerance)
- Filters to non-NULL score/attribute values

### Indexes
All views include indexes on:
- `geom`: Spatial index (GIST) for map rendering
- Score columns: B-tree indexes for filtering
- Classification columns: B-tree indexes for categorization

### Refresh Time
- Concurrent refresh allows queries during refresh
- Time depends on data volume and server resources
- Typically 1-5 minutes per view for Karnataka test data

## Test BBox Filter (IMPORTANT)

**Current:** Views filter to Karnataka test region (76-78° lon, 12-14° lat)

```sql
ST_Intersects(o.geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
```

**For All-India Production:** Remove this filter from all WHERE clauses in the SQL script.

## Dependencies

The visualization views depend on columns being present in `osm_all_roads`:

### Required Columns:
- **Base:** `osm_id`, `bikable_road`, `geometry`, `geom_ls`
- **Parameter Scores (8):** `score_urban_gate`, `score_cruise_road`, `score_offroad`, `score_calm_road`, `score_flow`, `score_remoteness`, `score_twist`, `score_scenic`
- **Persona Scores (4):** `persona_milemuncher_score`, `persona_cornercraver_score`, `persona_trailblazer_score`, `persona_tranquiltraveller_score`
- **Attributes:** `fourlane`, `avg_speed_kph`, `road_type_i1`, `road_setting_i1`, `road_classification_v2`

### Supporting Columns:
- `ref`, `name`, `highway`, `lanes`, `tags`, `twistiness_score`
- `population_density`, `build_perc`
- `road_scenery_*` flags (hill, lake, beach, river, forest, field)

**Note:** The script includes a verification step that checks for required columns before creating views.

## Related Files

- **`00_drop_all_vis_views.sql`**: Drops all visualization views (updated to include persona v2 views)
- **`vis_persona_scores_simplified_z10.sql`**: Simplified persona scores (base_score versions)
- **SQL Source Files:**
  - `../road_persona_v2/00_add_persona_v2_columns.sql`: Adds persona v2 columns
  - `../road_persona_v2/01_compute_parameter_scores.sql`: Computes parameter scores
  - `../road_persona_v2/02_compute_persona_scores.sql`: Computes persona scores
  
- **Python Scripts:**
  - `../../scripts/dev-runs/fourlane_run.py`: Computes fourlane attribute
  - `../../scripts/dev-runs/avg_speed_kph_run.py`: Computes avg_speed_kph attribute
  - `../../scripts/dev-runs/persona_v2_run.py`: Main persona v2 computation pipeline

## Troubleshooting

### Views not creating
- Check that required columns exist in `osm_all_roads`
- Verify that persona v2 scoring has been run
- Check for SQL syntax errors in pgAdmin

### Empty views
- Verify data exists in test bbox (76-78° lon, 12-14° lat)
- Check that `bikable_road = TRUE` for roads
- Ensure scores are not NULL

### Performance issues
- Ensure indexes are created (check script output)
- Use `EXPLAIN ANALYZE` to diagnose slow queries
- Consider increasing PostGIS work_mem for large datasets

### QGIS rendering slow
- Use z10 views (not z14) for initial exploration
- Filter by bbox in QGIS before styling
- Use "Graduated" symbology instead of "Rule-based" for better performance

## Future Enhancements

Potential additions:
- Additional zoom levels (z6 for overview, z14 for detailed analysis)
- Combined parameter views (e.g., all 8 scores in one view)
- Heatmap aggregations (grid-based score summaries)
- Time-series views (if scores change over time)
- Comparison views (persona v1 vs v2)
