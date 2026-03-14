# Four-Lane (fourlane) Classification Script

## Files Created
- `00_add_fourlane_column.sql` - SQL to add the column
- `fourlane_run.py` - Python script to populate the column

## Overview
This script classifies roads as four-lane ('yes' or 'no') based on a simple rule:
- **'yes'**: Road is one-way AND has 2 or more lanes
- **'no'**: All other cases

## Logic Explanation
The term "four-lane" in this context refers to roads that are:
1. One-way (unidirectional traffic)
2. Have at least 2 lanes

This means the equivalent bidirectional road would have 4+ lanes total (2+ lanes in each direction).

## Usage

### Step 1: Add the column (optional - script does this automatically)
```bash
source .env
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -p $DB_PORT \
  -f osm-processing-pipeline/scripts/dev-runs/00_add_fourlane_column.sql
```

### Step 2: Run the classification

```bash
# Test bbox (recommended first)
./run_with_venv.sh osm-processing-pipeline/scripts/dev-runs/fourlane_run.py --bbox test

# All India
./run_with_venv.sh osm-processing-pipeline/scripts/dev-runs/fourlane_run.py

# Custom bbox
./run_with_venv.sh osm-processing-pipeline/scripts/dev-runs/fourlane_run.py \
  --lat-min 12.0 --lat-max 15.0 --lon-min 75.0 --lon-max 79.0
```

## Environment Variables
- `FOURLANE_OSM_CHUNK_SIZE`: OSM ID chunk size (default: 50000)
- Standard database connection variables (DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT)

## Classification Logic (SQL)

The script checks two conditions:
1. **Is the road one-way?**
   - Checks `tags->>'oneway'` for values: 'YES', 'TRUE', '1', '-1'
   
2. **Does it have 2+ lanes?**
   - First tries `tags->>'lanes'` (extracts first integer)
   - Falls back to `lanes` column
   - Handles formats: "2", "2-1" (takes second value), etc.

```sql
fourlane = 
  CASE
    WHEN oneway = true AND lanes >= 2 THEN 'yes'
    ELSE 'no'
  END
```

## Output Statistics

After completion, the script logs:
- Total roads processed
- Count and percentage with `fourlane = 'yes'`
- Count with `fourlane = 'no'`
- Any NULL values (shouldn't occur)

## Logging

Logs are saved to `logs/fourlane_run_<timestamp>.log` with:
- Progress updates for each chunk
- Rows updated per chunk
- Final statistics

## Database Optimizations

- Chunks processing by OSM ID (default: 50,000 per chunk)
- Sets work_mem, maintenance_work_mem, temp_buffers
- Disables synchronous_commit during processing
- Disables autovacuum during processing (re-enabled at end)

## Examples

### Expected Results
- **Four-lane = 'yes'**: NH-44 one-way segment with 2+ lanes
- **Four-lane = 'no'**: 
  - Two-way roads (regardless of lanes)
  - One-way roads with only 1 lane
  - Residential streets
  - Any road without proper tagging
