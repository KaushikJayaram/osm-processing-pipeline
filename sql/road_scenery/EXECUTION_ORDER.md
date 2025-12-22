# Scenery Query Execution Order

## Overview

All scenery queries now use **Approach 4 (Hybrid)**: Feature-centric iteration with progressive filtering to avoid duplicate processing.

## Execution Order

### Step 1: Setup (Run Once)
```sql
-- 01_scenery_processing_add_columns.sql
-- Creates columns and indexes
```

### Step 2: Urban/Semiurban/Rural Classification (Run First)
```sql
-- 02_scenery_urban_and_semi_urban.sql
-- Assigns urban, semiurban, and rural based on road classification
```

### Step 3: Reset All Scenery Columns (REQUIRED Before Each Run)
```sql
-- 00_reset_all_scenery.sql
-- Resets all scenery columns to 0 for non-urban/non-semiurban roads
-- IMPORTANT: Must run this before executing scenery assignment queries
```

### Step 4: Assign Scenery Types (Can run in any order, or in parallel)

The following queries can be run in any order. Each query uses progressive filtering, so they can even be run in parallel if needed:

```sql
-- 03_scenery_forest.sql
-- 04_scenery_hill.sql
-- 05_scenery_lake.sql
-- 06_scenery_beach.sql
-- 07_scenery_river.sql
-- 08_scenery_desert.sql
-- 09_scenery_field.sql
-- 11_scenery_mountain_pass.sql
```

**Note:** `10_scenery_saltflat.sql` only resets the column (no assignment logic yet).

## Complete Execution Script

```sql
-- 1. Setup (one-time)
\i sql/road_scenery/01_scenery_processing_add_columns.sql

-- 2. Urban/Semiurban classification
\i sql/road_scenery/02_scenery_urban_and_semi_urban.sql

-- 3. Reset all scenery (REQUIRED before each scenery assignment run)
\i sql/road_scenery/00_reset_all_scenery.sql

-- 4. Assign scenery types (can run in parallel or sequentially)
\i sql/road_scenery/03_scenery_forest.sql
\i sql/road_scenery/04_scenery_hill.sql
\i sql/road_scenery/05_scenery_lake.sql
\i sql/road_scenery/06_scenery_beach.sql
\i sql/road_scenery/07_scenery_river.sql
\i sql/road_scenery/08_scenery_desert.sql
\i sql/road_scenery/09_scenery_field.sql
\i sql/road_scenery/11_scenery_mountain_pass.sql
```

## Approach 4 (Hybrid) Benefits

1. **Feature-centric iteration**: Iterates through features (lakes, rivers, etc.) instead of roads
   - With 285k lakes vs 4M roads, this is 14x fewer iterations

2. **Progressive filtering**: Excludes already-marked roads from further processing
   - Each road is processed exactly once
   - No duplicate work even if a road is near multiple features

3. **Efficient spatial indexing**: Uses GIST indexes on both tables for fast spatial lookups

## Performance Expectations

With proper indexes and your data size (285k lakes, 4M roads):
- **Each scenery query**: 5-15 minutes
- **Total for all scenery types**: 40-120 minutes (can be parallelized)

## Verification

After running all queries, verify results:

```sql
-- Check how many roads were marked for each scenery type
SELECT 
    COUNT(*) FILTER (WHERE road_scenery_forest = 1) as forest_roads,
    COUNT(*) FILTER (WHERE road_scenery_hill = 1) as hill_roads,
    COUNT(*) FILTER (WHERE road_scenery_lake = 1) as lake_roads,
    COUNT(*) FILTER (WHERE road_scenery_beach = 1) as beach_roads,
    COUNT(*) FILTER (WHERE road_scenery_river = 1) as river_roads,
    COUNT(*) FILTER (WHERE road_scenery_desert = 1) as desert_roads,
    COUNT(*) FILTER (WHERE road_scenery_field = 1) as field_roads,
    COUNT(*) FILTER (WHERE road_scenery_mountainpass = 1) as mountainpass_roads
FROM osm_all_roads
WHERE road_scenery_urban = 0 AND road_scenery_semiurban = 0;
```

## Troubleshooting

If queries are slow:
1. Verify indexes exist: `\d+ osm_all_roads` and check for GIST indexes
2. Update statistics: `ANALYZE osm_all_roads; ANALYZE rs_lakes;` etc.
3. Check query plan: `EXPLAIN ANALYZE <query>` - should show Index Scan, not Seq Scan
4. Consider uncommenting optional progressive filter indexes in `01_scenery_processing_add_columns.sql`

