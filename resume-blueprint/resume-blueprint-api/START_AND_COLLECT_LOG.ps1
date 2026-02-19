# ========================================
# Start backend and collect logs
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Backend Startup Log Collection Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: reset database
Write-Host "Step 1: Reset database..." -ForegroundColor Yellow
$pg = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "postgres" | ForEach-Object { $_.ToString().Split(" ")[0] } | Select-Object -First 1)

if (-not $pg) {
    Write-Host "✗ Error: Postgres container is not running" -ForegroundColor Red
    exit 1
}

Write-Host "  Postgres container: $pg" -ForegroundColor Gray
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;" | Out-Null
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;" | Out-Null
Write-Host "✓ Database reset completed" -ForegroundColor Green
Write-Host ""

# Step 2: stop any existing Java process
Write-Host "Step 2: Stop existing Java processes..." -ForegroundColor Yellow
Get-Process -Name java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "✓ Java processes stopped" -ForegroundColor Green
Write-Host ""

# Step 3: start backend and collect logs
Write-Host "Step 3: Start backend (logs saved to startup.log)..." -ForegroundColor Yellow
Write-Host "  Note: if startup fails, check the last 80 lines of startup.log" -ForegroundColor Gray
Write-Host ""

$logFile = "startup.log"
$startTime = Get-Date

# Start backend, output to console and file
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run 2>&1 | Tee-Object -FilePath $logFile

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Startup completed (elapsed: $([math]::Round($duration, 2)) seconds)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check success
$logContent = Get-Content $logFile -ErrorAction SilentlyContinue
if ($logContent -match "Started ResumeBlueprintApiApplication") {
    Write-Host "✓ Backend started successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verification steps:" -ForegroundColor Yellow
    Write-Host "  1. Check port: netstat -ano | findstr :18080" -ForegroundColor White
    Write-Host "  2. Test page: curl -I http://127.0.0.1:18080/upload" -ForegroundColor White
    Write-Host "  3. Browser: http://127.0.0.1:18080/upload" -ForegroundColor White
} else {
    Write-Host "✗ Backend startup failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Last 80 log lines:" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Get-Content $logFile -Tail 80
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Check the errors above, especially:" -ForegroundColor Yellow
    Write-Host "  - Flyway migration errors" -ForegroundColor White
    Write-Host "  - Database connection errors" -ForegroundColor White
    Write-Host "  - SQL syntax errors" -ForegroundColor White
}
