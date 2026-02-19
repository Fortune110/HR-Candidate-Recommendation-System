# Git Commit and Push Script
# Execute this script after closing Cursor IDE or when lock file is released

cd c:\HR-Candidate-Recommendation-System

# Remove lock file if exists
if (Test-Path .git\index.lock) {
    Write-Host "Removing lock file..."
    Remove-Item -Force .git\index.lock -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Add all changes
Write-Host "Adding all changes..."
git add .

# Commit with message
Write-Host "Committing changes..."
git commit -m "feat: Add candidate stage management and ML training data export

- Add candidate pipeline stage management API
  - PATCH /api/candidates/{id}/stage with reasonCode and jobId support
  - GET /api/candidates/{id}/stage/history for stage history
  - Database migrations V5 and V6 for stage tracking

- Add ML training data export API
  - GET /api/ml/training-examples (CSV/JSON format)
  - Database view ml_training_examples_v1 for training data aggregation
  - Migration V14 for ML training view

- Add Python ML training module
  - train.py and evaluate.py scripts
  - Support for LogisticRegression and RandomForest models
  - Feature extraction and metrics collection

- Add comprehensive documentation
  - ML_TRAINING_EXPORT.md
  - STAGE_HISTORY_ENHANCEMENT_SUMMARY.md
  - ML module README"

# Push to remote
Write-Host "Pushing to remote repository..."
git push origin feat/ml-repro-metrics

Write-Host "Done!"
