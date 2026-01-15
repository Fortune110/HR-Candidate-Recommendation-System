# One-Click Startup Script - Complete Fixed Workflow
# Execute in PowerShell: .\START_HERE.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HR Candidate Recommendation System" -ForegroundColor Cyan
Write-Host "  Quick Startup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check current directory
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Get-Location
}

Write-Host "Project Root: $projectRoot" -ForegroundColor Yellow
Write-Host ""

# Step 1: Start database
Write-Host "[1/4] Starting PostgreSQL database..." -ForegroundColor Green
Push-Location "$projectRoot\talent-archive-core"
docker compose up -d postgres
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Cannot start database container" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "✓ Database container started" -ForegroundColor Green
Pop-Location

# Wait for database to be ready
Write-Host ""
Write-Host "[2/4] Waiting for database to be ready (5 seconds)..." -ForegroundColor Green
Start-Sleep -Seconds 5

# Step 2: Verify database connection
Write-Host ""
Write-Host "[3/4] Verifying database connection..." -ForegroundColor Green
Push-Location "$projectRoot\talent-archive-core"
$dbCheck = docker compose exec -T postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Database connection OK" -ForegroundColor Green
} else {
    Write-Host "Warning: Database connection may have issues, but continuing..." -ForegroundColor Yellow
    Write-Host "  Error: $dbCheck" -ForegroundColor Yellow
}
Pop-Location

# Step 3: Start backend application
Write-Host ""
Write-Host "[4/4] Starting Spring Boot application..." -ForegroundColor Green
Write-Host "  Application will start in background, check new window for output" -ForegroundColor Yellow
Write-Host "  Or wait 20 seconds and run health check" -ForegroundColor Yellow
Write-Host ""

Push-Location "$projectRoot\resume-blueprint\resume-blueprint-api"

# Check if already running
$existingProcess = Get-Process -Name java -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*ResumeBlueprintApiApplication*"
} -ErrorAction SilentlyContinue

if ($existingProcess) {
    Write-Host "  Application may already be running, skipping startup" -ForegroundColor Yellow
    Write-Host "  If health check fails, manually start: .\mvnw.cmd spring-boot:run" -ForegroundColor Yellow
} else {
    Write-Host "  Startup command: .\mvnw.cmd spring-boot:run" -ForegroundColor Cyan
    Write-Host "  Tip: Run this command in a new window, or use the following to start in background:" -ForegroundColor Cyan
    Write-Host "    Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd $projectRoot\resume-blueprint\resume-blueprint-api; .\mvnw.cmd spring-boot:run'" -ForegroundColor Cyan
}

Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. If application did not start automatically, run in a new window:" -ForegroundColor Yellow
Write-Host "   cd $projectRoot\resume-blueprint\resume-blueprint-api" -ForegroundColor White
Write-Host "   .\mvnw.cmd spring-boot:run" -ForegroundColor White
Write-Host ""
Write-Host "2. Wait 20 seconds, then run health check:" -ForegroundColor Yellow
Write-Host "   Invoke-WebRequest -Uri 'http://localhost:18080/api/extract/health' -UseBasicParsing" -ForegroundColor White
Write-Host ""
Write-Host "3. If health check returns 200, run E2E tests:" -ForegroundColor Yellow
Write-Host "   cd $projectRoot" -ForegroundColor White
Write-Host "   .\requests\e2e_smoke.ps1" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
