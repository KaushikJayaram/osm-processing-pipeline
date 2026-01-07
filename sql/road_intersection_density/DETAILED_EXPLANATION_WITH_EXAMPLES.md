# Intersection Density Calculation - Detailed Explanation with Examples

## Overview

The intersection density calculation has 3 main steps:
1. **Find and Score Intersections**: Identify real intersections and assign base scores
2. **Aggregate Scores Per Way**: Sum intersection scores for each road segment with multipliers
3. **Calculate Density and Congestion Factor**: Apply length adjustments, capping, and map to congestion factor

---

## Step 1: Find and Score Intersections

### Logic

**Goal**: Find nodes where roads actually intersect (not just way splits)

**Filtering Rules** (to exclude way splits):
- ✅ **3+ roads meet** → Definitely an intersection
- ✅ **2 roads meet with DIFFERENT road types** → True intersection
- ✅ **2 roads meet and at least one is a MID-NODE** → Crossing (not endpoint-to-endpoint)

**Scoring**: Based on the **two highest hierarchy** road types meeting at the intersection

### Hierarchy Values
- NH = 8
- SH = 7
- MDR = 6
- OH = 5
- HAdj = 4
- WoH = 3
- Track = 2
- Path = 1

### Scoring Matrix

| Combination | Example | Score |
|------------|---------|-------|
| High-High | NH-NH, NH-SH, SH-SH | 1.0 |
| High-Mid | NH-MDR, SH-MDR, NH-OH, SH-OH | 0.7 |
| High-Low | NH-WoH, SH-WoH | 0.4 |
| Mid-Mid | MDR-MDR, MDR-OH, OH-OH | 0.5 |
| Mid-Low | MDR-WoH, OH-WoH | 0.3 |
| Low-Low | WoH-WoH, Track-Track | 0.2 |

### Example 1: Simple Intersection

**Scenario**: 3 roads meet at a node
- Road A: NH (hierarchy 8)
- Road B: SH (hierarchy 7)
- Road C: WoH (hierarchy 3)

**Top 2 hierarchies**: 8 (NH) and 7 (SH)
**Combination**: High-High
**Intersection Score**: **1.0**

### Example 2: Mixed Hierarchy Intersection

**Scenario**: 2 roads meet at a node
- Road A: NH (hierarchy 8)
- Road B: MDR (hierarchy 6)

**Top 2 hierarchies**: 8 (NH) and 6 (MDR)
**Combination**: High-Mid
**Intersection Score**: **0.7**

### Example 3: Low Hierarchy Intersection

**Scenario**: 2 roads meet at a node
- Road A: WoH (hierarchy 3)
- Road B: WoH (hierarchy 3)

**Top 2 hierarchies**: 3 (WoH) and 3 (WoH)
**Combination**: Low-Low
**Intersection Score**: **0.2**

---

## Step 2: Aggregate Scores Per Way

### Logic

For each road segment, sum up all intersection scores along it, but:
1. **Divide by number of roads** at each intersection (proportional sharing)
2. **Multiply by road hierarchy multiplier** (based on the road itself)
3. **Multiply by urban/rural setting multiplier**

### Road Hierarchy Multipliers

| Road Type | Multiplier |
|-----------|------------|
| NH | 1.5x |
| SH | 1.3x |
| MDR | 1.2x |
| OH | 1.1x |
| HAdj | 1.0x |
| WoH | 0.9x |
| Track | 0.8x |
| Path | 0.7x |

### Urban/Rural Setting Multipliers

| Setting | Multiplier |
|---------|------------|
| Urban | 1.5x |
| SemiUrban | 1.1x |
| Rural | 1.0x |

### Formula

```
total_intersection_score = Σ(
    (intersection_score / road_count_at_intersection) 
    × road_hierarchy_multiplier 
    × setting_multiplier
)
```

### Example 4: Single Intersection on NH Road

**Scenario**: 
- Road: NH, Urban setting, 2 km long
- Has 1 intersection: NH-NH intersection (score 1.0)
- 3 roads meet at this intersection

