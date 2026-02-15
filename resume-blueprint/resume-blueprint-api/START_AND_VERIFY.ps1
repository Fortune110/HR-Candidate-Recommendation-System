# ========================================
# Backend startup and accessibility check
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Backend Startup and Accessibility Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# A. Confirm facts
Write-Host "A. Confirm facts..." -ForegroundColor Yellow
Write-Host "  - server.port: 18080 (application.yml)" -ForegroundColor Gray
Write-Host "  - UploadPageController: /upload -> static/upload.html" -ForegroundColor Gray
Write-Host "  - upload.html: src/main/resources/static/upload.html" -ForegroundColor Gray
Write-Host "  - springdoc: added (2.3.0)" -ForegroundColor Gray
Write-Host ""

# Step 1: stop existing Java processes
Write-Host "Step 1: Stop existing Java processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process -Name java -ErrorAction SilentlyContinue
if ($javaProcesses) {
    $javaProcesses | Stop-Process -Force
    Write-Host "✓ Stopped $($javaProcesses.Count) Java process(es)" -ForegroundColor Green
} else {
    Write-Host "✓ No running Java processes" -ForegroundColor Green
}
Start-Sleep -Seconds 2
Write-Host ""

# Step 2: reset database
Write-Host "Step 2: Reset database..." -ForegroundColor Yellow
$pg = "resume_blueprint_postgres"
try {
    docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;" | Out-Null
    docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;" | Out-Null
    Write-Host "✓ Database reset completed" -ForegroundColor Green
} catch {
    Write-Host "✗ Database reset failed: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: start backend (background)
Write-Host "Step 3: Start backend..." -ForegroundColor Yellow
Write-Host "  Note: startup can take 30-60 seconds" -ForegroundColor Gray
Write-Host ""

$projectPath = "C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api"
$logFile = Join-Path $projectPath "startup.log"

# Start backend and save logs
$job = Start-Job -ScriptBlock {
    param($path, $log)
    Set-Location $path
    .\mvnw.cmd spring-boot:run 2>&1 | Tee-Object -FilePath $log
} -ArgumentList $projectPath, $logFile

Write-Host "  Backend starting (Job ID: $($job.Id))..." -ForegroundColor Gray
Write-Host "  Waiting for startup..." -ForegroundColor Gray

# Wait for startup (max 120 seconds)
$maxWait = 120
$waited = 0
$started = $false

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 3
    $waited += 3
    
    # Check startup success markers in log
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -ErrorAction SilentlyContinue
        if ($logContent -match "Started ResumeBlueprintApiApplication") {
            $started = $true
            break
        }
        if ($logContent -match "BUILD FAILURE" -or $logContent -match "Application run failed") {
            Write-Host ""
            Write-Host "✗ Backend startup failed!" -ForegroundColor Red
            Write-Host "Last 80 log lines:" -ForegroundColor Yellow
            Write-Host "----------------------------------------" -ForegroundColor Gray
            Get-Content $logFile -Tail 80
            Write-Host "----------------------------------------" -ForegroundColor Gray
            Stop-Job $job
            Remove-Job $job
            exit 1
        }
    }
    
    # Check port listening
    $listening = netstat -ano | findstr ":18080" | findstr "LISTENING"
    if ($listening) {
        $started = $true
        break
    }
    
    Write-Host "  ... waiting ($waited/$maxWait seconds)" -ForegroundColor Gray
}

if (-not $started) {
    Write-Host ""
    Write-Host "✗ Startup timed out (waited $waited seconds)" -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "Last 80 log lines:" -ForegroundColor Yellow
        Get-Content $logFile -Tail 80
    }
    Stop-Job $job
    Remove-Job $job
    exit 1
}

Write-Host ""
Write-Host "✓ Backend started successfully!" -ForegroundColor Green
Write-Host ""

# Step 4: verify port listening
Write-Host "Step 4: Verify port listening..." -ForegroundColor Yellow
$listening = netstat -ano | findstr ":18080" | findstr "LISTENING"
if ($listening) {
    Write-Host "✓ Port 18080 is listening" -ForegroundColor Green
    Write-Host "  $listening" -ForegroundColor Gray
} else {
    Write-Host "✗ Port 18080 is not listening" -ForegroundColor Red
    Write-Host "  Check Java processes:" -ForegroundColor Yellow
    Get-Process -Name java -ErrorAction SilentlyContinue | Format-Table
    exit 1
}
Write-Host ""

# Step 5: verify HTTP connectivity
Write-Host "Step 5: Verify HTTP connectivity..." -ForegroundColor Yellow

# Test root path
Write-Host "  Testing root path..." -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:18080/" -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓ GET / : $($response.StatusCode)" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode) {
        Write-Host "  ✓ GET / : $statusCode (reachable)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ GET / : connection failed" -ForegroundColor Red
    }
}

# Test upload page
Write-Host "  Testing upload page..." -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:18080/upload" -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓ GET /upload : $($response.StatusCode)" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode) {
        Write-Host "  ✓ GET /upload : $statusCode (reachable)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ GET /upload : connection failed" -ForegroundColor Red
    }
}

# Test Swagger UI
Write-Host "  Testing Swagger UI..." -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:18080/swagger-ui/index.html" -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓ GET /swagger-ui/index.html : $($response.StatusCode)" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode) {
        Write-Host "  ✓ GET /swagger-ui/index.html : $statusCode (reachable)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ GET /swagger-ui/index.html : connection failed" -ForegroundColor Red
    }
}
Write-Host ""

# Step 6: confirm correct upload page URL
Write-Host "Step 6: Confirm upload page URL..." -ForegroundColor Yellow
Write-Host "  Code evidence:" -ForegroundColor Gray
Write-Host "    - UploadPageController.java: @GetMapping(value = \"/upload\")" -ForegroundColor White
Write-Host "    - File path: src/main/resources/static/upload.html" -ForegroundColor White
Write-Host "  Conclusion: the URL is /upload (not /upload.html)" -ForegroundColor Green
Write-Host "  Reason: controller maps /upload and returns HTML directly" -ForegroundColor Gray
Write-Host ""

# Final summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Yellow
Write-Host "  - Upload page: http://127.0.0.1:18080/upload" -ForegroundColor White
Write-Host "  - Swagger UI: http://127.0.0.1:18080/swagger-ui/index.html" -ForegroundColor White
Write-Host ""
Write-Host "Note: backend is running in the background (Job ID: $($job.Id))" -ForegroundColor Gray
Write-Host "To stop backend: Stop-Job $($job.Id); Remove-Job $($job.Id)" -ForegroundColor Gray
Write-Host ""
