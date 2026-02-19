#!/usr/bin/env python3
"""
ML Training Script
Train a baseline model using data from /api/ml/training-examples endpoint.
"""

import argparse
import sys
import os
from datetime import datetime
from pathlib import Path

import pandas as pd
import numpy as np
import requests
import json
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, roc_auc_score
import joblib

# Configuration
DEFAULT_API_URL = "http://localhost:18080"
MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)
METRICS_DIR = Path(__file__).parent / "metrics"
METRICS_DIR.mkdir(exist_ok=True)

# Feature columns (job-related only, exclude sensitive/identifier fields)
FEATURE_COLUMNS = [
    "match_score",
    "overlap_score",
    "gap_penalty",
    "bonus_score",
    "skill_match_count",
    "year_diff",      # placeholder (currently NULL, but included for future)
    "risk_score",     # placeholder (currently NULL, but included for future)
]

# Label column
LABEL_COLUMN = "label"


def fetch_training_data(api_url, job_id=None):
    """
    Fetch training data from API endpoint.
    
    Args:
        api_url: Base URL of the API (default: http://localhost:18080)
        job_id: Optional job ID to filter data
    
    Returns:
        pandas.DataFrame: Training data
    
    Raises:
        SystemExit: If API is unavailable or data is empty
    """
    url = f"{api_url}/api/ml/training-examples"
    params = {"format": "csv"}
    if job_id is not None:
        params["jobId"] = job_id
    
    print(f"Fetching training data from: {url}")
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
            print(f"       No training data found for job_id = {job_id}")
        else:
            print("       No training data available.")
        sys.exit(1)
    
    try:
        df = pd.read_csv(pd.io.common.StringIO(response.text))
    except Exception as e:
        print(f"ERROR: Failed to parse CSV response: {e}")
        sys.exit(1)
    
    if df.empty:
        print("ERROR: Training data is empty after parsing.")
        if job_id:
            print(f"       No records found for job_id = {job_id}")
        else:
            print("       No records available in the database.")
        sys.exit(1)
    
    print(f"Fetched {len(df)} training examples")
    return df


def prepare_features(df):
    """
    Prepare features for training.
    
    Args:
        df: DataFrame with training data
    
    Returns:
        tuple: (X, y, df_valid) where X is feature matrix, y is label vector, 
               and df_valid is the filtered dataframe
    """
    # Check required columns
    missing_cols = set(FEATURE_COLUMNS + [LABEL_COLUMN]) - set(df.columns)
    if missing_cols:
        print(f"ERROR: Missing required columns: {missing_cols}")
        sys.exit(1)
    
    # Extract features and label
    X = df[FEATURE_COLUMNS].copy()
    y = df[LABEL_COLUMN].copy()
    
    # Handle NULL values in features (fill with 0 for numeric columns)
    X = X.fillna(0)
    
    # Filter out records with NULL labels (not used for training)
    valid_mask = y.notna()
    X_valid = X[valid_mask].copy()
    y_valid = y[valid_mask].copy()
    df_valid = df[valid_mask].copy()
    
    if len(X_valid) == 0:
        print("ERROR: No valid training examples (all labels are NULL)")
        sys.exit(1)
    
    # Convert label to int
    y_valid = y_valid.astype(int)
    
    print(f"Using {len(X_valid)} examples with valid labels")
    print(f"Label distribution: hired={sum(y_valid == 1)}, rejected={sum(y_valid == 0)}")
    
    if len(set(y_valid)) < 2:
        print("WARNING: Only one class present in the data. Model may not be meaningful.")
    
    return X_valid.values, y_valid.values, df_valid


def split_data(X, y, df_valid, split_type="random", test_size=0.2, random_state=42):
    """
    Split data into train and test sets.
    
    Args:
        X: Feature matrix
        y: Label vector
        df_valid: DataFrame with valid records (for time-based sorting)
        split_type: Split type ('random' or 'time')
        test_size: Proportion of test set
        random_state: Random seed for random split
    
    Returns:
        tuple: (X_train, X_test, y_train, y_test) split data
    """
    if split_type == "time":
        # Time-based split: sort by stage_changed_at (ascending) and take last test_size as test
        if "stage_changed_at" not in df_valid.columns:
            print("ERROR: stage_changed_at column not found for time-based split")
            sys.exit(1)
        
        # Convert to datetime if string
        df_valid["stage_changed_at"] = pd.to_datetime(df_valid["stage_changed_at"])
        # Sort by time (ascending: oldest first)
        sorted_indices = df_valid["stage_changed_at"].argsort().values
        
        n_test = int(len(X) * test_size)
        test_indices = sorted_indices[-n_test:]
        train_indices = sorted_indices[:-n_test]
        
        X_train, X_test = X[train_indices], X[test_indices]
        y_train, y_test = y[train_indices], y[test_indices]
        
        print(f"Time-based split: sorted by stage_changed_at")
        print(f"Train period: {df_valid.iloc[train_indices[0]]['stage_changed_at']} to {df_valid.iloc[train_indices[-1]]['stage_changed_at']}")
        print(f"Test period: {df_valid.iloc[test_indices[0]]['stage_changed_at']} to {df_valid.iloc[test_indices[-1]]['stage_changed_at']}")
    else:
        # Random split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state,
            stratify=y if len(set(y)) > 1 else None
        )
    
    return X_train, X_test, y_train, y_test


