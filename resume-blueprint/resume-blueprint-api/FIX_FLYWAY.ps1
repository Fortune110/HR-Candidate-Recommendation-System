# ========================================
# Flyway Reset Script (100% Executable Version)
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flyway Validation Failure Fix Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Stop backend (if running)
Write-Host "Step 0: Stopping backend (if running)..." -ForegroundColor Yellow
Get-Process -Name java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "✓ Backend stopped (if previously running)" -ForegroundColor Green
Write-Host ""

# Step 1: Find Postgres container real name
Write-Host "Step 1: Finding Postgres container..." -ForegroundColor Yellow
$pg = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "postgres" | ForEach-Object { $_.ToString().Split(" ")[0] } | Select-Object -First 1)

if (-not $pg) {
    Write-Host "✗ Error: Cannot find Postgres container, please start Postgres first" -ForegroundColor Red
    Write-Host "Hint: Check the directory where docker-compose.yml is located, execute docker-compose up -d postgres" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found Postgres container: $pg" -ForegroundColor Green
Write-Host ""

# Step 2: Reset database (DROP + CREATE)
Write-Host "Step 2: Resetting database (DROP + CREATE)..." -ForegroundColor Yellow

# Try using rb_user
Write-Host "  Trying to use rb_user..." -ForegroundColor Gray
$dropResult = docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;" 2>&1

if ($LASTEXITCODE -ne 0 -or $dropResult -match "role.*does not exist") {
    Write-Host "  rb_user does not exist, using postgres superuser..." -ForegroundColor Gray
    docker exec $pg psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;" | Out-Null
    docker exec $pg psql -U postgres -d postgres -c "CREATE DATABASE resume_blueprint_db;" | Out-Null
    Write-Host "✓ Database rebuilt using postgres user" -ForegroundColor Green
} else {
    Write-Host "  Dropping database..." -ForegroundColor Gray
    docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;" | Out-Null
    
    Write-Host "  Creating database..." -ForegroundColor Gray
    $createResult = docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Creation failed, using postgres user..." -ForegroundColor Gray
        docker exec $pg psql -U postgres -d postgres -c "CREATE DATABASE resume_blueprint_db;" | Out-Null
        Write-Host "✓ Database rebuilt using postgres user" -ForegroundColor Green
    } else {
        Write-Host "✓ Database rebuilt using rb_user" -ForegroundColor Green
    }
}

Write-Host ""

# Step 3: Verify database connection
Write-Host "Step 3: Verifying database connection..." -ForegroundColor Yellow
$testResult = docker exec $pg psql -U rb_user -d resume_blueprint_db -c "SELECT 1;" 2>&1

if ($LASTEXITCODE -ne 0) {
    # Try testing with postgres user
    $testResult = docker exec $pg psql -U postgres -d resume_blueprint_db -c "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Database connection OK (using postgres user)" -ForegroundColor Green
        Write-Host "⚠ Note: Database is currently using postgres user, please confirm username configuration in application.yml" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Database connection failed: $testResult" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Database connection OK" -ForegroundColor Green
}

Write-Host ""

# Step 4: Prompt to start backend
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Database reset complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Start backend application" -ForegroundColor Yellow
Write-Host ""
Write-Host "Execute the following commands:" -ForegroundColor Cyan
Write-Host "  cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api" -ForegroundColor White
Write-Host "  .\mvnw.cmd spring-boot:run" -ForegroundColor White
Write-Host ""
Write-Host "After seeing 'Started ResumeBlueprintApiApplication', access:" -ForegroundColor Yellow
Write-Host "  - http://localhost:18080/upload" -ForegroundColor White
Write-Host "  - http://localhost:18080/swagger-ui/index.html" -ForegroundColor White
Write-Host ""
