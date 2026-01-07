# Persona Scoring Analysis Summary

> **⚠️ NOTE: This document describes analysis of the OLD complex persona scoring system.**
> 
> **Current Implementation:** The project now uses a **Simplified Framework (Phase 1)**. See:
> - `osm-file-processing-v2/sql/road_persona/SIMPLIFIED_FRAMEWORK.md` - Current framework
> - `osm-file-processing-v2/sql/road_persona/README_SIMPLIFIED.md` - Usage guide
> 
> This document is retained for historical reference only.

## Key Findings

### 1. Road Type Distribution
- **WoH dominates**: 85.03% of all roads (8.8M roads)
- **Highways are rare**: Only 4.12% combined (427K roads)
  - NH: 1.57% (163K roads)
  - MDR: 1.35% (140K roads)
  - SH: 1.06% (110K roads)
  - OH: 0.14% (15K roads)

**Implication**: The hard eligibility gate (only NH/SH/MDR/OH score > 0) is working correctly - WoH gets 0.0 score.

---

### 2. Lane + Oneway Distribution (Highways Only)

**Overall Distribution**:
- **Unknown lanes**: 66.53% (284K roads) - Major data quality issue
- **2+ lanes oneway**: 22.26% (95K roads) - The "4-lane highway" case (BEST for MileMuncher)
- **2+ lanes bidirectional**: 9.98% (43K roads)
- **1 lane oneway**: 0.88% (4K roads)
- **1 lane bidirectional**: 0.35% (1.5K roads)

**By Road Type**:
- **OH**: 67.24% are 2+ lanes oneway (EXCELLENT - highest quality highways)
- **NH**: 38.58% are 2+ lanes oneway, 50.21% unknown
- **SH**: Only 13.24% are 2+ lanes oneway, 73.63% unknown
- **MDR**: Only 5.49% are 2+ lanes oneway, 83.78% unknown

**Key Insight**: OH roads are the highest quality (most are 2+ lanes oneway), followed by NH. SH and MDR have poor lane data quality.

---

### 3. MileMuncher Scores - Current Performance

**By Road Type** (all score very high!):
- **NH**: 96.19 avg (100% excellent ≥70)
- **OH**: 93.12 avg (99.74% excellent)
- **SH**: 92.83 avg (100% excellent)
- **MDR**: 91.15 avg (99.98% excellent)
- **WoH**: 0.0 avg (0% excellent) ✓ Hard gate working!

**By Lane + Oneway Category**:
- **2+ lanes oneway**: 95.48 avg (100% excellent) - BEST
- **2+ lanes bidirectional**: 94.38 avg (100% excellent)
- **Unknown**: 92.84 avg (99.98% excellent)
- **1 lane oneway**: 92.13 avg (99.95% excellent)
- **1 lane bidirectional**: 91.97 avg (99.74% excellent)

**Key Insight**: 
- Current scoring already differentiates well (2+ lanes oneway scores highest)
- But the difference is small (95.48 vs 91.97 = only 3.5 points)
- Need to amplify the hierarchy to make it more meaningful

---

### 4. Urban Stress vs Remoteness Correlation

**Findings**:
- **Urban**: avg_low_pop=0.128, avg_low_build=0.203 (low remoteness, high stress)
- **SemiUrban**: avg_low_pop=0.275, avg_low_build=0.554
- **Rural**: avg_low_pop=0.403, avg_low_build=0.733 (higher remoteness, no stress)

**Key Insight**: 
- There IS correlation (rural areas have higher remoteness scores)
- But remoteness scores don't vary much within rural category (0.393-0.403 median)
- **Confirms over-indexing**: Once you're rural, there's no additional value in being "more remote"
- Urban stress already captures the urban/rural distinction effectively

**Recommendation**: Reduce remoteness weights and rely more on urban_stress.

---

### 5. Population Density & Build Percentage Percentiles

**Population Density** (people/km²):
- P25: 479
- **P50 (median)**: 1,174 ← Use as "rural enough" threshold
- P75: 3,322
- P95: 17,044

**Build Percentage**:
- P25: 1.67%
- **P50 (median)**: 4.52% ← Use as "rural enough" threshold
- P75: 14.66%
- P95: 33.37%

