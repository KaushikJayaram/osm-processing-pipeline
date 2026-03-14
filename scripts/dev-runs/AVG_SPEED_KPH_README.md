# Average Speed (avg_speed_kph) Calculation Script

## File Created
`osm-processing-pipeline/scripts/dev-runs/avg_speed_kph_run.py`

## Overview
This script computes the `avg_speed_kph` column for all roads in `osm_all_roads` using a chunked processing approach by OSM ID.

## Usage

### Basic usage (all India):
```bash
python3 osm-processing-pipeline/scripts/dev-runs/avg_speed_kph_run.py
```

### Test bbox:
```bash
python3 osm-processing-pipeline/scripts/dev-runs/avg_speed_kph_run.py --bbox test
```

### Custom bbox:
```bash
python3 osm-processing-pipeline/scripts/dev-runs/avg_speed_kph_run.py \
  --lat-min 12.0 --lat-max 15.0 \
  --lon-min 75.0 --lon-max 79.0
```

## Environment Variables
- `AVG_SPEED_OSM_CHUNK_SIZE`: OSM ID chunk size (default: 50000)
- Standard database connection variables (DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT)

## Formula
Base speed = 100 kph, multiplied by:

1. **Lanes + Oneway Factor**
   - Oneway roads with >1 lane: 1.0
   - Oneway roads with ≤1 lane: 0.9
   - Two-way roads with >1 lane: 0.9
   - Two-way roads with ≤1 lane: 0.8

2. **Road Type × Road Setting Multipliers**
   - See table in script for all combinations
   - Examples:
     - Rural NH: 0.9
     - SemiUrban NH: 0.8
     - Urban NH: 0.6
     - Rural/SemiUrban WOH/Res: 0.25
     - Urban WOH/Res: 0.4

3. **Intersection Speed Degradation**
   - Uses `intersection_speed_degradation_final` (multiplier format, 0.5-1.0)
   - Only applied if < 1.0

4. **Curvature Factor**
   - Uses `twistiness_score` (v2 curvature, higher = more twisty)
   - 0.0-0.08: no penalty (1.0)
   - 0.08-0.20: scaled penalty from 1.0 down to 0.6
   - ≥ 0.20: maximum penalty (0.6)

## IMPORTANT NOTES

### Curvature Metric Used
This script uses **`twistiness_score`** from the v2 curvature module:
- **Higher values = more twisty/curved roads**
- Based on the roadcurvature.com methodology
- NULL values are treated as 0 (straight, no penalty)
- Penalty scale:
  - 0.00-0.08: No penalty (multiplier = 1.0)
  - 0.08-0.20: Linear scaling from 1.0 to 0.6
  - 0.20+: Maximum penalty (multiplier = 0.6)

**Note:** The legacy `road_curvature_ratio` column (0-1 where 1=straight) is no longer used. If your database doesn't have `twistiness_score` populated, you'll need to run the curvature v2 processing first.

### Variable Name Verification
All column names used match the existing schema:
- ✅ `road_setting_i1` (values: 'Rural', 'SemiUrban', 'Urban')
- ✅ `road_type_i1` (values: 'NH', 'SH', 'MDR', 'OH', 'HADJ', 'TRACK', 'WOH', 'Res')
- ✅ `intersection_speed_degradation_final`
- ✅ `lanes` (TEXT column)
- ✅ `tags` (JSONB column with 'lanes' and 'oneway' keys)
- ✅ `twistiness_score` (v2 curvature metric, higher = more twisty)

### Road Type/Setting Values
The script uses CamelCase for `road_setting_i1` comparison ('Rural', 'SemiUrban', 'Urban') to match the database schema. Road types include special cases:
- 'WOH' (Without Highway classification)
- 'Res' (Residential)
- Both treated identically in the formula

## Logging
Logs are saved to `logs/avg_speed_kph_run_<timestamp>.log` with:
- Progress updates for each chunk
- Rows updated per chunk
- Final statistics (avg, median, p90, min, max speeds)

## Database Optimizations
- Sets work_mem, maintenance_work_mem, temp_buffers
- Disables synchronous_commit during processing
- Disables autovacuum during processing (re-enabled at end)
