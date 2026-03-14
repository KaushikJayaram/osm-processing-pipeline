#!/usr/bin/env python3

import argparse
import json
import logging
import os
from datetime import datetime

import numpy as np
import pandas as pd
import psycopg
import matplotlib
from dotenv import load_dotenv

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns

# Set style for better looking plots
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (10, 6)

# Column definitions
PARAMETER_COLUMNS = [
    "score_urban_gate",
    "score_cruise_road",
    "score_offroad",
    "score_calm_road",
    "score_flow",
    "score_remoteness",
    "score_twist",
    # Scenic v2.1 (persona-specific)
    "score_scenic_wild",
    "score_scenic_serene",
    "score_scenic_fast",
]

PERSONA_COLUMNS = [
    "persona_milemuncher_score",
    "persona_cornercraver_score",
    "persona_trailblazer_score",
    "persona_tranquiltraveller_score",
]

NORMALISED_PERSONA_COLUMNS = [
    "persona_milemuncher_score_normalised",
    "persona_cornercraver_score_normalised",
    "persona_trailblazer_score_normalised",
    "persona_tranquiltraveller_score_normalised",
]

# Raw inputs used by parameter calculations (keep mostly numeric; categoricals like road_type_i1
# are covered by score_distribution_by_road_type.csv).
INPUT_FEATURE_COLUMNS = [
    # Urban / setting
    "road_scenery_urban",
    "road_scenery_semiurban",

    # Cruise/offroad/calm
    "fourlane",  # will derive numeric fourlane_is_yes in pandas

    # Flow
    "intersection_speed_degradation_final",

    # Remoteness
    "reinforced_pressure",

    # Twist
    "twistiness_score",
    "road_scenery_hill",

    # Scenic inputs
    "scenery_v2_confidence",
    "wc_forest_frac",
    "wc_field_frac",
    "road_scenery_river",
    "road_scenery_lake",
]

ALL_SCORE_COLUMNS = PARAMETER_COLUMNS + PERSONA_COLUMNS + NORMALISED_PERSONA_COLUMNS
ALL_ANALYSIS_COLUMNS = ALL_SCORE_COLUMNS + INPUT_FEATURE_COLUMNS

# Grouping: parameter -> inputs (numeric where possible).
# Note: we use derived "fourlane_is_yes" instead of string "fourlane".
PARAMETER_INPUTS_MAP = {
    "score_urban_gate": ["road_scenery_urban"],
    "score_cruise_road": ["fourlane_is_yes"],
    "score_offroad": ["fourlane_is_yes", "road_scenery_semiurban"],
    "score_calm_road": ["fourlane_is_yes", "road_scenery_semiurban"],
    "score_flow": ["intersection_speed_degradation_final"],
    "score_remoteness": ["reinforced_pressure"],
    "score_twist": ["twistiness_score", "road_scenery_hill"],
    "score_scenic_wild": [
        "scenery_v2_confidence",
        "wc_forest_frac",
        "wc_field_frac",
        "road_scenery_hill",
        "road_scenery_river",
        "road_scenery_lake",
    ],
    "score_scenic_serene": [
        "scenery_v2_confidence",
        "wc_forest_frac",
        "wc_field_frac",
        "road_scenery_hill",
        "road_scenery_river",
        "road_scenery_lake",
    ],
    "score_scenic_fast": [
        "scenery_v2_confidence",
        "wc_forest_frac",
        "road_scenery_hill",
        "road_scenery_river",
        "road_scenery_lake",
    ],
}


def get_base_dir():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def setup_logging(base_dir, script_name):
    log_dir = os.path.join(base_dir, "logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"{script_name}_{timestamp}.log")
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[logging.FileHandler(log_file, encoding="utf-8"), logging.StreamHandler()],
    )
    logging.info("Logging initialized. Log file: %s", log_file)
    return log_file


