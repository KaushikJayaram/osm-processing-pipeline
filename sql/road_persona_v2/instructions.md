# Persona V2 Scoring Framework - Design Instructions

## Overview
This document outlines the design decisions and scoring logic for the Persona V2 framework. The goal is to create an improved, more accurate persona scoring system that better captures the characteristics that appeal to different rider personas.

## Context from V1
The original persona scoring framework (`road_persona/`) used a simplified approach with base scores calculated from various road attributes. Review the following files for context:
- `../road_persona/SIMPLIFIED_FRAMEWORK.md` - Original framework design
- `../road_persona/01_compute_persona_base_scores_simplified.sql` - Original scoring logic
- `../road_persona/README_SIMPLIFIED.md` - Original documentation

## Four Personas

### 1. MileMuncher
**Profile**: Loves long, uninterrupted rides with minimal stops and good road quality for maintaining speed.

**Key Attributes** (to be determined):
- Road classification (highways/arterials preferred)
- Road quality/surface
- Straightness vs curvature
- Low intersection density
- Low urban pressure
- [Add more as needed]

**Scoring Logic**: [TBD]

---

### 2. CornerCraver
**Profile**: Seeks twisty, curved roads with technical riding challenges.

**Key Attributes** (to be determined):
- High curvature scores
- Hill/elevation characteristics
- Road classification (mountain roads)
- Scenic quality
- [Add more as needed]

**Scoring Logic**: [TBD]

---

### 3. TrailBlazer
**Profile**: Adventures off the beaten path, preferring remote and scenic routes.

**Key Attributes** (to be determined):
- Low urban pressure
- High scenery scores (natural landscapes)
- Road access level (prefer less accessible)
- Road classification (rural/unpaved)
- [Add more as needed]

**Scoring Logic**: [TBD]

---

### 4. TranquilTraveller
**Profile**: Enjoys peaceful, scenic rides away from traffic and urban chaos.

**Key Attributes** (to be determined):
- Low urban pressure
- High scenery scores
- Low traffic density
- Moderate curvature (not too extreme)
- Good surface quality
- [Add more as needed]

**Scoring Logic**: [TBD]

---

## Available Attributes in osm_all_roads

Based on the existing pipeline, the following attributes are available for scoring:

### Road Classification
- `classification_arterial_type` (freeway, arterial, collector, local, etc.)
- `classification_hierarchy_int` (numeric hierarchy level)

### Road Curvature
- `curvature_*` columns (various curvature metrics)

### Scenery
- `scenery_*` columns (landscape classifications, natural features)

### Urban Pressure
- `urban_pressure_*` columns (population density, urban cluster proximity)

### Urban Clusters
- `urban_cluster_*` columns (cluster membership, urban characteristics)

### Road Access
- `access_*` columns (accessibility metrics)

### Intersection Density
- `intersection_density_*` columns (junction frequency)

### Others
- `highway` (OSM highway tag)
- `surface` (road surface type)
- `bikable_road` (boolean filter)
- `geometry` (for spatial operations)

## Design Questions to Resolve

### 1. Scoring Scale
- Continue with 0-100 scale?
- How to handle NULL values in input attributes?
- Should we normalize/standardize inputs before scoring?

### 2. Weighting Strategy
- Fixed weights vs. adaptive weights?
- How to combine multiple attributes into a single persona score?
- Should weights vary by region/context?

### 3. Exclusion Rules
- Should certain road types be excluded entirely for specific personas?
- Minimum thresholds for inclusion?

### 4. Performance Considerations
- Can scoring be done in a single UPDATE statement per persona?
- Need for intermediate temp tables?
- Chunking strategy (currently set to grid_id ranges)

### 5. Validation Approach
- How to validate that scores make intuitive sense?
- Sample roads to manually check?
- Distribution analysis?

## Implementation Plan

### Phase 1: Define Scoring Logic
1. Decide on exact attributes to use for each persona
2. Define weighting/combination formula
3. Document decision rationale

### Phase 2: Implement SQL
1. Write scoring SQL in `01_compute_persona_v2_scores.sql`
2. Test on small bbox (test bounds)
3. Validate sample results

### Phase 3: Production Run
1. Run on full India bbox
2. Analyze score distributions
3. Iterate if needed

## Notes & Ideas

[Add design notes, brainstorming, and decision rationale here as you develop the logic]

---

**Next Steps**:
1. Review the original scoring logic in `../road_persona/01_compute_persona_base_scores_simplified.sql`
2. Identify what worked well and what needs improvement
3. Draft the new scoring formulas
4. Implement in SQL


**Prompt**:

You are working in the RideSense OSM/PostGIS pipeline. Implement persona parameter scoring + persona scores in SQL.

GOAL
1) Compute 8 scoring parameters (all in 0–1) for every row in `osm_all_roads`
2) Compute 4 persona scores (0–1) using the formulas below
3) Urban rule: when `road_scenery_urban = 1` then ALL persona scores = 0 (hard gate)
4) Keep the computation cheap: pure SQL CASE logic + simple arithmetic. No expensive spatial ops.

INPUT COLUMNS (already exist)
- road_scenery_urban (0/1)
- road_type_i1 (enum: NH, SH, OH, MDR, WOH, Res, HADJ, TRACK, PATH, etc.)
- fourlane (yes/no)
- road_scenery_semiurban (0/1)
- intersection_speed_degradation_final (0.5–1.0, higher is better flow)
- reinforced_pressure (0–1, 0 remote, 1 urban)
- twistiness_score (numeric; not guaranteed to saturate at 1)
- road_scenery_hill, road_scenery_lake, road_scenery_beach, road_scenery_river, road_scenery_forest, road_scenery_field (0/1 booleans)

