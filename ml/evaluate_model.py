#!/usr/bin/env python3
"""
Evaluate a trained model on test data.

Usage:
    python ml/evaluate_model.py <model_path> [--job-id JOB_ID] [--api-url API_URL]

Example:
    python ml/evaluate_model.py ml/models/model_logistic_20240111_120000.joblib
    python ml/evaluate_model.py ml/models/model_logistic_20240111_120000.joblib --job-id 123
"""

import argparse
import sys
import os
from datetime import datetime
from typing import Optional
import pandas as pd
import numpy as np
from sklearn.metrics import accuracy_score, roc_auc_score, roc_curve
import joblib

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.http_client import fetch_training_data, APIError, validate_data
from ml.features import prepare_data


def print_banner(title: str):
    """Print a formatted banner."""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70 + "\n")


def print_section(title: str):
    """Print a section header."""
    print(f"\n[{title}]")
    print("-" * 70)


def load_model(model_path: str) -> dict:
    """
    Load model and scaler from file.
    
    Args:
        model_path: Path to the saved model file
        
    Returns:
        Dictionary containing model, scaler, and metadata
        
    Raises:
        FileNotFoundError: If model file doesn't exist
        ValueError: If model file is invalid
    """
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found: {model_path}")
    
    try:
        model_data = joblib.load(model_path)
        if not isinstance(model_data, dict):
            raise ValueError("Invalid model file format: expected dictionary")
        
        if 'model' not in model_data or 'scaler' not in model_data:
            raise ValueError("Invalid model file: missing 'model' or 'scaler'")
        
        return model_data
    except Exception as e:
        raise ValueError(f"Failed to load model: {str(e)}") from e


def compute_top_k_metrics(y_true: np.ndarray, y_pred_proba: np.ndarray, k_values: list = [10, 20, 50]) -> dict:
    """
    Compute top-k hit rate metrics.
    
    Top-k hit rate: percentage of positive samples (label=1, i.e., HIRED) 
    in the top-k predictions ranked by probability.
    
    Args:
        y_true: True labels (0 or 1)
        y_pred_proba: Predicted probabilities for class 1
        k_values: List of k values to compute metrics for
        
    Returns:
        Dictionary with top-k metrics
    """
    # Sort by predicted probability (descending)
    sorted_indices = np.argsort(y_pred_proba)[::-1]
    y_true_sorted = y_true[sorted_indices]
    
    metrics = {}
    total_positive = np.sum(y_true == 1)
    
    if total_positive == 0:
        # No positive samples, return None for all metrics
        for k in k_values:
            metrics[f'top_{k}_hit_rate'] = None
        return metrics
    
    for k in k_values:
        if k > len(y_true):
            k = len(y_true)
        
        top_k_indices = sorted_indices[:k]
        top_k_positive = np.sum(y_true[top_k_indices] == 1)
        hit_rate = top_k_positive / k
        recall_at_k = top_k_positive / total_positive if total_positive > 0 else 0.0
        
        metrics[f'top_{k}_hit_rate'] = hit_rate
        metrics[f'top_{k}_recall'] = recall_at_k
    
    return metrics


