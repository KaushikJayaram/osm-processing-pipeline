# Simplified Persona Scoring - Phase 1 Implementation

## Overview

This is a simplified implementation of persona scoring that follows the "start simple, add complexity only where needed" philosophy. Phase 1 focuses on core factors and simple scoring without complex normalization or corridor bonuses.

## Files

1. **`01_compute_persona_base_scores_simplified.sql`** - Main SQL script that calculates persona scores
2. **`run_persona_scoring_simplified.py`** - Python script to run the SQL and get summary statistics
3. **`validate_simplified_scores.sql`** - Validation queries to check results
4. **`SIMPLIFIED_FRAMEWORK.md`** - Framework documentation

## Quick Start

### Run the Scoring Script

```bash
# From project root
./run_with_venv.sh osm-file-processing-v2 osm-file-processing-v2/iterative-runs/run_persona_scoring_simplified.py
```

Or directly:
```bash
cd osm-file-processing-v2
python iterative-runs/run_persona_scoring_simplified.py
```

### Validate Results

Run the validation queries:
```bash
psql -h localhost -U your_user -d your_db -f sql/road_persona/validate_simplified_scores.sql
```

## What It Does

### Phase 1 Features

1. **Simple Factor Scoring (0-1 range)**
   - Road Quality (MileMuncher): Highway type + lanes
   - Straightness (MileMuncher): Inverse of twistiness
   - Low Stress (all): Rural > SemiUrban > Urban
   - Twistiness (CornerCraver): Normalized twistiness_score
   - Surface Quality (CornerCraver): Paved > unpaved
   - Exploration (TrailBlazer): Inner roads > highways
   - Scenery (TrailBlazer, TranquilTraveller): Count of scenery flags
   - Moderate Roads (TranquilTraveller): MDR/SH/OH preferred

2. **Weighted Average Combination**
   - MileMuncher: 50% road quality + 30% straightness + 20% low stress
   - CornerCraver: 60% twistiness + 25% low stress + 15% surface quality
   - TrailBlazer: 40% exploration + 35% scenery + 25% low stress
   - TranquilTraveller: 45% scenery + 30% low stress + 25% moderate roads

3. **Direct Scaling to 0-100**
   - No percentile normalization
   - No top-end stretching
   - Simple multiplication: `raw_score * 100.0`

4. **No Corridor Bonus (Phase 1)**
   - `corridor_km` set to NULL
   - `final_score` = `base_score` (no bonus applied)

### Test Bbox

Currently configured for test region:
- **Bbox**: `ST_MakeEnvelope(76, 12, 78, 14, 4326)`
- **Area**: Karnataka region (includes Bangalore)
- **Coordinates**: 76-78° longitude, 12-14° latitude

## Output Columns

The script updates these columns in `osm_all_roads`:

- `persona_milemuncher_base_score` (0-100) - Only column used in Phase 1
- `persona_cornercraver_base_score` (0-100) - Only column used in Phase 1
- `persona_trailblazer_base_score` (0-100) - Only column used in Phase 1
- `persona_tranquiltraveller_base_score` (0-100) - Only column used in Phase 1

**Note:** Phase 1 uses only base_score columns. No corridor_km or final_score columns are created in the simplified framework.

## Validation

After running, check:

1. **Summary Statistics** - Are scores distributed reasonably?
2. **Top Roads** - Do high-scoring roads make sense for each persona?
3. **Road Type Distribution** - Do highway types score higher for MileMuncher?
4. **Setting Distribution** - Do rural roads score higher than urban?
5. **Zero Scores** - MileMuncher should only score highways (others = 0)

## Next Steps (Phase 2)

If Phase 1 results look good, consider adding:

1. **Corridor Bonus** - Simple linear bonus for long corridors
2. **Percentile Normalization** - If distribution is poor
3. **Weight Adjustments** - Based on visualization feedback
4. **Additional Factors** - Only if clearly needed

## Troubleshooting

### No scores calculated
- Check that test bbox intersects with roads
- Verify `bikable_road = TRUE` filter
- Check that required columns exist (road_type_i1, road_setting_i1, twistiness_score, etc.)

### All scores are 0
- Check that factors are being calculated correctly
- Verify road_type_i1 and road_setting_i1 have valid values
- Check twistiness_score is not NULL (for CornerCraver)

### Scores seem wrong
- Run validation queries to see distributions
- Check top-scoring roads to see if they make sense
- Verify factor calculations in the SQL script

## Logs

Logs are written to:
```
logs/persona_scoring_simplified_YYYYMMDD_HHMMSS.log
```

The script also prints summary statistics to console.

