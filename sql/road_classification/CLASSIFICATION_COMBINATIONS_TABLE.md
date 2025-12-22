# Road Classification Combinations - Reference Table

This table shows the **theoretically possible** combinations of classification values based on the SQL logic. To see **actual** combinations in your database, run `10_analyze_unique_classification_combinations.sql`.

## Classification Attributes

| Column Name | Description | Possible Values |
|------------|-------------|----------------|
| `final_road_classification_from_grid_overlap` | Grid-based classification | UrbanWoH, UrbanH, SemiUrbanWoH, SemiUrbanH, RuralWoH, RuralH, NULL |
| `road_setting_i1` | Road setting (derived from grid overlap) | Urban, SemiUrban, Rural, NULL |
| `road_type_i1` | Road type (derived from highway/ref) | NH, SH, MDR, OH, HAdj, Track, Path, WoH |
| `road_classification_i1` | Intermediate classification (derived) | UrbanNH, UrbanSH, UrbanMDR, UrbanOH, UrbanHAdj, UrbanTrack, UrbanPath, UrbanWoH, SemiUrbanNH, SemiUrbanSH, SemiUrbanMDR, SemiUrbanOH, SemiUrbanHAdj, SemiUrbanTrack, SemiUrbanPath, SemiUrbanWoH, RuralNH, RuralSH, RuralMDR, RuralOH, RuralHAdj, RuralTrack, RuralPath, RuralWoH, NULL |
| `road_classification` | Legacy v1 classification | NH, SH, Unknown, NULL |
| `road_classification_v2` | Refined v2 classification | Urban, NH, SH, Interior, Unknown, NULL |
| `final_mdr_status` | MDR status | mdr, maybe_mdr_primary, maybe_mdr_secondary, not_mdr, NULL |

## Expected Valid Combinations (High-level)

Based on the SQL logic, here are the **expected valid combinations**:

| final_road_classification_from_grid_overlap | road_setting_i1 | road_type_i1 | road_classification_i1 | Notes |
|--------------------------------------------|-----------------|-------------|------------------------|-------|
| UrbanH / UrbanWoH | Urban | * | Urban* | Setting is Urban; road type comes from highway/ref |
| SemiUrbanH / SemiUrbanWoH | SemiUrban | * | SemiUrban* | Setting is SemiUrban; road type comes from highway/ref |
| RuralH / RuralWoH | Rural | * | Rural* | Setting is Rural; road type comes from highway/ref |

Notes:
- `road_type_i1` is derived **purely** from `highway` + `ref` (including `_link` types).
- `road_classification_i1` is derived as `road_setting_i1 || road_type_i1`.

## Key Rules

1. **Setting vs type are separate**:
   - `road_setting_i1` comes from `final_road_classification_from_grid_overlap`
   - `road_type_i1` comes from `highway` + `ref`
   - `road_classification_i1 = road_setting_i1 || road_type_i1`

5. **MDR status**:
   - This is produced by `09_add_mdr.sql` (optional/extra). If you don’t run it, `final_mdr_status` will remain NULL/unchanged.

## To See Actual Combinations in Your Database

Run this query:

```sql
SELECT 
    final_road_classification_from_grid_overlap,
    road_classification_i1,
    road_classification,
    road_classification_v2,
    final_mdr_status,
    COUNT(*) as road_count
FROM osm_all_roads
WHERE bikable_road = TRUE
GROUP BY 
    final_road_classification_from_grid_overlap,
    road_classification_i1,
    road_classification,
    road_classification_v2,
    final_mdr_status
ORDER BY road_count DESC;
```

Or use the provided SQL file: `10_analyze_unique_classification_combinations.sql`

