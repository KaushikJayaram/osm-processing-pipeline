# Simplified Persona Scoring Framework

## Philosophy

**Start simple, add complexity only where needed.**

Instead of complex multi-factor formulas with percentile normalization, top-end stretching, and multiple intermediate factors, we use:
- **2-3 key factors per persona** (the ones that truly matter)
- **Simple 0-1 scoring** for each factor
- **Weighted average** to combine factors
- **Linear normalization** to 0-100 range
- **Optional corridor bonus** (keep it simple)

---

## High-Level Framework

### Step 1: Identify Core Factors (2-3 per Persona)

Each persona cares about **2-3 things**. Everything else is secondary.

#### MileMuncher
1. **Road Quality** (NH/SH/MDR/OH + lanes) - Must be highway, better if multi-lane
2. **Straightness** (low twistiness) - Prefers straight roads
3. **Low Stress** (rural > semi-urban > urban) - Avoids urban congestion

#### CornerCraver
1. **Twistiness** (high twistiness_score) - The more curves, the better
2. **Low Stress** (rural > semi-urban > urban) - Avoids urban traffic
3. **Surface Quality** (paved > unpaved) - Needs decent surface for technical riding

#### TrailBlazer
1. **Exploration** (inner roads, not major highways) - Prefers off-beaten-path
2. **Scenery** (scenic richness) - Wants interesting views
3. **Low Density** (rural areas) - Avoids urban congestion

#### TranquilTraveller
1. **Scenery** (scenic richness) - Primary focus on beauty
2. **Low Stress** (rural > semi-urban > urban) - Wants peaceful rides
3. **Moderate Roads** (MDR/SH/OH, not NH or WoH) - Comfortable but not extreme

---

### Step 2: Simple Factor Scoring (0-1 range)

Each factor gets a simple 0-1 score. No complex percentile calculations, no log-scaling (unless truly needed).

#### Road Quality (for MileMuncher)
```sql
road_quality = CASE
    WHEN road_type_i1 NOT IN ('NH', 'SH', 'MDR', 'OH') THEN 0.0  -- Hard gate: only highways
    WHEN road_type_i1 = 'NH' AND lanes >= 2 THEN 1.0
    WHEN road_type_i1 = 'NH' THEN 0.8
    WHEN road_type_i1 = 'SH' AND lanes >= 2 THEN 0.7
    WHEN road_type_i1 = 'SH' THEN 0.6
    WHEN road_type_i1 IN ('MDR', 'OH') AND lanes >= 2 THEN 0.5
    WHEN road_type_i1 IN ('MDR', 'OH') THEN 0.4
    ELSE 0.0
END
```

#### Straightness (for MileMuncher)
```sql
straightness = 1.0 - LEAST(1.0, twistiness_score / 0.20)  -- Cap at 0.20 twistiness = 0 score
-- If twistiness_score is NULL, default to 0.5 (neutral)
```

#### Low Stress (for all personas)
```sql
low_stress = CASE
    WHEN road_setting_i1 = 'Rural' THEN 1.0
    WHEN road_setting_i1 = 'SemiUrban' THEN 0.6
    WHEN road_setting_i1 = 'Urban' THEN 0.2
    ELSE 0.5  -- Unknown
END
```

#### Twistiness (for CornerCraver)
```sql
twistiness = LEAST(1.0, twistiness_score / 0.15)  -- Normalize: 0.15+ = max score
-- If twistiness_score is NULL, default to 0.0 (no curves = bad for CornerCraver)
```

#### Surface Quality (for CornerCraver)
```sql
surface_quality = CASE
    WHEN tags->>'surface' IN ('asphalt', 'paved', 'concrete') THEN 1.0
    WHEN tags->>'surface' IN ('paving_stones', 'sett', 'cobblestone') THEN 0.7
    WHEN tags->>'surface' IN ('compacted', 'fine_gravel', 'gravel') THEN 0.4
    WHEN tags->>'surface' IN ('dirt', 'earth', 'ground', 'mud', 'sand', 'unpaved') THEN 0.1
    ELSE 0.6  -- Unknown = assume decent
END
```

#### Exploration (for TrailBlazer)
```sql
exploration = CASE
    WHEN road_type_i1 IN ('Track', 'Path') THEN 1.0
    WHEN road_type_i1 = 'WoH' THEN 0.8
    WHEN road_type_i1 IN ('MDR', 'OH') THEN 0.5
    WHEN road_type_i1 = 'SH' THEN 0.3
    WHEN road_type_i1 = 'NH' THEN 0.1
    WHEN road_type_i1 = 'HAdj' THEN 0.2
    ELSE 0.5
END
```

#### Scenery (for TrailBlazer and TranquilTraveller)
```sql
-- Simple count of scenery flags (cap at reasonable max)
scenery = LEAST(1.0, (
    COALESCE(road_scenery_forest, 0) +
    COALESCE(road_scenery_hill, 0) +
    COALESCE(road_scenery_lake, 0) +
    COALESCE(road_scenery_river, 0) +
    COALESCE(road_scenery_mountainpass, 0) +
    COALESCE(road_scenery_field, 0)
) / 3.0)  -- 3+ flags = max score
```