def parse_args():
    parser = argparse.ArgumentParser(
        description="Analyze Persona V2 score distributions and validation."
    )
    parser.add_argument(
        "--bbox",
        choices=["all", "test"],
        default="all",
        help="Optional bounding box filter (default: all).",
    )
    parser.add_argument("--lat-min", type=float, help="Override LAT_MIN.")
    parser.add_argument("--lat-max", type=float, help="Override LAT_MAX.")
    parser.add_argument("--lon-min", type=float, help="Override LON_MIN.")
    parser.add_argument("--lon-max", type=float, help="Override LON_MAX.")
    parser.add_argument(
        "--where",
        type=str,
        default=None,
        help="Additional SQL WHERE clause (without 'WHERE').",
    )
    return parser.parse_args()


def resolve_bbox(args):
    # Default bounds (all India)
    lat_min, lat_max, lon_min, lon_max = 6.5, 35.5, 68.0, 97.5
    # Test bounds
    if args.bbox == "test":
        lat_min, lat_max, lon_min, lon_max = 12.0, 15.0, 75.0, 79.0
    if args.lat_min is not None:
        lat_min = args.lat_min
    if args.lat_max is not None:
        lat_max = args.lat_max
    if args.lon_min is not None:
        lon_min = args.lon_min
    if args.lon_max is not None:
        lon_max = args.lon_max
    return lat_min, lat_max, lon_min, lon_max


def build_base_where(args, bbox_params):
    base_where = ["bikable_road = TRUE"]
    if args.bbox != "all" or any(
        v is not None for v in (args.lat_min, args.lat_max, args.lon_min, args.lon_max)
    ):
        base_where.append(
            "geometry && ST_MakeEnvelope(%(lon_min)s, %(lat_min)s, %(lon_max)s, %(lat_max)s, 4326)"
        )
    if args.where:
        base_where.append(f"({args.where})")
    return " AND ".join(base_where)


def weighted_quantile(values, weights, quantiles):
    """Calculate weighted quantiles."""
    # Sort by values
    sorter = np.argsort(values)
    values_sorted = values[sorter]
    weights_sorted = weights[sorter]
    
    # Compute cumulative weights
    weighted_quantiles_sum = np.cumsum(weights_sorted)
    weighted_quantiles_sum -= weighted_quantiles_sum[0]
    weighted_quantiles_sum /= weighted_quantiles_sum[-1]
    
    # Interpolate to find quantiles
    return np.interp(quantiles, weighted_quantiles_sum, values_sorted)


