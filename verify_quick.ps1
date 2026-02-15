# Quick System Verification Script - 4-Step Process
# Optimized with shorter timeouts and progress indicators

$BaseUrl = "http://localhost:18080"
$PassCount = 0
$FailCount = 0

function Write-TestResult {
    param([string]$TestName, [string]$Status, [string]$Message = "")
    $symbol = if ($Status -eq "PASS") { "[OK]" } else { "[X]" }
    $color = if ($Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "$symbol [$Status] $TestName" -ForegroundColor $color
    if ($Message) { Write-Host "    $Message" -ForegroundColor Gray }
    if ($Status -eq "PASS") { $script:PassCount++ } else { $script:FailCount++ }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Quick System Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Backend Liveness
Write-Host "[Step 1] Backend Liveness..." -ForegroundColor Yellow
$portCheck = netstat -ano | findstr :18080 | findstr LISTENING
if ($portCheck) {
    Write-TestResult "Port 18080 Listening" "PASS" "Backend running"
} else {
    Write-TestResult "Port 18080 Listening" "FAIL" "Backend not running"
    exit 1
}

# Step 2: Dependencies
Write-Host "`n[Step 2] Dependencies..." -ForegroundColor Yellow
$dbContainer = docker ps --filter "name=resume_blueprint_postgres" --format "{{.Names}}" 2>$null
if ($dbContainer -match "resume_blueprint_postgres") {
    Write-TestResult "DB Container" "PASS" "resume_blueprint_postgres running"
} else {
    Write-TestResult "DB Container" "FAIL" "Not running"
}

$extractContainer = docker ps --filter "name=resume_blueprint_extract" --format "{{.Names}}" 2>$null
if ($extractContainer -match "resume_blueprint_extract") {
    Write-TestResult "Extract Container" "PASS" "resume_blueprint_extract running"
} else {
    Write-TestResult "Extract Container" "FAIL" "Not running"
}

try {
    $extractHealth = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($extractHealth.StatusCode -eq 200) {
        $health = $extractHealth.Content | ConvertFrom-Json
        if ($health.status -eq "ok" -and $health.models_loaded) {
            Write-TestResult "Extract Health" "PASS" "localhost:5000/health OK"
        } else {
            Write-TestResult "Extract Health" "FAIL" "Unhealthy"
        }
    }
} catch {
    Write-TestResult "Extract Health" "FAIL" "Cannot access"
}

# Step 3: Backend Availability
Write-Host "`n[Step 3] Backend Availability..." -ForegroundColor Yellow
try {
    $swagger = Invoke-WebRequest -Uri "$BaseUrl/swagger-ui/index.html" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($swagger.StatusCode -eq 200) {
        Write-TestResult "Swagger UI" "PASS" "HTTP 200"
    }
} catch {
    Write-TestResult "Swagger UI" "FAIL" "Cannot access"
}

try {
    $upload = Invoke-WebRequest -Uri "$BaseUrl/upload" -UseBasicParsing -TimeoutSec 3 -Method Head -ErrorAction Stop
    if ($upload.StatusCode -eq 200) {
        Write-TestResult "Upload Page" "PASS" "HTTP 200"
    }
} catch {
    Write-TestResult "Upload Page" "FAIL" "Cannot access"
}

# Step 4: Critical Path
Write-Host "`n[Step 4] Critical Path Test..." -ForegroundColor Yellow

# 4.1 Direct extract call
Write-Host "  4.1 Testing extract service directly..." -ForegroundColor Gray
try {
    $body = @{ text = "John Doe Software Engineer"; doc_type = "RESUME" } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "http://localhost:5000/extract" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 8 -ErrorAction Stop
    if ($result.entities -and $result.entities.Count -gt 0) {
        Write-TestResult "Extract Direct" "PASS" "$($result.entities.Count) entities extracted"
    } else {
        Write-TestResult "Extract Direct" "FAIL" "No entities"
    }
} catch {
    Write-TestResult "Extract Direct" "FAIL" "$($_.Exception.Message)"
}

# 4.2 Create resume
Write-Host "  4.2 Creating test resume..." -ForegroundColor Gray
$testDocId = $null
try {
    $resumeBody = @{
        candidateId = "quick_test_$(Get-Date -Format 'HHmmss')"
        text = "John Doe Software Engineer Java Spring Boot"
    } | ConvertTo-Json
    $doc = Invoke-RestMethod -Uri "$BaseUrl/api/resumes" -Method POST -Body $resumeBody -ContentType "application/json" -TimeoutSec 8 -ErrorAction Stop
    if ($doc.documentId) {
        $testDocId = $doc.documentId
        Write-TestResult "Create Resume" "PASS" "Document ID: $testDocId"
    } else {
        Write-TestResult "Create Resume" "FAIL" "No documentId"
    }
} catch {
    Write-TestResult "Create Resume" "FAIL" "$($_.Exception.Message)"
}

# 4.3 Backend extract call
if ($testDocId) {
    Write-Host "  4.3 Testing backend->extract call..." -ForegroundColor Gray
    try {
        $extractBody = @{
            documentId = $testDocId
            text = "John Doe Software Engineer Java Spring Boot"
            docType = "RESUME"
        } | ConvertTo-Json
        $extract = Invoke-RestMethod -Uri "$BaseUrl/api/extract" -Method POST -Body $extractBody -ContentType "application/json" -TimeoutSec 15 -ErrorAction Stop
        if ($extract.runId -and $extract.runId -gt 0) {
            Write-TestResult "Backend Extract" "PASS" "Run ID: $($extract.runId)"
        } else {
            Write-TestResult "Backend Extract" "FAIL" "Invalid response"
        }
    } catch {
        Write-TestResult "Backend Extract" "FAIL" "$($_.Exception.Message)"
    }
} else {
    Write-TestResult "Backend Extract" "FAIL" "Skipped (no documentId)"
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[OK] Passed: $PassCount" -ForegroundColor Green
Write-Host "[X] Failed: $FailCount" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($FailCount -eq 0) {
    Write-Host "[SUCCESS] System is running normally!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[WARNING] Some tests failed" -ForegroundColor Red
    exit 1
}
