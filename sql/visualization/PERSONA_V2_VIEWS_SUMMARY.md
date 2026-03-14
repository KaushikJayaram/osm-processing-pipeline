# Persona V2 Visualization Views - Quick Summary

## What Was Created

✅ **1 SQL Script**: `vis_persona_v2_parameters_z10.sql`
✅ **17 Materialized Views** at z10 zoom level
✅ **Complete Documentation**: `README_PERSONA_V2_VIEWS.md`
✅ **Updated Drop Script**: `00_drop_all_vis_views.sql`

---

## 17 Views Created

### 📊 Parameter Score Views (8)
Visualizes individual parameter scores (0-1 scale):

1. `vis.map_score_urban_gate_z10` - Urban connectivity
2. `vis.map_score_cruise_road_z10` - High-speed cruising
3. `vis.map_score_offroad_z10` - Off-road capability
4. `vis.map_score_calm_road_z10` - Low-traffic conditions
5. `vis.map_score_flow_z10` - Road flow/continuity
6. `vis.map_score_remoteness_z10` - Isolation level
7. `vis.map_score_twist_z10` - Curvature/twistiness
8. `vis.map_score_scenic_z10` - Scenic quality

### 🎭 Persona Score Views (4)
Visualizes composite persona scores (0-1 scale):

9. `vis.map_persona_milemuncher_v2_z10` - Highway cruisers
10. `vis.map_persona_cornercraver_v2_z10` - Twisty road enthusiasts
11. `vis.map_persona_trailblazer_v2_z10` - Adventure seekers
12. `vis.map_persona_tranquiltraveller_v2_z10` - Peaceful explorers

### 🛣️ Road Attribute Views (5)
Visualizes key road attributes:

13. `vis.map_fourlane_z10` - Four-lane classification
14. `vis.map_avg_speed_kph_z10` - Average speed estimates
15. `vis.map_road_type_i1_z10` - Road type classification
16. `vis.map_road_setting_i1_z10` - Road setting (urban/rural)
17. `vis.map_road_classification_v2_z10` - Road classification v2

---

## Quick Start

### 1. Create Views
```bash
# In psql
\i osm-processing-pipeline/sql/visualization/vis_persona_v2_parameters_z10.sql
```

Or run in pgAdmin Query Tool.

### 2. Use in QGIS
1. Connect to PostgreSQL database
2. Add PostGIS layer
3. Schema: `vis`
4. Table: Select any `map_*_z10` view
5. Style by score or classification column

### 3. Refresh After Data Updates
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY vis.map_score_urban_gate_z10;
-- Repeat for each view
```

---

## View Structure

All views include:
- ✅ **Score/Attribute Column**: The primary value being visualized
- ✅ **Score Classification**: Text categories (Excellent/Good/Fair/Poor/Very Poor)
- ✅ **Road Context**: road_type_i1, road_setting_i1, road_classification_v2
- ✅ **Identification**: osm_id, ref, name
- ✅ **Metrics**: length_km
- ✅ **Geometry**: Simplified to 0.0005 tolerance (z10)
- ✅ **Indexes**: Spatial (GIST) and attribute (B-tree) indexes

---

## Score Classifications

### Parameter & Persona Scores (0-1 scale)
- **Excellent**: ≥ 0.8
- **Good**: 0.6 - 0.8
- **Fair**: 0.4 - 0.6
- **Poor**: 0.2 - 0.4
- **Very Poor**: < 0.2

### Average Speed (km/h)
- **Very High**: ≥ 80 km/h
- **High**: 60-80 km/h
- **Medium**: 40-60 km/h
- **Low**: 20-40 km/h
- **Very Low**: < 20 km/h

---

## Important Notes

### ⚠️ Test BBox Filter
Currently filters to **Karnataka test region** (76-78° lon, 12-14° lat).

**For production/all-India**: Remove this line from all view definitions:
```sql
AND ST_Intersects(o.geometry, ST_MakeEnvelope(76, 12, 78, 14, 4326))
```

### 📋 Dependencies
Views require these columns in `osm_all_roads`:
- **Parameter scores** (8): score_urban_gate, score_cruise_road, etc.
- **Persona scores** (4): persona_milemuncher_score, etc.
- **Attributes** (5): fourlane, avg_speed_kph, road_type_i1, road_setting_i1, road_classification_v2

Run scoring scripts first:
- `persona_v2_run.py` - Computes parameter & persona scores
- `fourlane_run.py` - Computes fourlane attribute
- `avg_speed_kph_run.py` - Computes avg_speed_kph attribute

---

## Files Created

```
osm-processing-pipeline/sql/visualization/
├── vis_persona_v2_parameters_z10.sql        (NEW - 650+ lines)
├── README_PERSONA_V2_VIEWS.md               (NEW - Complete docs)
├── PERSONA_V2_VIEWS_SUMMARY.md              (NEW - This file)
└── 00_drop_all_vis_views.sql                (UPDATED - Added 17 drops)
```

---

## Example Use Cases

### 🔍 Find Excellent Roads for Each Persona
```sql
-- Best MileMuncher roads
SELECT osm_id, ref, name, persona_milemuncher_score
FROM vis.map_persona_milemuncher_v2_z10
WHERE score_class = 'Excellent'
ORDER BY persona_milemuncher_score DESC;