def train_model(X_train, X_test, y_train, y_test, model_type="logistic", random_state=42):
    """
    Train a classification model.
    
    Args:
        X_train: Training feature matrix
        X_test: Test feature matrix
        y_train: Training label vector
        y_test: Test label vector
        model_type: Model type ('logistic' or 'random_forest')
        random_state: Random seed
    
    Returns:
        tuple: (model, scaler, metrics) trained model, scaler, and metrics dict
    """
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Train model
    if model_type == "random_forest":
        print(f"\nTraining RandomForestClassifier...")
        model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=random_state,
            class_weight="balanced"
        )
    else:
        print(f"\nTraining LogisticRegression...")
        model = LogisticRegression(
            max_iter=1000,
            random_state=random_state,
            class_weight="balanced"
        )
    
    model.fit(X_train_scaled, y_train)
    
    # Evaluate on test set
    y_pred = model.predict(X_test_scaled)
    y_pred_proba = model.predict_proba(X_test_scaled)[:, 1] if hasattr(model, "predict_proba") else None
    
    train_score = model.score(X_train_scaled, y_train)
    test_score = accuracy_score(y_test, y_pred)
    
    metrics = {
        "train_accuracy": float(train_score),
        "test_accuracy": float(test_score),
    }
    
    # Compute AUC if probabilities are available
    if y_pred_proba is not None and len(set(y_test)) > 1:
        try:
            auc = roc_auc_score(y_test, y_pred_proba)
            metrics["test_auc"] = float(auc)
        except ValueError:
            metrics["test_auc"] = None
    else:
        metrics["test_auc"] = None
    
    print(f"Train accuracy: {train_score:.4f}")
    print(f"Test accuracy: {test_score:.4f}")
    if metrics["test_auc"] is not None:
        print(f"Test AUC: {metrics['test_auc']:.4f}")
    
    return model, scaler, metrics


def compute_top_k_metrics(y_true, y_pred_proba, k_values=[10, 20, 50]):
    """Compute top-k hit rate metrics."""
    if y_pred_proba is None:
        return {}
    
    top_k_metrics = {}
    sorted_indices = np.argsort(y_pred_proba)[::-1]
    y_true_sorted = y_true[sorted_indices]
    
    for k in k_values:
        if k > len(y_true):
            k = len(y_true)
        top_k_labels = y_true_sorted[:k]
        hired_count = sum(top_k_labels == 1)
        hit_rate = hired_count / k if k > 0 else 0.0
        top_k_metrics[f"top_{k}_hit_rate"] = float(hit_rate)
        top_k_metrics[f"top_{k}_hired_count"] = int(hired_count)
    
    return top_k_metrics


def cross_validate_model(X, y, model_type="logistic", cv=5, random_state=42):
    """
    Perform cross-validation.
    
    Args:
        X: Feature matrix
        y: Label vector
        model_type: Model type ('logistic' or 'random_forest')
        cv: Number of folds
        random_state: Random seed
    
    Returns:
        dict: Cross-validation metrics
    """
    # Scale features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Create model
    if model_type == "random_forest":
        model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            random_state=random_state,
            class_weight="balanced"
        )
    else:
        model = LogisticRegression(
            max_iter=1000,
            random_state=random_state,
            class_weight="balanced"
        )
    
    # Cross-validation
    cv_fold = StratifiedKFold(n_splits=cv, shuffle=True, random_state=random_state)
    
    cv_accuracy = cross_val_score(model, X_scaled, y, cv=cv_fold, scoring="accuracy")
    
    # AUC requires probabilities
    try:
        cv_auc = cross_val_score(model, X_scaled, y, cv=cv_fold, scoring="roc_auc")
        auc_mean = float(cv_auc.mean())
        auc_std = float(cv_auc.std())
    except ValueError:
        auc_mean = None
        auc_std = None
    
    accuracy_mean = float(cv_accuracy.mean())
    accuracy_std = float(cv_accuracy.std())
    
    print(f"\nCross-Validation ({cv}-fold):")
    print(f"  Accuracy: {accuracy_mean:.4f} (+/- {accuracy_std:.4f})")
    if auc_mean is not None:
        print(f"  AUC: {auc_mean:.4f} (+/- {auc_std:.4f})")
    
    return {
        "cv_accuracy_mean": accuracy_mean,
        "cv_accuracy_std": accuracy_std,
        "cv_auc_mean": auc_mean,
        "cv_auc_std": auc_std,
    }