**Recommendation**: Use P50 (median) as the threshold for "rural enough" - roads below this get capped remoteness score.

---

### 6. Corridor Key Distribution

**Current Implementation** (using ref/name/classification/osm_id):
- **Has classification (no ref/name)**: 95.09% (9.8M roads) ← MEANINGLESS corridors!
- **Has ref**: 2.56% (266K roads) ← Good corridors
- **Has name (no ref)**: 2.04% (211K roads) ← Good corridors
- **Only osm_id**: 0.31% (32K roads) ← Meaningless

**Key Insight**: 
- 95% of roads are grouped by classification, creating meaningless corridors
- Only 4.6% of roads have meaningful corridor identifiers (ref or name)
- **This confirms the need to change corridor_key to only use ref/name**

**Impact**: After change, ~95% of roads will have corridor_km = 0 (no corridor bonus), which is correct - unnamed roads shouldn't benefit from corridor compounding.

---

## Recommendations for MileMuncher Scoring Improvements

### 1. Hard Eligibility Gate ✓ (Already Working)
- Only NH/SH/MDR/OH score > 0
- WoH correctly gets 0.0

### 2. Lane + Oneway Hierarchy (Needs Amplification)

**Current**: Small difference (95.48 vs 91.97 = 3.5 points)
**Proposed Multipliers**:
- **2+ lanes oneway**: 1.0x (best - the "4-lane highway")
- **2+ lanes bidirectional**: 0.90x
- **1 lane oneway**: 0.80x
- **1 lane bidirectional**: 0.75x
- **Unknown**: 0.70x (conservative default)

**Rationale**: 
- Amplify the difference to make hierarchy meaningful
- Unknown lanes should be penalized (data quality issue)
- Road type (NH > SH > MDR > OH) should still matter within each lane category

### 3. Remoteness Over-Indexing (Needs Reduction)

**Current Weights**:
- MileMuncher: 0.12 × remoteness + 0.12 × (1 - urban_stress)

**Proposed Weights**:
- MileMuncher: 0.08 × remoteness + 0.15 × (1 - urban_stress)

**Rationale**:
- Reduce remoteness weight by 33% (0.12 → 0.08)
- Increase urban_stress weight by 25% (0.12 → 0.15)
- Urban_stress is the primary signal; remoteness is secondary

**Alternative**: Cap remoteness scores at 0.8 for roads below P50 threshold (median population density/build_perc).

### 4. Corridor Continuity (Critical Fix)

**Current**: `COALESCE(ref, name, road_classification_i1, osm_id)`
**Proposed**: `COALESCE(NULLIF(ref,''), NULLIF(name,''))`

**Impact**:
- ~95% of roads will have corridor_km = 0 (no bonus)
- Only 4.6% of roads (with ref/name) will get corridor bonuses
- This is correct - corridors should represent actual continuous routes

---

## Implementation Priority

1. **HIGH**: Fix corridor continuity (only ref/name)
2. **HIGH**: Add hard eligibility gate for MileMuncher (NH/SH/MDR/OH only)
3. **MEDIUM**: Amplify lane + oneway hierarchy multipliers
4. **MEDIUM**: Reduce remoteness weights, increase urban_stress weights

---

## Data Quality Issues Identified

1. **Lane data missing**: 66.53% of highways have unknown lanes
   - OH: 31.22% unknown (best)
   - NH: 50.21% unknown
   - SH: 73.63% unknown (worst)
   - MDR: 83.78% unknown (worst)

2. **Corridor identifiers missing**: 95% of roads lack ref/name
   - Only 4.6% have meaningful corridor identifiers

3. **Impact**: Unknown lanes should get conservative default (0.70x multiplier), not penalized too harshly since it's a data quality issue, not a road quality issue.

---

## Next Steps

1. Review this analysis summary
2. Confirm the proposed changes align with requirements
3. ~~Implement SQL changes in `01_compute_persona_base_scores.sql` and `02_compute_persona_corridors_and_final.sql`~~ (Old system - replaced by simplified framework)
4. Test and validate with sample queries
5. Update documentation