def summarize_series(series, weights=None):
    """Generate comprehensive statistics for a series.
    
    Args:
        series: pandas Series of values
        weights: pandas Series of weights (e.g., length_geom_3857). If None, uses equal weights.
    """
    # Remove NaN from both series and weights
    valid_mask = series.notna()
    s = series[valid_mask]
    
    if s.empty:
        return {
            "total_distance_km": 0.0,
            "road_count": 0,
            "null_count": int(series.isna().sum()),
            "high_score_distance_km": 0.0,
            "high_score_pct": 0.0,
            "mean": np.nan,
            "median": np.nan,
            "std": np.nan,
            "min": np.nan,
            "max": np.nan,
            "p5": np.nan,
            "p10": np.nan,
            "p25": np.nan,
            "p50": np.nan,
            "p75": np.nan,
            "p90": np.nan,
            "p95": np.nan,
            "p99": np.nan,
        }
    
    if weights is not None:
        w = weights[valid_mask]
        w = w.fillna(0)  # Handle any NaN weights
        
        # Convert to numpy for calculations
        values = s.values
        weight_values = w.values
        
        # Remove zero or negative weights
        positive_weights = weight_values > 0
        if not np.any(positive_weights):
            # Fall back to unweighted if no valid weights
            weight_values = np.ones_like(values)
            positive_weights = np.ones_like(values, dtype=bool)
        
        values = values[positive_weights]
        weight_values = weight_values[positive_weights]
        
        total_weight = np.sum(weight_values)
        
        # Calculate high score (>0.7) distance
        high_score_mask = values > 0.7
        high_score_weight = np.sum(weight_values[high_score_mask])
        high_score_distance_km = float(high_score_weight / 1000)
        high_score_pct = float((high_score_weight / total_weight * 100) if total_weight > 0 else 0.0)
        
        # Weighted statistics
        weighted_mean = np.sum(values * weight_values) / total_weight
        weighted_variance = np.sum(weight_values * (values - weighted_mean) ** 2) / total_weight
        weighted_std = np.sqrt(weighted_variance)
        
        # Weighted quantiles
        quantile_values = [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99]
        quantile_results = weighted_quantile(values, weight_values, quantile_values)
        
        return {
            "total_distance_km": float(total_weight / 1000),  # Convert meters to km
            "road_count": int(len(values)),
            "null_count": int(series.isna().sum()),
            "high_score_distance_km": high_score_distance_km,
            "high_score_pct": high_score_pct,
            "mean": float(weighted_mean),
            "median": float(quantile_results[3]),  # p50
            "std": float(weighted_std),
            "min": float(np.min(values)),
            "max": float(np.max(values)),
            "p5": float(quantile_results[0]),
            "p10": float(quantile_results[1]),
            "p25": float(quantile_results[2]),
            "p50": float(quantile_results[3]),
            "p75": float(quantile_results[4]),
            "p90": float(quantile_results[5]),
            "p95": float(quantile_results[6]),
            "p99": float(quantile_results[7]),
        }
    else:
        # Unweighted statistics (original behavior)
        quantiles = s.quantile([0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99])
        return {
            "total_distance_km": 0.0,  # Not applicable for unweighted
            "road_count": int(s.count()),
            "null_count": int(series.isna().sum()),
            "high_score_distance_km": 0.0,
            "high_score_pct": 0.0,
            "mean": float(s.mean()),
            "median": float(s.median()),
            "std": float(s.std(ddof=1)) if s.count() > 1 else 0.0,
            "min": float(s.min()),
            "max": float(s.max()),
            "p5": float(quantiles.loc[0.05]),
            "p10": float(quantiles.loc[0.10]),
            "p25": float(quantiles.loc[0.25]),
            "p50": float(quantiles.loc[0.50]),
            "p75": float(quantiles.loc[0.75]),
            "p90": float(quantiles.loc[0.90]),
            "p95": float(quantiles.loc[0.95]),
            "p99": float(quantiles.loc[0.99]),
        }


def save_histogram(series, output_path, title, bins=50, color="#4C78A8"):
    """Save histogram for a score distribution."""
    s = series.dropna()
    if s.empty:
        logging.warning(f"Skipping histogram for {title} - no data")
        return False
    s_min = float(np.nanmin(s))
    s_max = float(np.nanmax(s))
    if not np.isfinite(s_min) or not np.isfinite(s_max):
        return False
    if s_min == s_max:
        return False
    uniq = int(s.nunique())
    bins = max(1, min(bins, uniq))
    if bins < 2:
        return False
    
    plt.figure(figsize=(10, 6))
    plt.hist(s, bins=bins, color=color, edgecolor="white", alpha=0.7)
    plt.title(title, fontsize=14, fontweight='bold')
    plt.xlabel("Score Value", fontsize=12)
    plt.ylabel("Frequency", fontsize=12)
    plt.grid(axis='y', alpha=0.3)
    
    # Add statistics text box
    stats_text = f"Mean: {s.mean():.4f}\nMedian: {s.median():.4f}\nStd: {s.std():.4f}"
    plt.text(0.02, 0.98, stats_text, transform=plt.gca().transAxes,
             verticalalignment='top', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5),
             fontsize=10)
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    return True


