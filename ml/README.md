# ML Training Module

Offline ML training module for candidate recommendation system.

## Overview

This module provides scripts to train and evaluate machine learning models using data from the Spring Boot API endpoint `/api/ml/training-examples`.

## Requirements

- Python 3.8+
- Dependencies listed in `requirements.txt`

## Installation

```bash
# Install dependencies
pip install -r requirements.txt
```

## Quick Start

### 1. Start the Spring Boot Application

**IMPORTANT**: The Spring Boot application must be running before training or evaluation.

The default API URL is `http://localhost:18080` (configurable via `--api-url` parameter).

To start the application:
```bash
cd resume-blueprint/resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

Wait for the application to start (look for "Started ResumeBlueprintApiApplication" in the logs).

### 2. Train a Model

**Example 1: Random split (default)**
```bash
python train.py
```

**Example 2: Time-based split (chronological)**
```bash
python train.py --split time
```

**Example 3: Cross-validation**
```bash
python train.py --cv 5
```

**Train with data filtered by job_id:**
```bash
python train.py --job-id 123
```

**Train with RandomForest model:**
```bash
python train.py --model-type random_forest
```

**Full options:**
```bash
python train.py --help
```

### 3. Evaluate a Model

```bash
# Evaluate using the latest model
python evaluate.py --model-path models/model_logistic_20240101_120000.joblib
```

**Evaluate with job_id filter:**
```bash
python evaluate.py --model-path models/model_logistic_20240101_120000.joblib --job-id 123
```

## Usage Examples

### Example 1: Basic Training and Evaluation

```bash
# Step 1: Train a model (uses all data)
python train.py

# Output:
# ============================================================
# ML Training Script
# ============================================================
# Fetching training data from: http://localhost:18080/api/ml/training-examples
# Fetched 150 training examples
# Using 120 examples with valid labels
# Label distribution: hired=60, rejected=60
# 
# Training data: 96 examples
# Test data: 24 examples
# 
# Training LogisticRegression...
# Train accuracy: 0.8542
# Test accuracy: 0.7917
# 
# Model saved to: ml/models/model_logistic_20240101_120000.joblib
# ============================================================
# Training completed successfully!
# ============================================================

# Step 2: Evaluate the model
python evaluate.py --model-path models/model_logistic_20240101_120000.joblib

# Output:
# ============================================================
# ML Model Evaluation Script
# ============================================================
# Loaded model from: models/model_logistic_20240101_120000.joblib
# Model type: LogisticRegression
# Feature columns: ['match_score', 'overlap_score', 'gap_penalty', 'bonus_score', 'skill_match_count', 'year_diff', 'risk_score']
# 
# Fetching evaluation data from: http://localhost:18080/api/ml/training-examples
# Fetched 150 evaluation examples
# Using 120 examples with valid labels
# Label distribution: hired=60, rejected=60
# 
# ============================================================
# Evaluation Results
# ============================================================
# 
# Dataset:
#   Total examples: 120
#   Hired: 60
#   Rejected: 60
# 
# Model Performance:
#   Accuracy: 0.7917
#   AUC: 0.8567
# 
# Top-K Hit Rates (hired candidates in top-k):
#   Top 10: 80.00% (8/10 hired)
#   Top 20: 75.00% (15/20 hired)
#   Top 50: 70.00% (35/50 hired)
# ============================================================
```

### Example 2: Training for Specific Job

```bash
# Train model using data for job_id=123
python train.py --job-id 123 --model-type random_forest

# Output:
# ============================================================
# ML Training Script
# ============================================================
# Fetching training data from: http://localhost:18080/api/ml/training-examples?jobId=123
# Filter: job_id = 123
# Fetched 45 training examples
# Using 38 examples with valid labels
# Label distribution: hired=20, rejected=18
# 
# Training data: 30 examples
# Test data: 8 examples
# 
# Training RandomForestClassifier...
# Train accuracy: 0.9333
# Test accuracy: 0.8750
# 
# Model saved to: ml/models/model_random_forest_20240101_130000.joblib
```

### Example 3: Error Handling

**API not available:**
```bash
$ python train.py
ERROR: Cannot connect to API. Please ensure the Spring Boot application is running.
       Tried to connect to: http://localhost:18080/api/ml/training-examples
```

**Empty data:**
```bash
$ python train.py --job-id 99999
ERROR: API returned empty data.
       No training data found for job_id = 99999