**Calculation**:
1. Base intersection score: 1.0
2. Proportional sharing: 1.0 / 3 = **0.333**
3. Road hierarchy multiplier: NH = **1.5x**
4. Setting multiplier: Urban = **1.5x**
5. **Total intersection score**: 0.333 × 1.5 × 1.5 = **0.75**

### Example 5: Multiple Intersections on SH Road

**Scenario**:
- Road: SH, SemiUrban setting, 5 km long
- Has 3 intersections:
  - Intersection 1: SH-MDR (score 0.7), 2 roads meet
  - Intersection 2: SH-WoH (score 0.4), 2 roads meet
  - Intersection 3: SH-SH (score 1.0), 4 roads meet

**Calculation**:
1. **Intersection 1**:
   - Base score: 0.7
   - Proportional: 0.7 / 2 = 0.35
   - Road multiplier: SH = 1.3x
   - Setting multiplier: SemiUrban = 1.1x
   - Contribution: 0.35 × 1.3 × 1.1 = **0.50**

2. **Intersection 2**:
   - Base score: 0.4
   - Proportional: 0.4 / 2 = 0.2
   - Road multiplier: SH = 1.3x
   - Setting multiplier: SemiUrban = 1.1x
   - Contribution: 0.2 × 1.3 × 1.1 = **0.29**

3. **Intersection 3**:
   - Base score: 1.0
   - Proportional: 1.0 / 4 = 0.25
   - Road multiplier: SH = 1.3x
   - Setting multiplier: SemiUrban = 1.1x
   - Contribution: 0.25 × 1.3 × 1.1 = **0.36**

4. **Total intersection score**: 0.50 + 0.29 + 0.36 = **1.15**

### Example 6: WoH Road with Low Hierarchy Intersection

**Scenario**:
- Road: WoH, Rural setting, 1 km long
- Has 1 intersection: WoH-WoH (score 0.2), 2 roads meet

**Calculation**:
1. Base intersection score: 0.2
2. Proportional sharing: 0.2 / 2 = **0.1**
3. Road hierarchy multiplier: WoH = **0.9x**
4. Setting multiplier: Rural = **1.0x**
5. **Total intersection score**: 0.1 × 0.9 × 1.0 = **0.09**

---

## Step 3: Calculate Density and Congestion Factor

### Logic

1. **Raw Density**: `total_intersection_score / length_km`
2. **Length Adjustment**: Multiply length by adjustment factor (reduces density for short roads)
3. **Adjusted Density**: `total_intersection_score / (length_km × adjustment_factor)`
4. **Progressive Capping**: Cap density based on length bucket
5. **Congestion Factor**: Map capped density to 0-1 factor (for speed multiplier)

### Length Adjustment Factors

| Length | Adjustment Factor | Effective Length Multiplier |
|---------|-------------------|----------------------------|
| < 100m | 1.5x | 150m, 200m, etc. |
| 100-500m | 1.3x | 130m, 260m, etc. |
| 500m-1km | 1.1x | 550m, 880m, etc. |
| > 1km | 1.0x | No adjustment |

### Progressive Capping

| Length | Cap Percentile |
|--------|----------------|
| > 1km | 95th percentile |
| 500m-1km | 90th percentile |
| 100-500m | 85th percentile |
| < 100m | 85th percentile |

### Congestion Factor Mapping

| Density Range | Congestion Factor | Meaning |
|---------------|-------------------|---------|
| < 1.0 | 1.0 | No congestion (speed × 1.0) |
| 1.0 - 2.0 | 0.95 | Slightly congested (speed × 0.95) |
| 2.0 - 3.0 | 0.87 | Low congestion (speed × 0.87) |
| > 3.0 | 0.5 - 0.87 | High congestion (speed × 0.5 to 0.87) |

**Formula for > 3.0**: `0.5 + (density - 3.0) × 0.1`, capped at 0.87

