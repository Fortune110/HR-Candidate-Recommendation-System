#!/usr/bin/env python3
"""
Train a Logistic Regression model for candidate recommendation.

Usage:
    python ml/train_model.py [--job-id JOB_ID] [--api-url API_URL]

Example:
    python ml/train_model.py
    python ml/train_model.py --job-id 123
    python ml/train_model.py --api-url http://localhost:18080 --job-id 456
"""

import argparse
import sys
import os
from datetime import datetime
from typing import Optional
import pandas as pd
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import joblib

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.http_client import fetch_training_data, APIError, validate_data
from ml.features import prepare_data, FEATURE_COLUMNS


def print_banner(title: str):
    """Print a formatted banner."""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70 + "\n")


def print_section(title: str):
    """Print a section header."""
    print(f"\n[{title}]")
    print("-" * 70)


def train_model(
    api_url: str = "http://localhost:18080",
    job_id: Optional[int] = None
) -> None:
    """
    Train a Logistic Regression model.
    
    Args:
        api_url: Base URL of the API
        job_id: Optional job ID to filter data
    """
    print_banner("ML Model Training - Logistic Regression")
    
    # Step 1: Fetch data
    print_section("Step 1: Fetching Training Data")
    print(f"API URL: {api_url}")
    if job_id:
        print(f"Job ID filter: {job_id}")
    else:
        print("Job ID filter: None (all jobs)")
    
    try:
        data = fetch_training_data(api_url=api_url, job_id=job_id, format="json")
        validate_data(data)
        print(f"✓ Fetched {len(data)} training examples from API")
    except (APIError, ValueError) as e:
        print(f"✗ Error fetching data: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 2: Convert to DataFrame
    print_section("Step 2: Processing Data")
    try:
        df = pd.DataFrame(data)
        print(f"✓ Converted to DataFrame: {len(df)} rows, {len(df.columns)} columns")
    except Exception as e:
        print(f"✗ Error converting to DataFrame: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Step 3: Extract features and labels
    print_section("Step 3: Extracting Features and Labels")
    try:
        X, y = prepare_data(df)
        print(f"✓ Extracted features: {X.shape[1]} features, {len(X)} valid examples")
        print(f"  Features: {', '.join(FEATURE_COLUMNS)}")
        
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
    
    # Step 4: Split data
    print_section("Step 4: Splitting Data")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"✓ Training set: {len(X_train)} examples")
    print(f"✓ Test set: {len(X_test)} examples")
    
    # Step 5: Scale features
    print_section("Step 5: Scaling Features")
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    print(f"✓ Features scaled (StandardScaler)")
    
    # Step 6: Train model
    print_section("Step 6: Training Model")
    model = LogisticRegression(random_state=42, max_iter=1000)
    model.fit(X_train_scaled, y_train)
    print(f"✓ Model trained (LogisticRegression)")
    
    # Step 7: Evaluate on train and test sets
    print_section("Step 7: Model Evaluation")
    train_accuracy = model.score(X_train_scaled, y_train)
    test_accuracy = model.score(X_test_scaled, y_test)
    print(f"✓ Training accuracy: {train_accuracy:.4f} ({100*train_accuracy:.2f}%)")
    print(f"✓ Test accuracy: {test_accuracy:.4f} ({100*test_accuracy:.2f}%)")
    
    # Step 8: Save model
    print_section("Step 8: Saving Model")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_filename = f"ml/models/model_logistic_{timestamp}.joblib"
    
    # Ensure models directory exists
    os.makedirs(os.path.dirname(model_filename), exist_ok=True)
    
    # Save model and scaler together
    joblib.dump({
        'model': model,
        'scaler': scaler,
        'feature_columns': FEATURE_COLUMNS,
        'timestamp': timestamp
    }, model_filename)
    
    print(f"✓ Model saved to: {model_filename}")
    
    # Final summary
    print_banner("Training Complete")
    print(f"Model file: {model_filename}")
    print(f"Training accuracy: {train_accuracy:.4f} ({100*train_accuracy:.2f}%)")
    print(f"Test accuracy: {test_accuracy:.4f} ({100*test_accuracy:.2f}%)")
    print(f"\nTo evaluate the model, run:")
    print(f"  python ml/evaluate_model.py {model_filename}\n")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Train a Logistic Regression model for candidate recommendation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ml/train_model.py
  python ml/train_model.py --job-id 123
  python ml/train_model.py --api-url http://localhost:18080 --job-id 456
        """
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
        help='Optional job ID to filter training data (supports both jobId and job_id query params)'
    )
    
    args = parser.parse_args()
    
    try:
        train_model(api_url=args.api_url, job_id=args.job_id)
    except KeyboardInterrupt:
        print("\n\nTraining interrupted by user.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