#### Moderate Roads (for TranquilTraveller)
```sql
moderate_roads = CASE
    WHEN road_type_i1 = 'WoH' THEN 0.0  -- Hard exclude
    WHEN road_type_i1 = 'NH' THEN 0.3   -- Too major
    WHEN road_type_i1 IN ('MDR', 'SH', 'OH') THEN 1.0  -- Perfect
    WHEN road_type_i1 = 'HAdj' THEN 0.4
    WHEN road_type_i1 IN ('Track', 'Path') THEN 0.6
    ELSE 0.5
END
```

---

### Step 3: Combine Factors (Weighted Average)

Simple weighted average. No complex compounding, no conditional multipliers.

#### MileMuncher
```sql
milemuncher_raw = (
    0.50 * road_quality +
    0.30 * straightness +
    0.20 * low_stress
)
```

#### CornerCraver
```sql
cornercraver_raw = (
    0.60 * twistiness +
    0.25 * low_stress +
    0.15 * surface_quality
)
```

#### TrailBlazer
```sql
trailblazer_raw = (
    0.40 * exploration +
    0.35 * scenery +
    0.25 * low_stress
)
```

#### TranquilTraveller
```sql
tranquiltraveller_raw = (
    0.45 * scenery +
    0.30 * low_stress +
    0.25 * moderate_roads
)
```

---

### Step 4: Normalize to 0-100

**Simple linear normalization** - no percentile ranking, no top-end stretching (initially).

```sql
-- Option 1: Simple min-max normalization (if we want to preserve distribution)
persona_base_score = (raw_score - min_raw) / (max_raw - min_raw) * 100.0

-- Option 2: Direct scaling (if raw scores are already 0-1)
persona_base_score = raw_score * 100.0

-- Option 3: Percentile-based (only if we need better distribution)
-- Use PERCENT_RANK() but keep it simple - no power functions
persona_base_score = PERCENT_RANK() OVER (ORDER BY raw_score) * 100.0
```

**Recommendation**: Start with **Option 2** (direct scaling) since our factors are already 0-1. If distribution looks bad, switch to Option 3 (percentile).

---

### Step 5: Corridor Bonus (Optional, Keep Simple)

Only if needed. Keep it simple:

```sql
-- Group by ref/name only (no fallbacks)
corridor_key = COALESCE(NULLIF(ref, ''), NULLIF(name, ''))

-- Sum good segments (base_score >= 60, not 70 - lower threshold)
corridor_km = SUM(CASE WHEN base_score >= 60 THEN length_km ELSE 0 END)

-- Simple linear bonus (not exponential)
corridor_bonus = LEAST(20.0, corridor_km / 5.0)  -- Max 20 point bonus, 5km = 1 point

-- Final score
final_score = LEAST(100.0, base_score + corridor_bonus)
```

**Alternative**: Skip corridor bonus entirely initially. Add it only if we see that routes are too fragmented.

---

## Implementation Plan

### Phase 1: Core Framework (Start Here)
1. ✅ Define 2-3 factors per persona (this document)
2. Implement simple factor scoring (0-1)
3. Implement weighted average combination
4. Implement linear normalization (direct scaling)
5. Test and validate with sample queries

### Phase 2: Refinement (Add Only If Needed)
- Add corridor bonus if routes are too fragmented
- Adjust weights based on visualization feedback
- Add percentile normalization if distribution is poor
- Add hard gates (like MileMuncher highway-only) if needed

### Phase 3: Advanced (Only If Required)
- Top-end stretching for excellent roads
- Complex compounding formulas
- Multiple intermediate factors
- Fine-tuned multipliers

---

## Key Simplifications

1. **No percentile normalization initially** - Direct scaling from 0-1 factors
2. **No top-end stretching** - Linear mapping
3. **No complex exponential formulas** - Simple weighted averages
4. **No multiple intermediate factors** - Only compute what we need
5. **No log-scaling** - Linear relationships
6. **No percentile capping** - Use simple thresholds
7. **Simple corridor bonus** - Linear, not exponential

---

## Validation Approach

1. **Visualize in QGIS** - Do high-scoring roads make sense?
2. **Sample queries** - Check top 20 roads per persona
3. **Distribution check** - Are scores spread reasonably (not all 0 or 100)?
4. **Factor contribution** - Do the factors we chose actually matter?

---

## Questions to Answer

1. **Do we need corridor bonus?** - Test without it first, add if needed
2. **Do we need percentile normalization?** - Test direct scaling first
3. **Are 2-3 factors enough?** - Start here, add more only if clearly needed
4. **Do we need hard gates?** - MileMuncher highway-only seems necessary, others TBD

---

## Next Steps

1. Review and approve this simplified framework
2. Implement Phase 1 (core framework)
3. Test with sample data
4. Visualize in QGIS
5. Iterate based on findings
6. Add complexity only where clearly needed

