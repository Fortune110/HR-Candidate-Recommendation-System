"""
Feature processing module for ML training.

Handles feature extraction from API responses, supporting both snake_case and camelCase formats.
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional, Tuple


# Fixed feature columns (snake_case format)
FEATURE_COLUMNS = [
    'match_score',
    'overlap_score',
    'gap_penalty',
    'bonus_score',
    'skill_match_count',
    'year_diff',
    'risk_score'
]

# Sensitive fields to exclude from features
SENSITIVE_FIELDS = {
    'candidate_id',
    'history_id',
    'job_id',
    'stage_changed_at',
    'match_created_at',
    'reason_code',
    'final_stage'
}


def normalize_column_name(col: str) -> str:
    """
    Normalize column name from camelCase to snake_case.
    
    Examples:
        matchScore -> match_score
        overlapScore -> overlap_score
        skillMatchCount -> skill_match_count
    """
    if not col or col.islower():
        return col
    
    # Handle camelCase conversion
    result = []
    for i, char in enumerate(col):
        if char.isupper() and i > 0:
            result.append('_')
        result.append(char.lower())
    return ''.join(result)


def extract_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Extract feature columns from dataframe, handling both snake_case and camelCase.
    
    Args:
        df: Input dataframe with training data
        
    Returns:
        DataFrame with feature columns only
        
    Raises:
        ValueError: If required features are missing
    """
    # Normalize all column names to snake_case
    df_normalized = df.copy()
    df_normalized.columns = [normalize_column_name(col) for col in df_normalized.columns]
    
    # Check if required features exist
    missing_features = [col for col in FEATURE_COLUMNS if col not in df_normalized.columns]
    if missing_features:
        available_cols = list(df_normalized.columns)
        raise ValueError(
            f"Missing required features: {missing_features}\n"
            f"Available columns: {available_cols}"
        )
    
    # Extract only feature columns
    features_df = df_normalized[FEATURE_COLUMNS].copy()
    
    # Fill NaN values with 0 for numeric columns
    for col in FEATURE_COLUMNS:
        if features_df[col].dtype in ['float64', 'int64']:
            features_df[col] = features_df[col].fillna(0.0)
        else:
            features_df[col] = pd.to_numeric(features_df[col], errors='coerce').fillna(0.0)
    
    # Convert to float to ensure numeric types
    features_df = features_df.astype(float)
    
    return features_df


def parse_label(value: Any) -> Optional[int]:
    """
    Parse label value from various formats.
    
    Supports:
    - Integer: 1, 0
    - Boolean: True -> 1, False -> 0
    - String: "HIRED", "hired", "REJECTED", "rejected", "1", "0"
    
    Args:
        value: Label value in various formats
        
    Returns:
        Integer label (1 for positive, 0 for negative) or None if invalid
    """
    if value is None or pd.isna(value):
        return None
    
    # Handle boolean
    if isinstance(value, bool):
        return 1 if value else 0
    
    # Handle integer
    if isinstance(value, (int, np.integer)):
        if value == 1 or value == 0:
            return int(value)
        return None
    
    # Handle string
    if isinstance(value, str):
        value_upper = value.upper().strip()
        if value_upper in ['HIRED', '1', 'TRUE']:
            return 1
        elif value_upper in ['REJECTED', '0', 'FALSE']:
            return 0
    
    return None


def extract_labels(df: pd.DataFrame) -> pd.Series:
    """
    Extract labels from dataframe.
    
    Args:
        df: Input dataframe with label column
        
    Returns:
        Series with integer labels (1 or 0), with None for invalid labels
        
    Raises:
        ValueError: If label column is missing
    """
    df_normalized = df.copy()
    df_normalized.columns = [normalize_column_name(col) for col in df_normalized.columns]
    
    if 'label' not in df_normalized.columns:
        raise ValueError("Missing 'label' column in data")
    
    labels = df_normalized['label'].apply(parse_label)
    return labels


def prepare_data(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series]:
    """
    Prepare data for training: extract features and labels.
    
    Args:
        df: Input dataframe with features and labels
        
    Returns:
        Tuple of (features_df, labels_series)
        
    Raises:
        ValueError: If data preparation fails
    """
    features_df = extract_features(df)
    labels_series = extract_labels(df)
    
    # Filter out rows with invalid labels
    valid_mask = labels_series.notna()
    features_valid = features_df[valid_mask]
    labels_valid = labels_series[valid_mask]
    
    if len(features_valid) == 0:
        raise ValueError("No valid labels found in data")
    
    return features_valid, labels_valid
