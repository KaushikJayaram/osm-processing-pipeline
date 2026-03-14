# Persona V2 Scoring System - Update Summary

## Overview
This update enhances the persona scoring system with persona-specific scenic parameters and normalized scores for better differentiation.

## Key Changes

### 1. New Scenic Parameters (Replacing Legacy `score_scenic`)

#### **score_scenic_wild** (For TrailBlazer)
- Emphasizes: Forest (65%), Hills (18%), Rivers (12%), Fields (6%), Lakes (8%)
- Synergy bonuses:
  - +0.25 if forest ≥35% AND hill
  - +0.18 if forest ≥35% AND river
  - +0.12 if lake AND (hill OR field ≥35%)
- Confidence-weighted (0.70-1.00 multiplier based on scenery_v2_confidence)

#### **score_scenic_serene** (For TranquilTraveller)
- Emphasizes: Lakes (35%), Rivers (25%), Hills (15%), Fields (10%), Forest (5%)
- Synergy bonuses:
  - +0.15 if lake present
  - +0.10 if river AND (hill OR forest ≥35%)
  - +0.08 if field ≥35% AND (lake OR river)
- Confidence-weighted (0.70-1.00 multiplier)

#### **score_scenic_fast** (For MileMuncher & CornerCraver)
- Emphasizes: Hills (35%), Rivers (30%), Lakes (25%), Forest (10%)
- Gentler confidence multiplier (0.80-1.00) for fast riding context

### 2. Updated Persona Formulas

#### MileMuncher
```
U × Cruise × Flow × (1 - 0.35×Twist) × (0.92 + 0.08×ScenicFast) × (0.90 + 0.10×(1-Remoteness))
```

#### CornerCraver
```
U × Twist × (0.80 + 0.20×Flow) × (1 - 0.15×Cruise) × (0.94 + 0.06×ScenicFast) × (0.90 + 0.10×Remoteness)
```

#### TrailBlazer
```
U × Offroad × Remoteness × (0.55 + 0.45×ScenicWild) × (1 - 0.15×Flow)
```

#### TranquilTraveller
```
U × Calm × (0.75 + 0.25×Flow) × (0.55 + 0.45×ScenicSerene) × (1 - 0.15×Twist) × (0.85 + 0.15×Remoteness)
```

### 3. Normalized Persona Scores

New columns: `persona_*_score_normalised`

Normalization stretches each persona score to 0-1 using global min/max:
```
normalized = (score - global_min) / (global_max - global_min)
```

This improves differentiation by expanding the effective range of scores.

## Implementation Details

### SQL Files

1. **00_add_persona_v2_columns.sql** - Adds all new columns (idempotent)
   - 3 scenic score columns
   - 4 normalized persona score columns

2. **01_compute_parameter_scores.sql** - Computes all parameter scores (chunked)
   - Existing parameters unchanged
   - New scenic scores with confidence weighting and synergy bonuses

3. **02_compute_persona_scores.sql** - Computes persona scores (chunked)
   - Updated formulas using persona-specific scenic scores

4. **03_normalize_persona_scores.sql** - Normalizes persona scores (chunked)
   - Uses global min/max computed once by runner
   - Applied per-chunk for efficiency

### Runner Updates

**persona_v2_run.py** enhancements:
- New function: `compute_global_persona_norm_bounds()` - computes min/max once across all bikable roads
- Updated SQL step tracking with `needs_minmax` flag
- Passes min/max bounds as parameters to normalization step
- Logs global ranges for verification

### Performance Considerations

- **Chunked execution** for all scoring steps (20,000 grid_id chunks)
- **Single global computation** for min/max bounds (not per-chunk)
- **No new indexes** - uses existing `bikable_road`, `geometry`, and grid mapping
- **Confidence multipliers** are cheap lookups (CASE statements)
- **Synergy bonuses** use simple CASE logic (no joins or spatial ops)

## Usage

Run with test bbox (default):
```bash
./run_with_venv.sh osm-processing-pipeline/scripts/dev-runs/persona_v2_run.py --bbox test
```

Run for all India:
```bash
./run_with_venv.sh osm-processing-pipeline/scripts/dev-runs/persona_v2_run.py --bbox all
```

Skip schema creation (if columns exist):
```bash
./run_with_venv.sh osm-processing-pipeline/scripts/dev-runs/persona_v2_run.py --bbox test --skip-schema
```

## Validation

Use the analysis script to validate results:
```bash
./run_with_venv.sh osm-processing-pipeline/Analysis/persona_v2_analysis.py
```

This generates:
- Summary statistics (with distance weighting)
- Score distributions by road type
- Correlation heatmaps
- Comparative visualizations
- Top roads per persona

## Parameter Reference

### Confidence Multipliers (Wild/Serene)
- conf ≥ 0.90: 1.00
- conf ≥ 0.80: 0.92
- conf ≥ 0.70: 0.85
- conf > 0.00: 0.75
- else: 0.70

### Confidence Multipliers (Fast)
- conf ≥ 0.90: 1.00
- conf ≥ 0.80: 0.95
- conf ≥ 0.70: 0.90
- conf > 0.00: 0.85
- else: 0.80

### Constants
- **TWIST_SAT**: 0.54 (p95 for twistiness normalization)
- **CHUNK_SIZE**: 20,000 grid_ids per batch