OUTPUT COLUMNS TO ADD/UPDATE (create if missing)
Parameter columns (0–1):
- score_urban_gate              (0/1)
- score_cruise_road             (0–1)
- score_offroad                 (0–1)
- score_calm_road               (0–1)
- score_flow                    (0–1)
- score_remoteness              (0–1)
- score_twist                   (0–1)
- score_scenic                  (0–1)

Persona score columns (0–1): - use the v2 column names as in the 00_add_persona_v2_columns.sql
- persona_milemuncher_score
- persona_cornercraver_score
- persona_trailblazer_score
- persona_tranquiltraveller_score

STEP A — Compute 8 PARAMETER SCORES

A1) UrbanGate
score_urban_gate = CASE WHEN road_scenery_urban = 1 THEN 0 ELSE 1 END

A2) CruiseRoadScore = (road_type_i1 factor) * (fourlane factor)
road_type_i1 factor:
  NH=1.0
  SH=0.9
  OH=0.9
  MDR=0.9
  WOH=0.2
  Res=0.2
  HADJ=0.6
  TRACK=0.0
  PATH=0.0
  else=0.25
fourlane factor:
  yes=1.0
  no=0.8

A3) OffRoadScore = (road_type_i1 factor) * (fourlane factor) * (semiurban factor)
road_type_i1 factor:
  NH=0.2
  SH=0.3
  OH=0.3
  MDR=0.3
  WOH=0.9
  Res=0.8
  HADJ=0.4
  TRACK=1.0
  PATH=0.9
  else=0.6
fourlane factor:
  yes=0.5
  no=1.0
semiurban factor:
  road_scenery_semiurban=1 -> 0.8
  else -> 1.0

A4) CalmRoadScore = (road_type_i1 factor) * (fourlane factor) * (semiurban factor)
road_type_i1 factor:
  NH=0.3
  SH=0.8
  OH=0.9
  MDR=1.0
  WOH=0.5
  Res=0.3
  HADJ=0.3
  TRACK=0.3
  PATH=0.1
  else=0.5
fourlane factor:
  yes=0.9
  no=1.0
semiurban factor:
  road_scenery_semiurban=1 -> 0.8
  else -> 1.0

A5) FlowScore
score_flow = COALESCE(intersection_speed_degradation_final, 1.0)
Clamp to [0.5,1.0] if needed.

A6) RemotenessScore (inverse of reinforced_pressure)
score_remoteness = 1.0 - COALESCE(reinforced_pressure, 0.0)
Clamp to [0,1].

A7) TwistScore
We need a robust normalization because twistiness_score max is unknown.
Implement: twist_norm = LEAST(twistiness_score / TWIST_SAT, 1.0)
Choose TWIST_SAT = p95(twistiness_score) computed once (for now use a constant like 0.30, and make it easy to change).
Hill factor:
  if road_scenery_hill=1 -> 1.0 else 0.8
score_twist = twist_norm * hill_factor
Clamp [0,1].

A8) ScenicScore
scenic_count = hill + lake + beach + river + forest + field
(note: forest/field are mutually exclusive but still count as 1)
Map to score:
  0 elements -> 0.60
  1 element  -> 0.75
  2 elements -> 0.88
  3+         -> 1.00

STEP B — Compute PERSONA SCORES (use these exact formulas)
Always apply UrbanGate hard: if road_scenery_urban=1 then persona scores = 0.

Let U = score_urban_gate
Let C = score_cruise_road
Let O = score_offroad
Let K = score_calm_road
Let F = score_flow
Let R = score_remoteness
Let T = score_twist
Let S = score_scenic

B1) MileMuncher
MM = U * C * F * (1 - 0.35*T) * (0.90 + 0.10*S) * (0.90 + 0.10*(1-R))
Explanation: high cruise + high flow, penalize twist, tiny scenic boost, slight preference for less remote (optional; keep as written)

B2) CornerCraver
CC = U * T * (0.80 + 0.20*F) * (1 - 0.15*C) * (0.92 + 0.08*S) * (0.90 + 0.10*R)
Explanation: twist primary, flow helps, slight highway penalty, tiny scenic, mild remoteness preference

B3) TrailBlazer
TB = U * O * (0.80 + 0.20*S) * (1 - 0.25*F) * (0.70 + 0.30*R)
Explanation: offroad primary, scenic helps, prefers low-flow, prefers remote

B4) TranquilTraveller
TT = U * K * (0.75 + 0.25*F) * (0.70 + 0.30*S) * (1 - 0.15*T) * (0.80 + 0.20*R)
Explanation: calm roads + flow + scenic, small twist penalty, mild remoteness preference

Clamp each persona score to [0,1].

DELIVERABLES
1) sql file to add columns
2) sql file to calculate the 8 parameter scores
3) sql file to calculate the final persona scores from the 8 parameter scores
4) updated the runner file /Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/scripts/dev-runs/persona_v2_run.py to run these sql scripts

5) Add a small validation query block at end: - give this as a separate sql file in /Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/sql/road_persona_v2 - but dont set it to run with the runner - i will run later manually
   - summary stats (count, avg, p50, p90) for each persona score
   - top 5 roads by each persona score (show osm_id, name, road_type_i1, scores)

IMPORTANT IMPLEMENTATION NOTES
- Use only standard Postgres SQL (CASE, COALESCE, LEAST/GREATEST).
- Keep computations null-safe (COALESCE).
- Do not use expensive spatial functions in this script.
- Make sure the “Urban hard gate” wins (persona scores become 0 when road_scenery_urban=1).
