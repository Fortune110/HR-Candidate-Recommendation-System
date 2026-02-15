#!/usr/bin/env python3
"""
ML Model Evaluation Script
Evaluate a trained model using data from /api/ml/training-examples endpoint.
"""

import argparse
import sys
import json
from pathlib import Path
from datetime import datetime

import pandas as pd
import numpy as np
import requests
import joblib
from sklearn.metrics import accuracy_score, roc_auc_score, roc_curve

# Configuration
DEFAULT_API_URL = "http://localhost:18080"
METRICS_DIR = Path(__file__).parent / "metrics"
METRICS_DIR.mkdir(exist_ok=True)

# Feature columns (must match training script)
FEATURE_COLUMNS = [
    "match_score",
    "overlap_score",
    "gap_penalty",
    "bonus_score",
    "skill_match_count",
    "year_diff",
    "risk_score",
]

# Label column
LABEL_COLUMN = "label"


def load_model(model_path):
    """
    Load model and scaler from disk.
    
    Args:
        model_path: Path to saved model file
    
    Returns:
        tuple: (model, scaler, feature_columns)
    """
    model_path = Path(model_path)
    if not model_path.exists():
        print(f"ERROR: Model file not found: {model_path}")
        sys.exit(1)
    
    try:
        model_data = joblib.load(model_path)
        model = model_data["model"]
        scaler = model_data["scaler"]
        feature_columns = model_data.get("feature_columns", FEATURE_COLUMNS)
        
        print(f"Loaded model from: {model_path}")
        print(f"Model type: {type(model).__name__}")
        print(f"Feature columns: {feature_columns}")
        
        return model, scaler, feature_columns
    except Exception as e:
        print(f"ERROR: Failed to load model: {e}")
        sys.exit(1)


def fetch_evaluation_data(api_url, job_id=None):
    """
    Fetch evaluation data from API endpoint.
    
    Args:
        api_url: Base URL of the API
        job_id: Optional job ID to filter data
    
    Returns:
        pandas.DataFrame: Evaluation data
    
    Raises:
        SystemExit: If API is unavailable or data is empty
    """
    url = f"{api_url}/api/ml/training-examples"
    params = {"format": "csv"}
    if job_id is not None:
        params["jobId"] = job_id
    
    print(f"\nFetching evaluation data from: {url}")
    if job_id:
        print(f"Filter: job_id = {job_id}")
    
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
    except requests.exceptions.ConnectionError:
        print("ERROR: Cannot connect to API. Please ensure the Spring Boot application is running.")
        print(f"       Tried to connect to: {url}")
        sys.exit(1)
    except requests.exceptions.Timeout:
        print("ERROR: API request timed out.")
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"ERROR: API returned error: {e}")
        print(f"       Status code: {response.status_code}")
        sys.exit(1)
    
    # Parse CSV response
    if not response.text.strip():
        print("ERROR: API returned empty data.")
        if job_id:
            print(f"       No evaluation data found for job_id = {job_id}")
        else:
            print("       No evaluation data available.")
        sys.exit(1)
    
    try:
        df = pd.read_csv(pd.io.common.StringIO(response.text))
    except Exception as e:
        print(f"ERROR: Failed to parse CSV response: {e}")
        sys.exit(1)
    
    if df.empty:
        print("ERROR: Evaluation data is empty after parsing.")
        if job_id:
            print(f"       No records found for job_id = {job_id}")
        else:
            print("       No records available in the database.")
        sys.exit(1)
    
    print(f"Fetched {len(df)} evaluation examples")
    return df


def prepare_features(df, feature_columns):
    """
    Prepare features for evaluation.
    
    Args:
        df: DataFrame with evaluation data
        feature_columns: List of feature column names
    
    Returns:
        tuple: (X, y, valid_mask) where X is feature matrix, y is label vector,
               and valid_mask indicates rows with valid labels
    """
    # Check required columns
    missing_cols = set(feature_columns + [LABEL_COLUMN]) - set(df.columns)
    if missing_cols:
        print(f"ERROR: Missing required columns: {missing_cols}")
        sys.exit(1)
    
    # Extract features and label
    X = df[feature_columns].copy()
    y = df[LABEL_COLUMN].copy()
    
    # Handle NULL values in features (fill with 0 for numeric columns)
    X = X.fillna(0)
    
    # Filter out records with NULL labels
    valid_mask = y.notna()
    X_valid = X[valid_mask].copy()
    y_valid = y[valid_mask].copy().astype(int)
    
    if len(X_valid) == 0:
        print("ERROR: No valid evaluation examples (all labels are NULL)")
        sys.exit(1)
    
    print(f"Using {len(X_valid)} examples with valid labels")
    print(f"Label distribution: hired={sum(y_valid == 1)}, rejected={sum(y_valid == 0)}")
    
    return X_valid.values, y_valid.values, valid_mask


