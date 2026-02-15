# Push main to GitHub (merge from feat/ml-repro-metrics already done locally)
# Run this in PowerShell from the repo folder

Set-Location $PSScriptRoot
Write-Host "Pushing main to GitHub..."
git push origin main
if ($LASTEXITCODE -eq 0) { Write-Host "Done! main is now on GitHub." } else { Write-Host "Push failed. Run: git push origin main" }
