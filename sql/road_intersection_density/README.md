# Road Intersection Density & Speed Degradation

This module contains two approaches for handling intersections:

## Approach 1: Intersection Density (Legacy)
Calculates intersection density for all bikable roads and stores:
- **Raw density** in `intersection_density_per_km` (with length adjustment and progressive capping)
- **Congestion factor** in `intersection_congestion_factor` (0-1 for GraphHopper custom models)

**Status:** Legacy approach - replaced by Intersection Speed Degradation (v2)

## Approach 2: Intersection Speed Degradation (v2) ✅ CURRENT
**Status:** ✅ **Complete & Finalized** - Implemented and written to PBF

Calculates intersection speed degradation using a new methodology:
- Categorizes intersections as Major/Middling/Minor based on road type sets
- Uses distance-based impact with weighted average or multiplicative stacking
- Applies setting multipliers (Urban/SemiUrban/Rural) and lanes+oneway factor
- Stores values in `intersection_speed_degradation_base`, `intersection_speed_degradation_setting_adjusted`, `intersection_speed_degradation_final`

**Key Feature:** `intersection_speed_degradation_final` is stored as a **MULTIPLIER (0.5-1.0)** for direct use in GraphHopper `multiply_by` operations.

**Documentation:** See `DETAILED_EXPLANATION_WITH_EXAMPLES.md` for complete methodology.

**Run Script:** `iterative-runs/run_intersection_speed_degradation_v2_and_pbf.py`

---

## Legacy Approach (v1) - Archived

**Status:** Legacy v1 files have been moved to `legacy-code/` directory for reference only.

**Legacy Files (archived):**
- `legacy-code/00_schema_intersection_v1.sql`
- `legacy-code/01_find_and_score_intersections_v1.sql`
- `legacy-code/02_aggregate_scores_per_way_v1.sql`
- `legacy-code/03_calculate_and_update_density_v1.sql`

**Note:** Legacy v1 implementation is no longer used. See `legacy-code/README.md` for details.

---

## Legacy Approach Details (for reference)

## Overview

Intersection density is calculated as:
- **Raw density** = `total_intersection_score / adjusted_length_km`
- Where `total_intersection_score` is the sum of weighted intersection scores for all intersections along a road
- Intersection scores are weighted by:
  - Road hierarchy (NH-NH = 1.0, NH-MDR = 0.7, WoH-WoH = 0.2, etc.)
  - Road's own hierarchy multiplier (NH=1.5, SH=1.3, MDR=1.2, etc.)
  - Urban/rural setting multiplier (Urban=1.5, SemiUrban=1.1, Rural=1.0)
- Length adjustment factor reduces impact of very short roads
- Progressive capping prevents extreme values based on length buckets
- Congestion factor (0-1) maps adjusted and capped density for GraphHopper

## Execution Order

The SQL files must be executed in order:

1. **`00_schema.sql`** - Creates temporary tables for intermediate results
2. **`01_find_and_score_intersections.sql`** - Finds intersection nodes and scores them based on road hierarchy
3. **`02_aggregate_scores_per_way.sql`** - Aggregates intersection scores per way
4. **`03_calculate_and_update_density.sql`** - Calculates density and updates `intersection_density_per_km` column

## Road Hierarchy Scoring

Intersections are scored based on the two highest hierarchy road types meeting at the intersection:

| Combination | Score | Example |
|------------|-------|---------|
| High-High | 1.0 | NH-NH, NH-SH, SH-SH |
| High-Mid | 0.7 | NH-MDR, SH-MDR, NH-OH, SH-OH |
| High-Low | 0.4 | NH-WoH, SH-WoH |
| Mid-Mid | 0.5 | MDR-MDR, MDR-OH, OH-OH |
| Mid-Low | 0.3 | MDR-WoH, OH-WoH |
| Low-Low | 0.2 | WoH-WoH, Track-Track |

**Road Hierarchy Values:**
- NH = 8
- SH = 7
- MDR = 6
- OH = 5
- HAdj = 4
- WoH = 3
- Track = 2
- Path = 1

## Length Calculation

Uses `ST_Length(geometry::geography)` for length calculation, which:
- Gives accurate results in meters (geography casting)
- Is the same method used in persona SQL files
- Avoids PostGIS library loading issues

## Length Adjustment and Capping

To address the impact of very short roads:
- **Length Adjustment Factor**: Applied to reduce effective density for short roads
  - <100m: multiply length by 1.5
  - 100-500m: multiply length by 1.3
  - 500m-1km: multiply length by 1.1
  - >1km: no adjustment
- **Progressive Capping**: Different caps based on length buckets
  - >1km: cap at 95th percentile
  - 500m-1km: cap at 90th percentile
  - 100-500m: cap at 85th percentile
  - <100m: cap at 85th percentile

## Congestion Factor

The `intersection_congestion_factor` (0-1) is calculated from the adjusted and capped density:
- **1.0 = No congestion** (multiply speed by 1.0 = no penalty)
- **0.5 = High congestion** (multiply speed by 0.5 = 50% penalty)
- **< 1**: Factor = 1.0 (no congestion)
- **1-2**: Factor = 0.95 (slightly congested)
- **2-3**: Factor = 0.87 (low congestion)
- **> 3**: Progressive decrease to 0.5 (high congestion)

## Output

The calculation populates two columns in `osm_all_roads`:
- **`intersection_density_per_km`**: Adjusted and capped density value
- **`intersection_congestion_factor`**: 0-1 congestion factor for GraphHopper (1.0 = no congestion, 0.5 = high congestion)
- **0.0** / **1.0** for roads with no intersections
- **NULL** values are set to 0.0 / 1.0

**Note:** The simplified persona scoring framework (Phase 1) does not currently use intersection density as a factor. If needed in the future, intersection density can be integrated into persona scoring formulas. See `sql/road_persona/SIMPLIFIED_FRAMEWORK.md` for current persona scoring approach.

## Usage

Run via Python:
```python
from scripts.add_custom_tags import compute_intersection_density_only
compute_intersection_density_only(db_config)
```

Or run SQL files directly:
```bash
psql -d your_db -f sql/road_intersection_density/00_schema.sql
psql -d your_db -f sql/road_intersection_density/01_find_and_score_intersections.sql
psql -d your_db -f sql/road_intersection_density/02_aggregate_scores_per_way.sql
psql -d your_db -f sql/road_intersection_density/03_calculate_and_update_density.sql
```

## Performance

- Processes all intersection nodes in a single pass
- Uses temporary tables for efficient aggregation
- No batch processing needed - PostgreSQL handles optimization
- Typically completes in 5-15 minutes depending on database size