def evaluate_model(
    model_path: str,
    api_url: str = "http://localhost:18080",
    job_id: Optional[int] = None
) -> None:
    """
    Evaluate a trained model on test data.
    
    Args:
        model_path: Path to the saved model file
        api_url: Base URL of the API
        job_id: Optional job ID to filter data
    """
    print_banner("ML Model Evaluation")
    
    # Step 1: Load model
    print_section("Step 1: Loading Model")
    try:
        model_data = load_model(model_path)
        model = model_data['model']
        scaler = model_data['scaler']
        feature_columns = model_data.get('feature_columns', [])
        timestamp = model_data.get('timestamp', 'unknown')
        print(f"✓ Model loaded from: {model_path}")
        print(f"  Model type: {type(model).__name__}")
        if timestamp != 'unknown':
            print(f"  Training timestamp: {timestamp}")
        if feature_columns:
            print(f"  Features: {len(feature_columns)} features")
    except (FileNotFoundError, ValueError) as e:
        print(f"✗ Error loading model: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 2: Fetch evaluation data
    print_section("Step 2: Fetching Evaluation Data")
    print(f"API URL: {api_url}")
    if job_id:
        print(f"Job ID filter: {job_id}")
    else:
        print("Job ID filter: None (all jobs)")
    
    try:
        data = fetch_training_data(api_url=api_url, job_id=job_id, format="json")
        validate_data(data)
        print(f"✓ Fetched {len(data)} examples from API")
    except (APIError, ValueError) as e:
        print(f"✗ Error fetching data: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 3: Convert to DataFrame
    print_section("Step 3: Processing Data")
    try:
        df = pd.DataFrame(data)
        print(f"✓ Converted to DataFrame: {len(df)} rows, {len(df.columns)} columns")
    except Exception as e:
        print(f"✗ Error converting to DataFrame: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 4: Extract features and labels
    print_section("Step 4: Extracting Features and Labels")
    try:
        X, y = prepare_data(df)
        print(f"✓ Extracted features: {X.shape[1]} features, {len(X)} valid examples")
        
        # Check label distribution
        label_counts = y.value_counts()
        print(f"✓ Label distribution:")
        for label_val, count in label_counts.items():
            label_name = "HIRED" if label_val == 1 else "REJECTED"
            print(f"    {label_name} (label={label_val}): {count} examples ({100*count/len(y):.1f}%)")
        
        # Validate we have both classes
        if len(label_counts) < 2:
            print(f"✗ Error: Only one class found in labels. Need both HIRED and REJECTED.", file=sys.stderr)
            print(f"  Found classes: {label_counts.index.tolist()}", file=sys.stderr)
            sys.exit(1)
        
    except ValueError as e:
        print(f"✗ Error preparing data: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 5: Scale features and make predictions
    print_section("Step 5: Making Predictions")
    try:
        X_scaled = scaler.transform(X)
        y_pred = model.predict(X_scaled)
        y_pred_proba = model.predict_proba(X_scaled)[:, 1]  # Probability of class 1
        print(f"✓ Predictions generated for {len(X)} examples")
    except Exception as e:
        print(f"✗ Error making predictions: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 6: Compute metrics
    print_section("Step 6: Computing Metrics")
    accuracy = accuracy_score(y, y_pred)
    print(f"✓ Accuracy: {accuracy:.4f} ({100*accuracy:.2f}%)")
    
    try:
        auc = roc_auc_score(y, y_pred_proba)
        print(f"✓ AUC (ROC): {auc:.4f}")
    except ValueError as e:
        print(f"✗ Error computing AUC: {e}", file=sys.stderr)
        auc = None
    
    # Compute top-k metrics
    top_k_metrics = compute_top_k_metrics(y.values, y_pred_proba, k_values=[10, 20, 50])
    print(f"✓ Top-K Hit Rates:")
    for k in [10, 20, 50]:
        hit_rate = top_k_metrics.get(f'top_{k}_hit_rate')
        recall = top_k_metrics.get(f'top_{k}_recall')
        if hit_rate is not None:
            print(f"    Top-{k:2d}: Hit Rate = {hit_rate:.4f} ({100*hit_rate:.2f}%), "
                  f"Recall = {recall:.4f} ({100*recall:.2f}%)")
        else:
            print(f"    Top-{k:2d}: N/A (insufficient data)")
    
    # Final summary
    print_banner("Evaluation Complete")
    print(f"Model: {model_path}")
    print(f"Accuracy: {accuracy:.4f} ({100*accuracy:.2f}%)")
    if auc is not None:
        print(f"AUC (ROC): {auc:.4f}")
    print(f"\nTop-K Hit Rates:")
    for k in [10, 20, 50]:
        hit_rate = top_k_metrics.get(f'top_{k}_hit_rate')
        if hit_rate is not None:
            print(f"  Top-{k:2d}: {hit_rate:.4f} ({100*hit_rate:.2f}%)")
    print()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Evaluate a trained ML model",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ml/evaluate_model.py ml/models/model_logistic_20240111_120000.joblib
  python ml/evaluate_model.py ml/models/model_logistic_20240111_120000.joblib --job-id 123
  python ml/evaluate_model.py ml/models/model_logistic_20240111_120000.joblib --api-url http://localhost:18080
        """
    )
    parser.add_argument(
        'model_path',
        type=str,
        help='Path to the saved model file (.joblib)'
    )
    parser.add_argument(
        '--api-url',
        type=str,
        default='http://localhost:18080',
        help='Base URL of the API (default: http://localhost:18080)'
    )
    parser.add_argument(
        '--job-id',
        type=int,
        default=None,
        help='Optional job ID to filter evaluation data'
    )
    
    args = parser.parse_args()
    
    try:
        evaluate_model(
            model_path=args.model_path,
            api_url=args.api_url,
            job_id=args.job_id
        )
    except KeyboardInterrupt:
        print("\n\nEvaluation interrupted by user.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