```

**No valid labels:**
```bash
$ python train.py
ERROR: No valid training examples (all labels are NULL)
```

## Features

### Feature Columns (Job-Related Only)

The model uses only job-related features (excludes sensitive/identifier fields):

- `match_score`: Overall match score (0-1)
- `overlap_score`: Weighted Jaccard overlap score
- `gap_penalty`: Penalty for missing high-weight tags
- `bonus_score`: Bonus for unique strengths
- `skill_match_count`: Number of matched skills
- `year_diff`: Year difference (placeholder, currently NULL)
- `risk_score`: Risk score (placeholder, currently NULL)

**Excluded fields** (sensitive/identifiers):
- `candidate_id`
- `history_id`
- `stage_changed_at`
- `match_created_at`
- `reason_code`

### Model Types

1. **LogisticRegression** (default)
   - Fast training and inference
   - Good baseline model
   - Provides probability estimates

2. **RandomForestClassifier**
   - Better performance on complex patterns
   - Handles non-linear relationships
   - More robust to outliers

### Evaluation Metrics

- **Accuracy**: Overall classification accuracy
- **AUC**: Area Under ROC Curve (if probabilities available)
- **Top-K Hit Rate**: Percentage of hired candidates in top-k predictions
  - Example: Top 20 hit rate = 75% means 15 out of 20 top candidates were hired

## Model Storage

Models are saved to `ml/models/` directory with format:
```
model_<type>_<timestamp>.joblib
```

Example: `model_logistic_20240101_120000.joblib`

Each model file contains:
- Trained model object
- Feature scaler (StandardScaler)
- Feature column names

## Command-Line Options

### train.py

```
--api-url URL       API base URL (default: http://localhost:18080)
--job-id ID         Optional job ID to filter training data
--model-type TYPE   Model type: logistic or random_forest (default: logistic)
--seed INT          Random seed for reproducibility (default: 42)
--split TYPE        Data split method: random or time (default: random)
--test-size FLOAT   Proportion of test set (default: 0.2)
--cv INT            Enable K-fold cross-validation (default: disabled)
--help              Show help message
```

### evaluate.py

```
--model-path PATH   Path to saved model file (.joblib) [required]
--api-url URL       API base URL (default: http://localhost:18080)
--job-id ID         Optional job ID to filter evaluation data
--help              Show help message
```

## Training Modes

### Random Split (default)
- Standard random 80/20 train/test split
- Uses stratification if both classes present
- Reproducible with `--seed` parameter

### Time-based Split
- Splits data chronologically by `stage_changed_at`
- Simulates "predicting the future" scenario
- Older data for training, newer data for testing
- Useful for time-series evaluation

### Cross-Validation
- K-fold cross-validation (specify `--cv K`)
- Reports mean and std of accuracy and AUC across folds
- Still saves a final model trained on all data

## Metrics Storage

Training and evaluation metrics are automatically saved as JSON files:

- **Training metrics**: `ml/metrics/metrics_<timestamp>.json`
- **Evaluation metrics**: `ml/metrics/evaluate_<timestamp>.json`

Each metrics file contains:
- Dataset statistics (count, label distribution)
- Feature columns used
- Split parameters (type, test_size, seed)
- Model performance (accuracy, AUC, top-k hit rates)
- Model path and timestamp

## Notes

1. **Data Requirements**: The training script requires data with valid labels (HIRED=1 or REJECTED=0). Records with NULL labels are excluded.

2. **Feature Scaling**: Features are standardized using StandardScaler before training.

3. **Class Balancing**: Models use `class_weight='balanced'` to handle imbalanced datasets.

4. **Train/Test Split**: Default 80/20 split (configurable via `--test-size`).

5. **Reproducibility**: Use `--seed` parameter to ensure reproducible results (default: 42).

6. **Top-K Metrics**: Top-k hit rate is computed by sorting predictions by probability (descending) and calculating the percentage of hired candidates in the top-k.

7. **API Dependencies**: This module requires the Spring Boot API to be running on port 18080 (configurable via `--api-url`). Ensure the API endpoint `/api/ml/training-examples` is accessible.

## Troubleshooting

### "Cannot connect to API"
- Ensure Spring Boot application is running
- Check API URL: `http://localhost:18080`
- Verify network connectivity

### "API returned empty data"
- Check if training data exists in the database
- Verify job_id (if specified) exists
- Ensure candidates have stage history with job_id

### "No valid training examples"
- All labels are NULL (not HIRED or REJECTED)
- Check database for candidates with final_stage='hired' or 'rejected'

### "Missing required columns"
- API response structure may have changed
- Check VIEW definition: `ml_training_examples_v1`

## Future Enhancements

- Support for cross-validation
- Hyperparameter tuning
- Feature importance analysis
- Model versioning and comparison
- Integration with model serving infrastructure
