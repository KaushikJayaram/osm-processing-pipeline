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


METRIC_COLUMNS = [
    "hill_slope_mean",
    "hill_slope_max",
    "hill_relief_1km",
    "hill_signal_raw",
    "hill_signal_smoothed",
]

FLAG_COLUMNS = [
    "road_scenery_hill",
]


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
        description="Analyze hill scenery metrics distributions and summary stats."
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
    # Test bounds (aligned with existing scripts)
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


def build_query(args, bbox_params):
    base_where = ["bikable_road = TRUE", "geometry IS NOT NULL"]
    if args.bbox != "all" or any(
        v is not None for v in (args.lat_min, args.lat_max, args.lon_min, args.lon_max)
    ):
        base_where.append(
            "geometry && ST_MakeEnvelope(%(lon_min)s, %(lat_min)s, %(lon_max)s, %(lat_max)s, 4326)"
        )
    if args.where:
        base_where.append(f"({args.where})")
    where_sql = " AND ".join(base_where)
    sql = f"""
        SELECT
            osm_id,
            {", ".join(FLAG_COLUMNS + METRIC_COLUMNS)}
        FROM osm_all_roads
        WHERE {where_sql}
    """
    return sql, bbox_params


def summarize_series(series):
    s = series.dropna()
    if s.empty:
        return {
            "count": 0,
            "null_count": int(series.isna().sum()),
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
    quantiles = s.quantile([0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99])
    return {
        "count": int(s.count()),
        "null_count": int(series.isna().sum()),
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


def save_histogram(series, output_path, title, bins=30):
    s = series.dropna()
    if s.empty:
        return False
    s_min = float(np.nanmin(s))
    s_max = float(np.nanmax(s))
    if not np.isfinite(s_min) or not np.isfinite(s_max):
        return False
    if s_min == s_max:
        # No range to bin; skip histogram
        return False
    uniq = int(s.nunique())
    bins = max(1, min(bins, uniq))
    if bins < 2:
        return False
    plt.figure(figsize=(8, 4))
    plt.hist(s, bins=bins, color="#4C78A8", edgecolor="white")
    plt.title(title)
    plt.xlabel("Value")
    plt.ylabel("Count")
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
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

    sql, params = build_query(args, bbox_params)
    logging.info("Executing query for hill scenery metrics...")

    with psycopg.connect(
        dbname=db_config["name"],
        user=db_config["user"],
        password=db_config["password"],
        host=db_config["host"],
        port=db_config["port"],
    ) as conn:
        df = pd.read_sql_query(sql, conn, params=params)

    logging.info("Rows fetched: %s", len(df))

    summary_rows = []
    for col in METRIC_COLUMNS:
        stats = summarize_series(df[col])
        stats["metric"] = col
        summary_rows.append(stats)

        plot_path = os.path.join(plots_dir, f"{col}_hist.png")
        save_histogram(df[col], plot_path, f"{col} distribution")

    summary_df = pd.DataFrame(summary_rows)[
        [
            "metric",
            "count",
            "null_count",
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
    summary_csv = os.path.join(output_dir, "summary_stats.csv")
    summary_df.to_csv(summary_csv, index=False)

    # Road_scenery_hill bucket counts
    flag_counts = df["road_scenery_hill"].value_counts(dropna=False).reset_index()
    flag_counts.columns = ["road_scenery_hill", "count"]
    flag_counts.to_csv(os.path.join(output_dir, "road_scenery_hill_counts.csv"), index=False)

    # Per-metric histogram bin counts
    bucket_rows = []
    for col in METRIC_COLUMNS:
        series = df[col].dropna()
        if series.empty:
            continue
        s_min = float(np.nanmin(series))
        s_max = float(np.nanmax(series))
        if not np.isfinite(s_min) or not np.isfinite(s_max) or s_min == s_max:
            continue
        uniq = int(series.nunique())
        bins = max(1, min(30, uniq))
        if bins < 2:
            continue
        counts, edges = np.histogram(series, bins=bins)
        for i, count in enumerate(counts):
            bucket_rows.append(
                {
                    "metric": col,
                    "bin_start": float(edges[i]),
                    "bin_end": float(edges[i + 1]),
                    "count": int(count),
                }
            )
    if bucket_rows:
        pd.DataFrame(bucket_rows).to_csv(
            os.path.join(output_dir, "metric_histogram_bins.csv"), index=False
        )

    # Save run metadata
    meta = {
        "timestamp": timestamp,
        "output_dir": output_dir,
        "log_file": log_file,
        "row_count": int(len(df)),
        "bbox": {"lat_min": lat_min, "lat_max": lat_max, "lon_min": lon_min, "lon_max": lon_max},
        "where": args.where,
    }
    with open(os.path.join(output_dir, "run_metadata.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)

    logging.info("Outputs written to: %s", output_dir)


if __name__ == "__main__":
    main()