def evaluate_model(model, scaler, X, y, feature_columns):
    """
    Evaluate model and compute metrics.
    
    Args:
        model: Trained model
        scaler: Feature scaler
        X: Feature matrix
        y: Label vector
        feature_columns: List of feature column names
    
    Returns:
        dict: Evaluation metrics
    """
    # Scale features
    X_scaled = scaler.transform(X)
    
    # Predict
    y_pred = model.predict(X_scaled)
    y_pred_proba = model.predict_proba(X_scaled)[:, 1] if hasattr(model, "predict_proba") else None
    
    # Compute metrics
    accuracy = accuracy_score(y, y_pred)
    
    metrics = {
        "accuracy": accuracy,
        "num_examples": len(y),
        "num_hired": sum(y == 1),
        "num_rejected": sum(y == 0),
    }
    
    # Compute AUC if probabilities are available
    if y_pred_proba is not None and len(set(y)) > 1:
        try:
            auc = roc_auc_score(y, y_pred_proba)
            metrics["auc"] = auc
        except ValueError:
            metrics["auc"] = None
    else:
        metrics["auc"] = None
    
    return metrics, y_pred_proba


def compute_top_k_metrics(y_true, y_pred_proba, k_values=[10, 20, 50]):
    """
    Compute top-k hit rate metrics.
    
    Args:
        y_true: True labels
        y_pred_proba: Predicted probabilities (for positive class)
        k_values: List of k values to evaluate
    
    Returns:
        dict: Top-k hit rates
    """
    if y_pred_proba is None:
        return {}
    
    top_k_metrics = {}
    
    # Sort by predicted probability (descending)
    sorted_indices = np.argsort(y_pred_proba)[::-1]
    y_true_sorted = y_true[sorted_indices]
    
    for k in k_values:
        if k > len(y_true):
            k = len(y_true)
        
        # Top k candidates
        top_k_labels = y_true_sorted[:k]
        hired_count = sum(top_k_labels == 1)
        hit_rate = hired_count / k if k > 0 else 0.0
        
        top_k_metrics[f"top_{k}_hit_rate"] = hit_rate
        top_k_metrics[f"top_{k}_hired_count"] = hired_count
    
    return top_k_metrics


def save_evaluation_metrics(metrics_dict, model_path):
    """
    Save evaluation metrics to JSON file.
    
    Args:
        metrics_dict: Dictionary of metrics
        model_path: Path to model file
    
    Returns:
        Path: Path to saved metrics file
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    metrics_filename = f"evaluate_{timestamp}.json"
    metrics_path = METRICS_DIR / metrics_filename
    
    metrics_dict["timestamp"] = datetime.now().isoformat()
    metrics_dict["model_path"] = str(model_path)
    
    with open(metrics_path, "w") as f:
        json.dump(metrics_dict, f, indent=2, default=str)
    
    print(f"\nEvaluation metrics saved to: {metrics_path}")
    return metrics_path


def print_metrics(metrics, top_k_metrics):
    """
    Print evaluation metrics.
    
    Args:
        metrics: Basic metrics dict
        top_k_metrics: Top-k metrics dict
    """
    print("\n" + "=" * 60)
    print("Evaluation Results")
    print("=" * 60)
    
    print(f"\nDataset:")
    print(f"  Total examples: {metrics['num_examples']}")
    print(f"  Hired: {metrics['num_hired']}")
    print(f"  Rejected: {metrics['num_rejected']}")
    
    print(f"\nModel Performance:")
    print(f"  Accuracy: {metrics['accuracy']:.4f}")
    if metrics['auc'] is not None:
        print(f"  AUC: {metrics['auc']:.4f}")
    else:
        print(f"  AUC: N/A (requires probabilities and multiple classes)")
    
    if top_k_metrics:
        print(f"\nTop-K Hit Rates (hired candidates in top-k):")
        for k in [10, 20, 50]:
            hit_rate_key = f"top_{k}_hit_rate"
            hired_count_key = f"top_{k}_hired_count"
            if hit_rate_key in top_k_metrics:
                hit_rate = top_k_metrics[hit_rate_key]
                hired_count = top_k_metrics[hired_count_key]
                print(f"  Top {k:2d}: {hit_rate:.2%} ({hired_count}/{k} hired)")
    
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description="Evaluate ML model using data from /api/ml/training-examples endpoint"
    )
    parser.add_argument(
        "--model-path",
        required=True,
        help="Path to saved model file (.joblib)"
    )
    parser.add_argument(
        "--api-url",
        default=DEFAULT_API_URL,
        help=f"API base URL (default: {DEFAULT_API_URL})"
    )
    parser.add_argument(
        "--job-id",
        type=int,
        default=None,
        help="Optional job ID to filter evaluation data"
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("ML Model Evaluation Script")
    print("=" * 60)
    
    # Load model
    model, scaler, feature_columns = load_model(args.model_path)
    
    # Fetch data
    df = fetch_evaluation_data(args.api_url, args.job_id)
    
    # Prepare features
    X, y, valid_mask = prepare_features(df, feature_columns)
    
    # Evaluate model
    metrics, y_pred_proba = evaluate_model(model, scaler, X, y, feature_columns)
    
    # Compute top-k metrics
    top_k_metrics = compute_top_k_metrics(y, y_pred_proba)
    
    # Combine all metrics
    all_metrics = {**metrics, **top_k_metrics}
    all_metrics["job_id"] = args.job_id
    
    # Print results
    print_metrics(metrics, top_k_metrics)
    
    # Save metrics
    model_path_obj = Path(args.model_path)
    save_evaluation_metrics(all_metrics, model_path_obj)


if __name__ == "__main__":
    main()