def save_model(model, scaler, model_type):
    """
    Save model and scaler to disk.
    
    Args:
        model: Trained model
        scaler: Feature scaler
        model_type: Model type name
    
    Returns:
        Path: Path to saved model file
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_filename = f"model_{model_type}_{timestamp}.joblib"
    model_path = MODELS_DIR / model_filename
    
    # Save model and scaler together
    joblib.dump({"model": model, "scaler": scaler, "feature_columns": FEATURE_COLUMNS}, model_path)
    
    print(f"\nModel saved to: {model_path}")
    return model_path


def save_metrics(metrics_dict, job_id=None):
    """
    Save metrics to JSON file.
    
    Args:
        metrics_dict: Dictionary of metrics
        job_id: Optional job ID
    
    Returns:
        Path: Path to saved metrics file
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    metrics_filename = f"metrics_{timestamp}.json"
    metrics_path = METRICS_DIR / metrics_filename
    
    with open(metrics_path, "w") as f:
        json.dump(metrics_dict, f, indent=2, default=str)
    
    print(f"Metrics saved to: {metrics_path}")
    return metrics_path


def main():
    parser = argparse.ArgumentParser(
        description="Train ML model using data from /api/ml/training-examples endpoint"
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
        help="Optional job ID to filter training data"
    )
    parser.add_argument(
        "--model-type",
        choices=["logistic", "random_forest"],
        default="logistic",
        help="Model type: logistic or random_forest (default: logistic)"
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducibility (default: 42)"
    )
    parser.add_argument(
        "--split",
        choices=["random", "time"],
        default="random",
        help="Data split method: random or time (default: random)"
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Proportion of test set (default: 0.2)"
    )
    parser.add_argument(
        "--cv",
        type=int,
        default=None,
        help="Enable K-fold cross-validation (default: disabled)"
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("ML Training Script")
    print("=" * 60)
    
    # Fetch data
    df = fetch_training_data(args.api_url, args.job_id)
    
    # Prepare features
    X, y, df_valid = prepare_features(df)
    
    # Initialize metrics dictionary
    metrics = {
        "timestamp": datetime.now().isoformat(),
        "num_examples": len(X),
        "num_hired": int(sum(y == 1)),
        "num_rejected": int(sum(y == 0)),
        "feature_columns": FEATURE_COLUMNS,
        "model_type": args.model_type,
        "split_type": args.split,
        "test_size": args.test_size,
        "random_seed": args.seed,
        "job_id": args.job_id,
    }
    
    # Cross-validation mode
    if args.cv is not None:
        print(f"\nRunning {args.cv}-fold cross-validation...")
        cv_metrics = cross_validate_model(X, y, args.model_type, args.cv, args.seed)
        metrics.update(cv_metrics)
        metrics["cross_validation"] = True
        metrics["cv_folds"] = args.cv
        
        # Still train a final model on all data for saving
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        if args.model_type == "random_forest":
            model = RandomForestClassifier(
                n_estimators=100, max_depth=10, random_state=args.seed, class_weight="balanced"
            )
        else:
            model = LogisticRegression(
                max_iter=1000, random_state=args.seed, class_weight="balanced"
            )
        model.fit(X_scaled, y)
        
        # Save model
        model_path = save_model(model, scaler, args.model_type)
        metrics["model_path"] = str(model_path)
    else:
        # Train/test split mode
        metrics["cross_validation"] = False
        
        # Split data
        X_train, X_test, y_train, y_test = split_data(
            X, y, df_valid, args.split, args.test_size, args.seed
        )
        
        print(f"\nTraining data: {len(X_train)} examples")
        print(f"Test data: {len(X_test)} examples")
        
        # Train model
        model, scaler, train_metrics = train_model(
            X_train, X_test, y_train, y_test, args.model_type, args.seed
        )
        metrics.update(train_metrics)
        
        # Compute top-k metrics on test set
        X_test_scaled = scaler.transform(X_test)
        y_test_proba = model.predict_proba(X_test_scaled)[:, 1] if hasattr(model, "predict_proba") else None
        top_k_metrics = compute_top_k_metrics(y_test, y_test_proba)
        metrics.update(top_k_metrics)
        
        # Save model
        model_path = save_model(model, scaler, args.model_type)
        metrics["model_path"] = str(model_path)
    
    # Save metrics
    metrics_path = save_metrics(metrics, args.job_id)
    
    print("\n" + "=" * 60)
    print("Training completed successfully!")
    print("=" * 60)
    print(f"\nTo evaluate the model, run:")
    print(f"  python evaluate.py --model-path {model_path} --api-url {args.api_url}")
    if args.job_id:
        print(f"  python evaluate.py --model-path {model_path} --api-url {args.api_url} --job-id {args.job_id}")


if __name__ == "__main__":
    main()
