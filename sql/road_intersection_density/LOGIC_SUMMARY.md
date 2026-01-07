# Intersection Density Logic Summary

## Overall Flow

### Step 1: Find and Score Intersections (`01_find_and_score_intersections.sql`)
1. **Find intersection nodes**: Nodes where 2+ roads meet
2. **Filter out way splits**: Only count as intersection if:
   - 3+ roads meet (definitely an intersection), OR
   - 2 roads meet with DIFFERENT road types, OR
   - 2 roads meet and at least one is a MID-NODE (crossing, not endpoint-to-endpoint)
3. **Score intersections** based on hierarchy combination of top 2 roads:
   - High-High (NH-NH, NH-SH, SH-SH): **1.0**
   - High-Mid (NH-MDR, SH-MDR, NH-OH, SH-OH): **0.7**
   - High-Low (NH-WoH, etc.): **0.4**
   - Mid-Mid (MDR-MDR, MDR-OH, OH-OH): **0.5**
   - Mid-Low (MDR-WoH, etc.): **0.3**
   - Low-Low (WoH-WoH, etc.): **0.2**

### Step 2: Aggregate Scores Per Way (`02_aggregate_scores_per_way.sql`)
For each road segment, sum up all intersection scores along it, with multipliers:

1. **Proportional sharing**: Divide intersection score by number of roads at intersection
   - Example: 3 roads meet at intersection with score 1.0 → each road gets 0.33
   - Prevents double-counting

2. **Road hierarchy multiplier** (based on the road itself):
   - NH: **1.5x**
   - SH: **1.3x**
   - MDR: **1.2x**
   - OH: **1.1x**
   - HAdj: **1.0x**
   - WoH: **0.9x**
   - Track: **0.8x**
   - Path: **0.7x**

3. **Urban/rural setting multiplier**:
   - Urban: **1.5x**
   - SemiUrban: **1.1x**
   - Rural: **1.0x**

**Result**: `total_intersection_score` per road segment

### Step 3: Calculate Density and Congestion Factor (`03_calculate_and_update_density.sql`)

1. **Raw density**: `total_intersection_score / length_km`

2. **Length adjustment**: Reduce effective density for short roads
   - <100m: multiply length by **1.5** (reduces density)
   - 100-500m: multiply length by **1.3**
   - 500m-1km: multiply length by **1.1**
   - >1km: no adjustment
   - **Adjusted density** = `total_intersection_score / (length_km * adjustment_factor)`

3. **Progressive capping**: Cap density based on length buckets
   - >1km: cap at **95th percentile**
   - 500m-1km: cap at **90th percentile**
   - 100-500m: cap at **85th percentile**
   - <100m: cap at **85th percentile**
   - **Capped density** = `LEAST(adjusted_density, cap_value)`

4. **Congestion factor** (0-1): Maps capped density to congestion level (for speed multiplier)
   - **1.0 = No congestion** (multiply speed by 1.0 = no penalty)
   - **0.5 = High congestion** (multiply speed by 0.5 = 50% penalty)
   - Mapping:
     - < 1: Factor = **1.0** (no congestion)
     - 1-2: Factor = **0.95** (slightly congested)
     - 2-3: Factor = **0.87** (low congestion)
     - > 3: Progressive decrease to **0.5** (high congestion)

## Key Points

1. **Higher hierarchy intersections = higher scores**: NH-NH intersection scores 1.0, WoH-WoH scores 0.2
2. **Higher hierarchy roads = higher multipliers**: NH road gets 1.5x multiplier, WoH gets 0.9x
3. **Urban roads = higher multipliers**: Urban gets 1.5x, Rural gets 1.0x
4. **Short roads get length adjustment**: Prevents extreme densities on very short segments
5. **Progressive capping**: Different caps for different length buckets prevent outliers
6. **Congestion factor for speed multiplier**: Higher density → lower factor (1.0 = no congestion, 0.5 = high congestion)

## Output Columns

- **`intersection_density_per_km`**: Capped density value (raw metric)
- **`intersection_congestion_factor`**: 0-1 congestion factor (1.0 = no congestion, 0.5 = high congestion) for speed multiplier