def save_boxplot(df, columns, output_path, title):
    """Save boxplot comparing multiple scores."""
    data_to_plot = []
    labels = []
    for col in columns:
        s = df[col].dropna()
        if not s.empty:
            data_to_plot.append(s)
            # Clean up column name for display
            label = col.replace("score_", "").replace("persona_", "").replace("_score", "").replace("_", " ").title()
            labels.append(label)
    
    if not data_to_plot:
        return False
    
    plt.figure(figsize=(12, 6))
    bp = plt.boxplot(data_to_plot, tick_labels=labels, patch_artist=True)
    
    # Color the boxes
    colors = plt.cm.Set3(range(len(data_to_plot)))
    for patch, color in zip(bp['boxes'], colors):
        patch.set_facecolor(color)
    
    plt.title(title, fontsize=14, fontweight='bold')
    plt.ylabel("Score Value", fontsize=12)
    plt.xticks(rotation=45, ha='right')
    plt.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    return True


def save_correlation_heatmap(df, columns, output_path, title):
    """Save correlation heatmap for scores."""
    corr_data = df[columns].corr()
    
    plt.figure(figsize=(10, 8))
    sns.heatmap(corr_data, annot=True, fmt=".2f", cmap="RdYlGn", center=0,
                square=True, linewidths=1, cbar_kws={"shrink": 0.8})
    
    # Clean up labels
    clean_labels = [col.replace("score_", "").replace("persona_", "").replace("_score", "").replace("_", " ").title() 
                    for col in columns]
    plt.xticks(range(len(columns)), clean_labels, rotation=45, ha='right')
    plt.yticks(range(len(columns)), clean_labels, rotation=0)
    
    plt.title(title, fontsize=14, fontweight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    return True


def save_persona_comparison_by_road_type(df, output_path):
    """Save bar chart comparing persona scores by road type."""
    road_type_stats = df.groupby('road_type_i1')[PERSONA_COLUMNS].mean().reset_index()
    road_type_stats = road_type_stats.sort_values('persona_milemuncher_score', ascending=False).head(10)
    
    if road_type_stats.empty:
        return False
    
    fig, ax = plt.subplots(figsize=(12, 6))
    x = np.arange(len(road_type_stats))
    width = 0.2
    
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    labels = ['MileMuncher', 'CornerCraver', 'TrailBlazer', 'TranquilTraveller']
    
    for i, (col, color, label) in enumerate(zip(PERSONA_COLUMNS, colors, labels)):
        offset = width * (i - 1.5)
        ax.bar(x + offset, road_type_stats[col], width, label=label, color=color, alpha=0.8)
    
    ax.set_xlabel('Road Type', fontsize=12)
    ax.set_ylabel('Average Persona Score', fontsize=12)
    ax.set_title('Average Persona Scores by Road Type (Top 10)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(road_type_stats['road_type_i1'], rotation=45, ha='right')
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()
    return True


def main():
    args = parse_args()
    base_dir = get_base_dir()
    script_name = os.path.splitext(os.path.basename(__file__))[0]
    log_file = setup_logging(base_dir, script_name)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(base_dir, "Analysis", "outputs", f"{script_name}_{timestamp}")
    os.makedirs(output_dir, exist_ok=True)
    plots_dir = os.path.join(output_dir, "plots")
    os.makedirs(plots_dir, exist_ok=True)

    load_dotenv(override=True)

    lat_min, lat_max, lon_min, lon_max = resolve_bbox(args)
    bbox_params = {
        "lat_min": lat_min,
        "lat_max": lat_max,
        "lon_min": lon_min,
        "lon_max": lon_max,
    }

    db_config = {
        "host": os.getenv("DB_HOST", "localhost"),
        "name": os.getenv("DB_NAME"),
        "user": os.getenv("DB_USER"),
        "password": os.getenv("DB_PASSWORD"),
        "port": int(os.getenv("DB_PORT", "5432")),
    }
    for key in ("name", "user", "password"):
        if not db_config.get(key):
            raise RuntimeError(f"Missing required DB config: {key}")

    where_sql = build_base_where(args, bbox_params)

    # ========================================================================
    # QUERY 1: Main scores data
    # ========================================================================
    logging.info("Fetching main score data...")
    main_query = f"""
        SELECT
            osm_id,
            name,
            road_type_i1,
            length_geom_3857,
            {", ".join(ALL_ANALYSIS_COLUMNS)}
        FROM osm_all_roads
        WHERE {where_sql}
    """
    
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        df = pd.read_sql_query(main_query, conn, params=bbox_params)

    logging.info("Rows fetched: %s", len(df))

    # ========================================================================
    # QUERY 2: Persona distance-weighted percentiles by (road_type_i1, fourlane, road_setting_i1)
    # ========================================================================
    # This matches the provided SQL pattern, but respects the same bbox + optional --where filter.
    def build_persona_group_percentiles_query(prefix: str, raw_col: str, norm_col: str) -> str:
        # NOTE: raw_col/norm_col are hardcoded column names (not user input), safe to format.
        return f"""
            WITH base AS (
              SELECT
                COALESCE(road_type_i1, 'UNKNOWN')    AS road_type_i1,
                COALESCE(fourlane, 'no')             AS fourlane,
                COALESCE(road_setting_i1, 'UNKNOWN') AS road_setting_i1,

                (GREATEST(COALESCE(length_geom_3857, 0.0), 0.0) / 1000.0) AS len_km,

                {raw_col}  AS {prefix},
                {norm_col} AS {prefix}_n

              FROM osm_all_roads
              WHERE {where_sql}
                AND geometry IS NOT NULL
                AND length_geom_3857 IS NOT NULL
                AND length_geom_3857 > 0
            ),
            ranked AS (
              SELECT
                *,
                SUM(len_km) OVER (PARTITION BY road_type_i1, fourlane, road_setting_i1) AS total_km,
                SUM(len_km) OVER (
                  PARTITION BY road_type_i1, fourlane, road_setting_i1
                  ORDER BY {prefix}
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS cum_km_raw,
                SUM(len_km) OVER (
                  PARTITION BY road_type_i1, fourlane, road_setting_i1
                  ORDER BY {prefix}_n
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ) AS cum_km_norm
              FROM base
            )
            SELECT
              road_type_i1,
              fourlane,
              road_setting_i1,
              COUNT(*) AS road_count,
              SUM(len_km) AS total_km,

              -- -------- raw (weighted percentiles) ----------
              MIN({prefix}) FILTER (WHERE cum_km_raw >= 0.05 * total_km) AS {prefix}_wp05,
              MIN({prefix}) FILTER (WHERE cum_km_raw >= 0.25 * total_km) AS {prefix}_wp25,
              MIN({prefix}) FILTER (WHERE cum_km_raw >= 0.50 * total_km) AS {prefix}_wmedian,
              MIN({prefix}) FILTER (WHERE cum_km_raw >= 0.75 * total_km) AS {prefix}_wp75,
              MIN({prefix}) FILTER (WHERE cum_km_raw >= 0.90 * total_km) AS {prefix}_wp90,
              MIN({prefix}) FILTER (WHERE cum_km_raw >= 0.95 * total_km) AS {prefix}_wp95,

              -- -------- normalised (weighted percentiles) ----------
              MIN({prefix}_n) FILTER (WHERE cum_km_norm >= 0.05 * total_km) AS {prefix}_n_wp05,
              MIN({prefix}_n) FILTER (WHERE cum_km_norm >= 0.25 * total_km) AS {prefix}_n_wp25,
              MIN({prefix}_n) FILTER (WHERE cum_km_norm >= 0.50 * total_km) AS {prefix}_n_wmedian,
              MIN({prefix}_n) FILTER (WHERE cum_km_norm >= 0.75 * total_km) AS {prefix}_n_wp75,
              MIN({prefix}_n) FILTER (WHERE cum_km_norm >= 0.90 * total_km) AS {prefix}_n_wp90,
              MIN({prefix}_n) FILTER (WHERE cum_km_norm >= 0.95 * total_km) AS {prefix}_n_wp95

            FROM ranked
            GROUP BY 1,2,3
            ORDER BY 1,2,3;
        """

    persona_specs = [
        ("mm", "persona_milemuncher_score", "persona_milemuncher_score_normalised"),
        ("cc", "persona_cornercraver_score", "persona_cornercraver_score_normalised"),
        ("tb", "persona_trailblazer_score", "persona_trailblazer_score_normalised"),
        ("tt", "persona_tranquiltraveller_score", "persona_tranquiltraveller_score_normalised"),
    ]

    weighted_percentiles_csvs = {}
    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        for prefix, raw_col, norm_col in persona_specs:
            logging.info(
                "Computing %s (raw + normalised) distance-weighted percentiles by group...",
                prefix.upper(),
            )
            q = build_persona_group_percentiles_query(prefix, raw_col, norm_col)
            out_df = pd.read_sql_query(q, conn, params=bbox_params)
            out_csv = os.path.join(
                output_dir,
                f\"{prefix}_weighted_percentiles_by_roadtype_fourlane_setting.csv\",
            )
            out_df.to_csv(out_csv, index=False)
            weighted_percentiles_csvs[prefix] = out_csv
            logging.info("%s weighted percentiles saved to: %s", prefix.upper(), out_csv)

    # ------------------------------------------------------------------------
    # Derive/clean raw inputs used in parameter computations
    # ------------------------------------------------------------------------
    # fourlane is stored as yes/no; create numeric helper for summaries.
    if "fourlane" in df.columns:
        df["fourlane_is_yes"] = (df["fourlane"].fillna("no") == "yes").astype(float)
    else:
        df["fourlane_is_yes"] = np.nan

    # Ensure boolean-ish scenery flags are numeric 0/1 for weighted stats.
    for flag_col in ("road_scenery_urban", "road_scenery_semiurban", "road_scenery_hill", "road_scenery_river", "road_scenery_lake"):
        if flag_col in df.columns:
            df[flag_col] = df[flag_col].fillna(0).astype(float)

    # ========================================================================
    # ANALYSIS 1: Summary statistics for all scores (distance-weighted)
    # ========================================================================
    logging.info("Computing distance-weighted summary statistics...")
    summary_rows = []
    
    # Use length_geom_3857 as weights
    weights = df['length_geom_3857']
    
    def add_summary(
        col_name: str,
        kind: str,
        *,
        group_name: str,
        item_role: str,
        used_for: str,
        sort_order: int,
    ):
        if col_name in df.columns:
            stats = summarize_series(df[col_name], weights=weights)
            stats["score_type"] = kind
            stats["score_name"] = col_name
            stats["group_name"] = group_name
            stats["item_role"] = item_role
            stats["used_for"] = used_for
            stats["sort_order"] = sort_order
            summary_rows.append(stats)

    # Grouped stats in requested order:
    # <inputs for parameter> ... <parameter> ... then persona raw, then persona normalised
    order = 0

    for param_col in PARAMETER_COLUMNS:
        group = f"parameter::{param_col}"
        inputs = PARAMETER_INPUTS_MAP.get(param_col, [])

        for inp in inputs:
            order += 1
            add_summary(
                inp,
                "parameter_input",
                group_name=group,
                item_role="input",
                used_for=param_col,
                sort_order=order,
            )

        order += 1
        add_summary(
            param_col,
            "parameter",
            group_name=group,
            item_role="parameter",
            used_for=param_col,
            sort_order=order,
        )

    group_raw = "persona_raw"
    for col in PERSONA_COLUMNS:
        order += 1
        add_summary(
            col,
            "persona_raw",
            group_name=group_raw,
            item_role="persona_raw",
            used_for=group_raw,
            sort_order=order,
        )

    group_norm = "persona_normalised"
    for col in NORMALISED_PERSONA_COLUMNS:
        order += 1
        add_summary(
            col,
            "persona_normalised",
            group_name=group_norm,
            item_role="persona_normalised",
            used_for=group_norm,
            sort_order=order,
        )
    
    summary_df = pd.DataFrame(summary_rows).sort_values(["sort_order", "score_name"])[
        [
            "group_name",
            "item_role",
            "used_for",
            "score_type",
            "score_name",
            "sort_order",
            "total_distance_km",
            "road_count",
            "null_count",
            "high_score_distance_km",
            "high_score_pct",
            "mean",
            "median",
            "std",
            "min",
            "max",
            "p5",
            "p10",
            "p25",
            "p50",
            "p75",
            "p90",
            "p95",
            "p99",
        ]
    ]
    summary_csv = os.path.join(output_dir, "summary_stats_all_scores.csv")
    summary_df.to_csv(summary_csv, index=False)
    logging.info("Summary statistics saved to: %s", summary_csv)

    # ========================================================================
    # ANALYSIS 2: Urban gate validation
    # ========================================================================
    logging.info("Validating urban gate...")
    urban_roads = df[df['road_scenery_urban'] == 1]
    urban_violations = {
        'urban_roads_count': int(len(urban_roads)),
        'mm_violations': int((urban_roads['persona_milemuncher_score'] > 0).sum()),
        'cc_violations': int((urban_roads['persona_cornercraver_score'] > 0).sum()),
        'tb_violations': int((urban_roads['persona_trailblazer_score'] > 0).sum()),
        'tt_violations': int((urban_roads['persona_tranquiltraveller_score'] > 0).sum()),
    }
    # Normalised scores should also be 0 in urban (if raw is 0 and global min is >= 0)
    for norm_col in NORMALISED_PERSONA_COLUMNS:
        if norm_col in urban_roads.columns:
            urban_violations[f"{norm_col}_violations"] = int((urban_roads[norm_col] > 0).sum())
    urban_validation_df = pd.DataFrame([urban_violations])
    urban_validation_df.to_csv(os.path.join(output_dir, "urban_gate_validation.csv"), index=False)
    logging.info("Urban gate validation: %s", urban_violations)

    # ========================================================================
    # ANALYSIS 3: Top roads per persona
    # ========================================================================
    logging.info("Finding top roads per persona...")
    top_roads_data = {}
    for persona_col in PERSONA_COLUMNS:
        if persona_col in df.columns:
            persona_name = persona_col.replace("persona_", "").replace("_score", "")
            top_roads = df.nlargest(10, persona_col)[
                ['osm_id', 'name', 'road_type_i1'] + ALL_ANALYSIS_COLUMNS
            ].copy()
            top_roads['persona'] = persona_name
            top_roads_data[persona_name] = top_roads
            
            # Save individual CSV
            top_roads.to_csv(os.path.join(output_dir, f"top_10_roads_{persona_name}.csv"), index=False)
    
    # Combined top roads
    if top_roads_data:
        combined_top = pd.concat(top_roads_data.values(), ignore_index=True)
        combined_top.to_csv(os.path.join(output_dir, "top_10_roads_all_personas.csv"), index=False)

    # ========================================================================
    # ANALYSIS 4: Score distribution by road type
    # ========================================================================
    logging.info("Analyzing distribution by road type...")
    road_type_dist = df.groupby('road_type_i1').agg({
        'osm_id': 'count',
        **{col: 'mean' for col in ALL_SCORE_COLUMNS if col in df.columns}
    }).reset_index()
    road_type_dist.columns = ['road_type_i1', 'count'] + [
        col for col in ALL_SCORE_COLUMNS if col in df.columns
    ]
    road_type_dist = road_type_dist.sort_values('count', ascending=False)
    road_type_dist.to_csv(os.path.join(output_dir, "score_distribution_by_road_type.csv"), index=False)

    # ========================================================================
    # VISUALIZATIONS
    # ========================================================================
    logging.info("Generating visualizations...")
    
    # 1. Individual histograms for parameter scores
    for col in PARAMETER_COLUMNS:
        if col in df.columns:
            col_name = col.replace("score_", "").replace("_", " ").title()
            save_histogram(
                df[col],
                os.path.join(plots_dir, f"{col}_histogram.png"),
                f"Distribution: {col_name}",
                bins=50,
                color="#4C78A8"
            )
    
    # 2. Individual histograms for persona scores
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    for col, color in zip(PERSONA_COLUMNS, colors):
        if col in df.columns:
            col_name = col.replace("persona_", "").replace("_score", "").title()
            save_histogram(
                df[col],
                os.path.join(plots_dir, f"{col}_histogram.png"),
                f"Distribution: {col_name} Persona",
                bins=50,
                color=color
            )

    # 2b. Individual histograms for normalised persona scores
    for col, color in zip(NORMALISED_PERSONA_COLUMNS, colors):
        if col in df.columns:
            col_name = col.replace("persona_", "").replace("_score_normalised", "").replace("_", " ").title()
            save_histogram(
                df[col],
                os.path.join(plots_dir, f"{col}_histogram.png"),
                f"Distribution: {col_name} Persona (Normalised)",
                bins=50,
                color=color
            )
    
    # 3. Boxplot comparison - parameter scores
    save_boxplot(
        df,
        PARAMETER_COLUMNS,
        os.path.join(plots_dir, "parameter_scores_boxplot.png"),
        "Parameter Scores Comparison"
    )
    
    # 4. Boxplot comparison - persona scores
    save_boxplot(
        df,
        PERSONA_COLUMNS,
        os.path.join(plots_dir, "persona_scores_boxplot.png"),
        "Persona Scores Comparison"
    )

    # 4b. Boxplot comparison - normalised persona scores
    save_boxplot(
        df,
        NORMALISED_PERSONA_COLUMNS,
        os.path.join(plots_dir, "persona_scores_normalised_boxplot.png"),
        "Persona Scores Comparison (Normalised)"
    )
    
    # 5. Correlation heatmap - all scores
    save_correlation_heatmap(
        df,
        ALL_SCORE_COLUMNS,
        os.path.join(plots_dir, "all_scores_correlation.png"),
        "Correlation Heatmap: All Scores"
    )
    
    # 6. Correlation heatmap - persona scores only
    save_correlation_heatmap(
        df,
        PERSONA_COLUMNS,
        os.path.join(plots_dir, "persona_scores_correlation.png"),
        "Correlation Heatmap: Persona Scores"
    )
    
    # 7. Persona comparison by road type
    save_persona_comparison_by_road_type(
        df,
        os.path.join(plots_dir, "persona_by_road_type.png")
    )

    # ========================================================================
    # Save run metadata
    # ========================================================================
    meta = {
        "timestamp": timestamp,
        "output_dir": output_dir,
        "log_file": log_file,
        "row_count": int(len(df)),
        "bbox": {"lat_min": lat_min, "lat_max": lat_max, "lon_min": lon_min, "lon_max": lon_max},
        "where": args.where,
        "parameter_scores": PARAMETER_COLUMNS,
        "persona_scores": PERSONA_COLUMNS,
        "persona_scores_normalised": NORMALISED_PERSONA_COLUMNS,
        "input_features": INPUT_FEATURE_COLUMNS,
        "parameter_inputs_map": PARAMETER_INPUTS_MAP,
        "urban_gate_validation": urban_violations,
        "outputs": {
            "summary_stats_all_scores_csv": summary_csv,
            "weighted_percentiles_by_group_csvs": weighted_percentiles_csvs,
        },
    }
    with open(os.path.join(output_dir, "run_metadata.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)

    logging.info("=" * 80)
    logging.info("Analysis complete!")
    logging.info("Outputs written to: %s", output_dir)
    logging.info("Summary statistics: %s", summary_csv)
    logging.info("Plots directory: %s", plots_dir)
    logging.info("=" * 80)


if __name__ == "__main__":
    main()
