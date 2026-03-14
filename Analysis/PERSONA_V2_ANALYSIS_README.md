# Persona V2 Analysis Script

## Overview
This script performs comprehensive analysis and validation of the Persona V2 scoring system. It replaces the manual SQL validation script with an automated Python analysis that generates statistics, CSVs, and visualizations.

## Features

### Summary Statistics
- **All Scores**: Generates comprehensive statistics (count, null_count, mean, median, std, min, max, p5, p10, p25, p50, p75, p90, p95, p99) for:
  - 8 parameter scores (urban_gate, cruise_road, offroad, calm_road, flow, remoteness, twist, scenic)
  - 4 persona scores (MileMuncher, CornerCraver, TrailBlazer, TranquilTraveller)

### Validation
- **Urban Gate Check**: Validates that all persona scores are 0 when `road_scenery_urban = 1`
- Reports violation counts (should be 0)

### Road Analysis
- **Top Roads**: Top 10 roads for each persona with all score details
- **Road Type Distribution**: Average scores by road type (NH, SH, OH, MDR, etc.)

### Visualizations
1. **Individual Histograms**: Distribution for each of the 12 scores (8 parameters + 4 personas)
2. **Boxplot Comparisons**: 
   - Parameter scores comparison
   - Persona scores comparison
3. **Correlation Heatmaps**:
   - All scores (12x12)
   - Persona scores only (4x4)
4. **Bar Chart**: Average persona scores by road type (top 10 types)

## Output Structure

```
Analysis/outputs/persona_v2_analysis_<timestamp>/
├── summary_stats_all_scores.csv          # Main statistics for all 12 scores
├── urban_gate_validation.csv              # Urban gate check results
├── top_10_roads_milemuncher.csv          # Top roads for MileMuncher
├── top_10_roads_cornercraver.csv         # Top roads for CornerCraver
├── top_10_roads_trailblazer.csv          # Top roads for TrailBlazer
├── top_10_roads_tranquiltraveller.csv    # Top roads for TranquilTraveller
├── top_10_roads_all_personas.csv         # Combined top roads
├── score_distribution_by_road_type.csv   # Scores grouped by road type
├── run_metadata.json                      # Run configuration and metadata
└── plots/
    ├── score_urban_gate_histogram.png
    ├── score_cruise_road_histogram.png
    ├── score_offroad_histogram.png
    ├── score_calm_road_histogram.png
    ├── score_flow_histogram.png
    ├── score_remoteness_histogram.png
    ├── score_twist_histogram.png
    ├── score_scenic_histogram.png
    ├── persona_milemuncher_score_histogram.png
    ├── persona_cornercraver_score_histogram.png
    ├── persona_trailblazer_score_histogram.png
    ├── persona_tranquiltraveller_score_histogram.png
    ├── parameter_scores_boxplot.png
    ├── persona_scores_boxplot.png
    ├── all_scores_correlation.png
    ├── persona_scores_correlation.png
    └── persona_by_road_type.png
```

## Usage

### Basic Usage (All India)
```bash
./run_with_venv.sh osm-processing-pipeline/Analysis/persona_v2_analysis.py
```

### Test Region Only
```bash
./run_with_venv.sh osm-processing-pipeline/Analysis/persona_v2_analysis.py --bbox test
```

### Custom Bounding Box
```bash
./run_with_venv.sh osm-processing-pipeline/Analysis/persona_v2_analysis.py \
  --lat-min 12.0 --lat-max 13.0 --lon-min 77.0 --lon-max 78.0
```

### With Additional Filter
```bash
./run_with_venv.sh osm-processing-pipeline/Analysis/persona_v2_analysis.py \
  --where "road_type_i1 IN ('NH', 'SH')"
```

## Dependencies
- pandas
- numpy
- psycopg[binary]
- matplotlib
- seaborn
- python-dotenv

All dependencies should already be in the project's `.venv`.

## Comparison with SQL Validation

| Feature | SQL Script | Python Analysis Script |
|---------|-----------|----------------------|
| Summary Stats | Console output | CSV with all percentiles |
| Histograms | ❌ | ✅ (12 histograms) |
| Boxplots | ❌ | ✅ (2 comparison plots) |
| Correlation | ❌ | ✅ (2 heatmaps) |
| Top Roads | Console output | CSV files |
| Road Type Analysis | Console output | CSV + bar chart |
| Urban Gate Check | Console output | CSV |
| Reusable Output | ❌ | ✅ (All CSVs + plots) |
| Automation | Manual psql | Automated via Python |

## When to Use

- **After running persona scoring**: Validate results and check distributions
- **Comparing runs**: Use timestamped outputs to compare before/after changes
- **Tuning parameters**: Analyze score distributions to adjust TWIST_SAT or formula weights
- **Debugging**: Check top roads per persona to verify scoring logic
- **Reporting**: Generate plots for presentations or documentation

## Notes

- The script uses the same database configuration as the main pipeline (from `.env`)
- All outputs are timestamped to avoid overwriting previous runs
- Plots are saved at 150 DPI for high quality
- The script is safe to run multiple times - each run creates a new output directory