### Example 7: Long NH Road (from Example 4)

**Scenario**: 
- Total intersection score: **0.75**
- Length: **2.0 km**
- Setting: Urban

**Calculation**:
1. **Raw density**: 0.75 / 2.0 = **0.375**

2. **Length adjustment**: 
   - Length = 2.0 km (> 1km)
   - Adjustment factor = 1.0 (no adjustment)
   - Adjusted length = 2.0 km

3. **Adjusted density**: 0.75 / 2.0 = **0.375**

4. **Capping**:
   - Length = 2.0 km (> 1km)
   - Cap at 95th percentile (let's say p95 = 5.0)
   - Capped density = MIN(0.375, 5.0) = **0.375**

5. **Congestion factor**:
   - Density = 0.375 (< 1.0)
   - Factor = **1.0** (no congestion)

**Result**: 
- `intersection_density_per_km` = **0.375**
- `intersection_congestion_factor` = **1.0**

### Example 8: Short Urban Road with High Intersection Density

**Scenario**:
- Total intersection score: **2.5**
- Length: **0.08 km** (80m)
- Setting: Urban

**Calculation**:
1. **Raw density**: 2.5 / 0.08 = **31.25** (very high!)

2. **Length adjustment**:
   - Length = 0.08 km (< 100m)
   - Adjustment factor = 1.5x
   - Adjusted length = 0.08 × 1.5 = 0.12 km

3. **Adjusted density**: 2.5 / 0.12 = **20.83**

4. **Capping**:
   - Length = 0.08 km (< 100m)
   - Cap at 85th percentile (let's say p85 = 8.0)
   - Capped density = MIN(20.83, 8.0) = **8.0**

5. **Congestion factor**:
   - Density = 8.0 (> 3.0)
   - Factor = 1.0 - (8.0 - 3.0) × 0.1 = 1.0 - 0.5 = **0.5**
   - (Formula: `1.0 - (density - 3.0) × 0.1`, minimum 0.5)

**Result**:
- `intersection_density_per_km` = **8.0**
- `intersection_congestion_factor` = **0.5** (high congestion, speed × 0.5)

### Example 9: Medium-Length Road with Moderate Density (from Example 5)

**Scenario**:
- Total intersection score: **1.15**
- Length: **5.0 km**
- Setting: SemiUrban

**Calculation**:
1. **Raw density**: 1.15 / 5.0 = **0.23**

2. **Length adjustment**:
   - Length = 5.0 km (> 1km)
   - Adjustment factor = 1.0 (no adjustment)
   - Adjusted length = 5.0 km

3. **Adjusted density**: 1.15 / 5.0 = **0.23**

4. **Capping**:
   - Length = 5.0 km (> 1km)
   - Cap at 95th percentile (let's say p95 = 5.0)
   - Capped density = MIN(0.23, 5.0) = **0.23**

5. **Congestion factor**:
   - Density = 0.23 (< 1.0)
   - Factor = **1.0** (no congestion)

**Result**:
- `intersection_density_per_km` = **0.23**
- `intersection_congestion_factor` = **1.0**

### Example 10: Urban Road with High Density

**Scenario**:
- Total intersection score: **4.5**
- Length: **1.5 km**
- Setting: Urban

**Calculation**:
1. **Raw density**: 4.5 / 1.5 = **3.0**

2. **Length adjustment**:
   - Length = 1.5 km (> 1km)
   - Adjustment factor = 1.0 (no adjustment)
   - Adjusted length = 1.5 km

3. **Adjusted density**: 4.5 / 1.5 = **3.0**

4. **Capping**:
   - Length = 1.5 km (> 1km)
   - Cap at 95th percentile (let's say p95 = 5.0)
   - Capped density = MIN(3.0, 5.0) = **3.0**

5. **Congestion factor**:
   - Density = 3.0 (exactly at threshold)
   - Factor = **0.87** (low congestion)

**Result**:
- `intersection_density_per_km` = **3.0**
- `intersection_congestion_factor` = **0.87** (speed × 0.87)

### Example 11: Very Short Road with One Intersection

**Scenario**:
- Total intersection score: **0.5** (from one NH-NH intersection, 2 roads, Urban NH road)
- Length: **0.05 km** (50m)
- Setting: Urban

**Calculation**:
1. **Raw density**: 0.5 / 0.05 = **10.0**

2. **Length adjustment**:
   - Length = 0.05 km (< 100m)
   - Adjustment factor = 1.5x
   - Adjusted length = 0.05 × 1.5 = 0.075 km

3. **Adjusted density**: 0.5 / 0.075 = **6.67**

4. **Capping**:
   - Length = 0.05 km (< 100m)
   - Cap at 85th percentile (let's say p85 = 8.0)
   - Capped density = MIN(6.67, 8.0) = **6.67**

5. **Congestion factor**:
   - Density = 6.67 (> 3.0)
   - Factor = 1.0 - (6.67 - 3.0) × 0.1 = 1.0 - 0.367 = **0.633**

**Result**:
- `intersection_density_per_km` = **6.67**
- `intersection_congestion_factor` = **0.633** (speed × 0.633)

---

## Summary of Key Concepts

### 1. Proportional Sharing
Prevents double-counting: If 3 roads meet at an intersection with score 1.0, each road gets 0.33, not 1.0.

### 2. Road Hierarchy Multiplier
Higher hierarchy roads (NH, SH) get higher multipliers, so the same intersection contributes more to their density score.

### 3. Setting Multiplier
Urban roads get higher multipliers (1.5x) than rural roads (1.0x), reflecting that intersections in urban areas are more significant.

### 4. Length Adjustment
Short roads get their effective length increased, reducing their density. This prevents very short segments from having extreme density values.

### 5. Progressive Capping
Different length buckets have different caps (percentiles), preventing outliers while allowing reasonable variation.

### 6. Congestion Factor
Maps density to a 0-1 factor for speed multiplier:
- **1.0** = No congestion (speed × 1.0 = no penalty)
- **0.5** = High congestion (speed × 0.5 = 50% penalty)

---

## Visual Flow Diagram

```
Intersection Node
    ↓
[Filter: Real intersection?]
    ↓ Yes
[Score by hierarchy combination]
    ↓
[Divide by road count at intersection]
    ↓
[Multiply by road hierarchy multiplier]
    ↓
[Multiply by setting multiplier]
    ↓
Sum for each road segment
    ↓
[Calculate raw density: score / length]
    ↓
[Apply length adjustment]
    ↓
[Apply progressive capping]
    ↓
[Map to congestion factor (0-1)]
    ↓
Store: intersection_density_per_km, intersection_congestion_factor
```

---

## Edge Cases

### Case 1: Road with No Intersections
- `total_intersection_score` = 0.0
- `intersection_density_per_km` = 0.0
- `intersection_congestion_factor` = 1.0 (no congestion)

### Case 2: Road with Multiple Intersections of Different Types
Each intersection is scored independently, then summed with multipliers.

### Case 3: Very Long Road with Few Intersections
Length adjustment doesn't apply (> 1km), but density will be naturally low due to long length.

### Case 4: Road at Cap Limit
If adjusted density exceeds the cap for its length bucket, it's capped at the percentile value, preventing extreme outliers.

---

## ALTERNATE APPROACH: Intersection Speed Degradation (New Method)

### Overview

This is an alternative approach that focuses on **speed degradation** rather than density. The goal is to calculate `intersection_speed_degradation` (0.0 to 0.5) representing how much speed is reduced due to intersections.

### Key Differences from Density Approach

1. **Categorization by Road Sets**: Intersections are categorized as Major, Middling, or Minor based on road type sets
2. **Distance-Based Impact**: Each intersection type degrades speed for a specific distance (not just a point)
3. **Multiplicative Stacking**: For short roads, multiple intersections stack multiplicatively
4. **Setting & Infrastructure Factors**: Additional reductions based on setting and road infrastructure

---

### Step 1: Categorize Intersections

**Road Type Sets:**
- **Set A**: NH, SH, MDR, OH
- **Set B**: HAdj, WoH, Path, Track

**Intersection Types** (based on 2 highest hierarchy roads):
- **Major**: Both roads in Set A → Raw score = **0.5**
- **Middling**: One road in Set A, one in Set B → Raw score = **0.25**
- **Minor**: Both roads in Set B → Raw score = **0.0**

**Note**: Still use the same filtering rules to exclude way splits (3+ roads, different types, or mid-node crossings).

---

### Step 2: Calculate Base Speed Degradation Per Way

**Impact Parameters:**
- **Major intersection**: 50% speed reduction for **50m**
- **Middling intersection**: 25% speed reduction for **25m**
- **Minor intersection**: 10% speed reduction for **10m** (Urban settings only)
  - In SemiUrban and Rural settings, minor intersections have no impact (0% speed reduction)

**Calculation Logic:**

#### For Ways ≥ Impacted Distance:

Weighted average approach:
```
degradation = (degraded_distance × degradation_factor + normal_distance × 0) / total_length
```

**Example**: 100m way with 1 major intersection
- 50m at 50% speed (degradation = 0.5) + 50m at 100% speed (degradation = 0.0)
- Weighted average: (0.5 × 50 + 0.0 × 50) / 100 = **0.25**

#### For Ways < Impacted Distance:

Multiplicative stacking approach:
- Each intersection reduces speed multiplicatively
- Final speed = initial_speed × (1 - degradation_1) × (1 - degradation_2) × ...
- Final degradation = 1 - final_speed

**Example**: 10m way with 2 major intersections
- First intersection: speed = 1.0 × 0.5 = **0.5** (degradation = 0.5)
- Second intersection: speed = 0.5 × 0.5 = **0.25** (degradation = 0.75)

**Example**: 20m way with 1 major + 1 middling intersection
- First (major): speed = 1.0 × 0.5 = **0.5** (degradation = 0.5)
- Second (middling): speed = 0.5 × 0.75 = **0.375** (degradation = 0.625)

---

### Step 3: Apply Setting Multiplier

**Setting Reduction Factors:**
- **Urban**: No reduction (multiply by **1.0**)
- **SemiUrban**: Reduce by 25% (multiply by **0.75**)
- **Rural**: Reduce by 50% (multiply by **0.5**)

**Formula:**
```
setting_adjusted_degradation = base_degradation × setting_multiplier
```

**Example**: Base degradation = 0.25
- Urban: 0.25 × 1.0 = **0.25**
- SemiUrban: 0.25 × 0.75 = **0.1875**
- Rural: 0.25 × 0.5 = **0.125**

---

### Step 4: Apply Lanes + Oneway Factor (Rural Only)

**Condition**: `oneway = yes AND lanes > 2 AND setting = Rural`

**Additional reduction**: 20% (multiply by **0.8**)

**Formula:**
```
final_degradation = IF (oneway = yes AND lanes > 2 AND setting = Rural)
                    THEN setting_adjusted_degradation × 0.8
                    ELSE setting_adjusted_degradation
```

**Example**: Rural road, oneway=yes, lanes=3, base degradation = 0.25
- Setting adjusted: 0.25 × 0.5 = **0.125**
- Lanes+oneway factor: 0.125 × 0.8 = **0.10**

---

### Variable Values Summary

| Variable | Value | Notes |
|----------|-------|-------|
| **Major intersection score** | 0.5 | Raw score for Set A × Set A |
| **Middling intersection score** | 0.25 | Raw score for Set A × Set B |
| **Minor intersection score** | 0.0 | Raw score for Set B × Set B |
| **Major impact distance** | 50m | Distance over which major intersection affects speed |
| **Middling impact distance** | 25m | Distance over which middling intersection affects speed |
| **Major speed reduction** | 50% (0.5) | Speed multiplier for major intersection |
| **Middling speed reduction** | 25% (0.25) | Speed multiplier for middling intersection |
| **Minor impact distance** | 10m | Distance over which minor intersection affects speed (Urban only) |
| **Minor speed reduction** | 10% (0.1) | Speed multiplier for minor intersection (Urban only) |
| **Urban multiplier** | 1.0 | No reduction for urban |
| **SemiUrban multiplier** | 0.75 | 25% reduction for semiurban |
| **Rural multiplier** | 0.5 | 50% reduction for rural |
| **Rural oneway+lanes multiplier** | 0.8 | 20% additional reduction (rural only) |
| **Lanes threshold** | > 2 | Minimum lanes for oneway+lanes factor |
| **Final degradation range** | 0.0 to 0.5 | Output range for intersection_speed_degradation |

---

### Example Calculations

#### Example 1: Long Urban NH Road with Major Intersection

**Scenario**:
- Road: NH, Urban, 200m long, oneway=no
- Has 1 major intersection (NH-NH)

**Calculation**:
1. Base degradation: (50m × 0.5 + 150m × 0.0) / 200m = **0.125**
2. Setting multiplier: Urban = 1.0
3. Setting adjusted: 0.125 × 1.0 = **0.125**
4. Lanes+oneway: Not applicable (not rural)
5. **Final degradation**: **0.125**

---

#### Example 2: Short Rural Road with Multiple Intersections

**Scenario**:
- Road: WoH, Rural, 30m long, oneway=yes, lanes=3
- Has 2 major intersections

**Calculation**:
1. Base degradation (multiplicative):
   - First: speed = 1.0 × 0.5 = 0.5 (degradation = 0.5)
   - Second: speed = 0.5 × 0.5 = 0.25 (degradation = 0.75)
   - **Base degradation = 0.75**
2. Setting multiplier: Rural = 0.5
3. Setting adjusted: 0.75 × 0.5 = **0.375**
4. Lanes+oneway: Applicable (rural + oneway + lanes > 2)
5. Final: 0.375 × 0.8 = **0.30**

---

#### Example 3: SemiUrban Road with Mixed Intersections

**Scenario**:
- Road: SH, SemiUrban, 150m long, oneway=no
- Has 1 major + 1 middling intersection

**Calculation**:
1. Base degradation (weighted average):
   - Major: 50m at 0.5 degradation
   - Middling: 25m at 0.25 degradation (but overlaps with major)
   - Need to handle overlap: use multiplicative for overlapping segments
   - Non-overlapping: 25m at 0.0, 25m at 0.25, 50m at 0.5
   - Weighted: (25×0.0 + 25×0.25 + 50×0.5) / 100 = **0.3125**
2. Setting multiplier: SemiUrban = 0.75
3. Setting adjusted: 0.3125 × 0.75 = **0.234**
4. **Final degradation**: **0.234**

---

### Implementation Notes

1. **Overlapping Impact Zones**: When multiple intersections have overlapping impact distances, use multiplicative stacking for the overlapping segments
2. **Distance Calculation**: Use actual distance along the way geometry, not straight-line distance
3. **Node Position**: Intersection impact starts at the intersection node and extends along the way
4. **Direction**: Impact applies in both directions from the intersection node

---

### Comparison with Density Approach

| Aspect | Density Approach | Speed Degradation Approach |
|--------|-----------------|---------------------------|
| **Output** | `intersection_density_per_km` (0 to high) | `intersection_speed_degradation` (0.0 to 0.5) |
| **Focus** | Count of intersections per km | Actual speed impact of intersections |
| **Scoring** | Hierarchy-based matrix | Set-based categorization |
| **Length handling** | Length adjustment factors | Distance-based impact zones |
| **Short roads** | Length adjustment + capping | Multiplicative stacking |
| **Factors** | Hierarchy + setting multipliers | Setting + lanes+oneway multipliers |
| **Use case** | Density analysis, congestion factor | Direct speed multiplier for routing |

