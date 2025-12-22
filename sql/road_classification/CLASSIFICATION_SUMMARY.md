# Road Classification System Summary

This document explains all the road classification attributes added to the `osm_all_roads` table and their possible values.

## Classification Attributes Overview

The road classification system uses a hierarchical approach with multiple levels of classification:

### 1. `final_road_classification_from_grid_overlap`
**Description**: Final classification based on grid overlap analysis. Determines whether a road passes through Urban, Semi-Urban, or Rural areas, and whether it intersects with NH/SH roads.

**Possible Values**:
- `UrbanWoH` - Urban area without NH/SH roads
- `UrbanH` - Urban area with NH/SH roads
- `SemiUrbanWoH` - Semi-Urban area without NH/SH roads
- `SemiUrbanH` - Semi-Urban area with NH/SH roads
- `RuralWoH` - Rural area without NH/SH roads
- `RuralH` - Rural area with NH/SH roads
- `NULL` - Roads that don't intersect with any grids or are not bikable

**Source**: Derived from `grid_classification_l2` values in `india_grids` table

---

### 2. `road_classification_i1`
**Description**: Intermediate classification (v2) combining:
- **Road setting** (Urban/SemiUrban/Rural) derived from `final_road_classification_from_grid_overlap`, and
- **Road type** (NH/SH/MDR/OH/HAdj/WoH) derived purely from `highway` + `ref`.

This is intentionally split to avoid conflating grid context (`*H`/`*WoH`) with road type. In particular, roads in `RuralWoH` grids can still be `primary/secondary/...` and should not be forced into a “WoH” road type.

**Supporting Columns**:
- `road_setting_i1`: `Urban`, `SemiUrban`, `Rural` (derived from `final_road_classification_from_grid_overlap`)
- `road_type_i1`: `NH`, `SH`, `MDR`, `OH`, `HAdj`, `Track`, `Path`, `WoH` (derived from `highway` + `ref`)

**Derived Rule**:
- `road_classification_i1 = road_setting_i1 || road_type_i1` (e.g., `Rural` + `SH` → `RuralSH`)

**Possible Values (examples)**:
- `UrbanNH`, `UrbanSH`, `UrbanMDR`, `UrbanOH`, `UrbanHAdj`, `UrbanTrack`, `UrbanPath`, `UrbanWoH`
- `SemiUrbanNH`, `SemiUrbanSH`, `SemiUrbanMDR`, `SemiUrbanOH`, `SemiUrbanHAdj`, `SemiUrbanTrack`, `SemiUrbanPath`, `SemiUrbanWoH`
- `RuralNH`, `RuralSH`, `RuralMDR`, `RuralOH`, `RuralHAdj`, `RuralTrack`, `RuralPath`, `RuralWoH`

---

### 3. `road_classification`
**Description**: Legacy classification (v1) - simplified version for backward compatibility.

**Possible Values**:
- `NH` - National Highway (from `road_classification_i1` = 'NH' or 'NHorSH')
- `SH` - State Highway (from `road_classification_i1` = 'SH')
- `Unknown` - Other roads (from `road_classification_i1` = 'NHSHAdjacent' or 'Interior')
- `NULL` - Urban roads or unclassified roads

**Mapping Logic**:
- `road_classification_i1` IN ('NH', 'NHorSH') → `NH`
- `road_classification_i1` = 'SH' → `SH`
- `road_classification_i1` IN ('NHSHAdjacent', 'Interior') → `Unknown`

---

### 4. `road_classification_v2`
**Description**: Refined classification (version 2) - more detailed than v1.

**Possible Values**:
- `Urban` - Urban roads (from `road_classification_i1` = 'UrbanH' or 'UrbanWoH')
- `NH` - National Highway (from `road_classification_i1` IN ('NH', 'NHorSH', 'NHSHAdjacent'))
- `SH` - State Highway (from `road_classification_i1` = 'SH')
- `Interior` - Interior roads (from `road_classification_i1` = 'Interior')
- `Unknown` - Unclassified roads
- `NULL` - Roads not processed

**Mapping Logic**:
- `road_classification_i1` IN ('UrbanH', 'UrbanWoH') → `Urban`
- `road_classification_i1` IN ('NH', 'NHorSH', 'NHSHAdjacent') → `NH`
- `road_classification_i1` = 'SH' → `SH`
- `road_classification_i1` = 'Interior' → `Interior`
- Otherwise → `Unknown`

---

### 5. `final_mdr_status`
**Description**: Major District Road (MDR) classification status.

**Possible Values**:
- `mdr` - Confirmed MDR (has MDR in ref field)
- `maybe_mdr_primary` - Possibly MDR (primary highway type, Interior classification, in SemiUrban/Rural)
- `maybe_mdr_secondary` - Possibly MDR (secondary highway type, Interior classification, in SemiUrban/Rural)
- `not_mdr` - Not an MDR
- `NULL` - Not processed

**Mapping Logic**:
- `ref` ILIKE '%MDR%' → `mdr`
- `highway = 'primary'` AND `road_classification_i1 = 'Interior'` AND in SemiUrban/Rural → `maybe_mdr_primary`
- `highway = 'secondary'` AND `road_classification_i1 = 'Interior'` AND in SemiUrban/Rural → `maybe_mdr_secondary`
- Otherwise → `not_mdr`

---

## Classification Flow

```
Grid Analysis
    ↓
grid_classification_l1 (Urban/Semi-Urban/Rural)
    ↓
grid_classification_l2 (Urban_H/Urban_WoH/SemiUrban_H/etc.)
    ↓
final_road_classification_from_grid_overlap
    ↓
road_setting_i1 + road_type_i1
    ↓
road_classification_i1 (Intermediate classification, derived)
    ↓
road_classification (v1 - Legacy) + road_classification_v2 (v2 - Refined)
    ↓
final_mdr_status (MDR classification)
```

## Query to See Unique Combinations

Run the SQL file `10_analyze_unique_classification_combinations.sql` to see:
- All unique combinations of classification values
- Count of roads for each combination
- Total number of unique combinations

## Notes

- All classifications only apply to **bikable roads** (`bikable_road = TRUE`)
- Bikable roads include: motorway, trunk, primary, secondary, tertiary, residential, unclassified, service, track, path, living_street, and their link variants
- Roads that don't intersect with any grids will have `NULL` values for grid-based classifications
- The classification system prioritizes Urban roads, then NH/SH roads, then other classifications