-- Best CornerCraver roads
SELECT osm_id, ref, name, persona_cornercraver_score
FROM vis.map_persona_cornercraver_v2_z10
WHERE score_class = 'Excellent'
ORDER BY persona_cornercraver_score DESC;
```

### 🗺️ Compare Parameters
```sql
-- Find roads with high twist AND scenic scores
SELECT t.osm_id, t.ref, t.name, t.score_twist, s.score_scenic
FROM vis.map_score_twist_z10 t
JOIN vis.map_score_scenic_z10 s ON t.osm_id = s.osm_id
WHERE t.score_twist >= 0.7 AND s.score_scenic >= 0.7;
```

### 🚗 Analyze Speed & Capacity
```sql
-- High-speed four-lane roads
SELECT osm_id, ref, avg_speed_kph, fourlane, road_classification_v2
FROM vis.map_avg_speed_kph_z10
WHERE fourlane = 'yes' AND avg_speed_kph >= 80;
```

---

## QGIS Styling Tips

### Graduated Colors (for scores)
- **Column**: score_* or persona_*_score
- **Mode**: Equal Interval or Quantile
- **Classes**: 5
- **Color Ramp**: Red to Green (or reverse)

### Categorized (for classifications)
- **Column**: score_class or speed_class
- **Colors**:
  - Excellent: `#006400` (Dark Green)
  - Good: `#90EE90` (Light Green)
  - Fair: `#FFFF00` (Yellow)
  - Poor: `#FFA500` (Orange)
  - Very Poor: `#FF0000` (Red)
  - No Data: `#808080` (Gray)

---

## Performance

- ⚡ **Indexes**: All views have spatial (GIST) and attribute indexes
- 🔄 **Concurrent Refresh**: Use `REFRESH MATERIALIZED VIEW CONCURRENTLY`
- 📏 **Simplified Geometry**: 0.0005 tolerance reduces size
- 🎯 **Filtered Data**: Only bikable roads with non-NULL values
- 🗺️ **Test Bbox**: Currently limited to Karnataka region

---

## Next Steps

1. ✅ **Verify Dependencies**: Ensure scoring scripts have been run
2. ✅ **Create Views**: Run `vis_persona_v2_parameters_z10.sql`
3. ✅ **Test in QGIS**: Load a few views and verify rendering
4. ✅ **Refresh Policy**: Decide when to refresh (after each scoring run)
5. ✅ **Production**: Remove test bbox filter for all-India coverage

---

## Questions?

See full documentation in `README_PERSONA_V2_VIEWS.md` for:
- Detailed field descriptions
- Advanced SQL queries
- Troubleshooting guide
- QGIS workflow examples
- Performance optimization tips
