# ============================================
# Complete System Verification Script - 4-Step Process
# ============================================
# Based on actual project setup:
# - Actuator not enabled
# - DB + extract in Docker
# - Backend on port 18080
# ============================================

$BaseUrl = "http://localhost:18080"
$PassCount = 0
$FailCount = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $symbol = if ($Status -eq "PASS") { "[OK]" } else { "[X]" }
    $color = if ($Status -eq "PASS") { "Green" } else { "Red" }
    
    Write-Host "$symbol [$Status] $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "    $Message" -ForegroundColor Gray
    }
    
    if ($Status -eq "PASS") { $script:PassCount++ } else { $script:FailCount++ }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Complete System Verification - 4 Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# Step 1: Is backend really running? (Liveness)
# ============================================
Write-Host "[Step 1] Backend Liveness Check" -ForegroundColor Yellow
$portCheck = netstat -ano | findstr :18080 | findstr LISTENING
if ($portCheck) {
    Write-TestResult "Port 18080 Listening" "PASS" "Backend is listening on port 18080"
} else {
    Write-TestResult "Port 18080 Listening" "FAIL" "Backend is not running"
    Write-Host "`n[X] Backend not running, aborting verification" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ============================================
# Step 2: Are dependencies online? (DB + extract)
# ============================================
Write-Host "[Step 2] Dependencies Check (DB + extract)" -ForegroundColor Yellow

# 2.1 DB container online
$dbContainer = docker ps --filter "name=resume_blueprint_postgres" --format "{{.Names}}" 2>$null
if ($dbContainer -match "resume_blueprint_postgres") {
    $dbStatus = docker ps --filter "name=resume_blueprint_postgres" --format "{{.Status}}" 2>$null
    Write-TestResult "DB Container Online" "PASS" "resume_blueprint_postgres - $dbStatus"
} else {
    Write-TestResult "DB Container Online" "FAIL" "resume_blueprint_postgres not running"
}

# 2.2 extract container online
$extractContainer = docker ps --filter "name=resume_blueprint_extract" --format "{{.Names}}" 2>$null
if ($extractContainer -match "resume_blueprint_extract") {
    $extractStatus = docker ps --filter "name=resume_blueprint_extract" --format "{{.Status}}" 2>$null
    Write-TestResult "Extract Container Online" "PASS" "resume_blueprint_extract - $extractStatus"
} else {
    Write-TestResult "Extract Container Online" "FAIL" "resume_blueprint_extract not running"
}

# 2.3 extract service health check (host->extract)
$extractHealth = $null
try {
    $extractHealth = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($extractHealth.StatusCode -eq 200) {
        $healthContent = $extractHealth.Content | ConvertFrom-Json
        if ($healthContent.status -eq "ok" -and $healthContent.models_loaded -eq $true) {
            Write-TestResult "Extract Service Health" "PASS" "localhost:5000/health - status=ok, models_loaded=true"
        } else {
            Write-TestResult "Extract Service Health" "FAIL" "Health check returned abnormal status"
        }
    }
} catch {
    Write-TestResult "Extract Service Health" "FAIL" "Cannot access localhost:5000/health - $($_.Exception.Message)"
}
Write-Host ""

# ============================================
# Step 3: Backend availability (not /actuator/health)
# ============================================
Write-Host "[Step 3] Backend Availability Check" -ForegroundColor Yellow

# Initialize variables
$swaggerResponse = $null
$uploadResponse = $null

# 3.1 Swagger UI
try {
    $swaggerResponse = Invoke-WebRequest -Uri "$BaseUrl/swagger-ui/index.html" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($swaggerResponse.StatusCode -eq 200) {
        Write-TestResult "Swagger UI" "PASS" "HTTP $($swaggerResponse.StatusCode) - Accessible"
    } else {
        Write-TestResult "Swagger UI" "FAIL" "HTTP $($swaggerResponse.StatusCode)"
    }
} catch {
    Write-TestResult "Swagger UI" "FAIL" "Cannot access - $($_.Exception.Message)"
}

# 3.2 Upload page
try {
    $uploadResponse = Invoke-WebRequest -Uri "$BaseUrl/upload" -UseBasicParsing -TimeoutSec 5 -Method Head -ErrorAction Stop
    if ($uploadResponse.StatusCode -eq 200) {
        Write-TestResult "Upload Page" "PASS" "HTTP $($uploadResponse.StatusCode) - Accessible"
    } else {
        Write-TestResult "Upload Page" "FAIL" "HTTP $($uploadResponse.StatusCode)"
    }
} catch {
    Write-TestResult "Upload Page" "FAIL" "Cannot access - $($_.Exception.Message)"
}
Write-Host ""

# ============================================
# Step 4: Critical path verification - Real extraction test
# ============================================
Write-Host "[Step 4] Critical Path - Real Business API Test" -ForegroundColor Yellow

# 4.1 Test extract service directly (host->extract)
Write-Host "  4.1 Testing extract service direct call..." -ForegroundColor Gray
try {
    $testText = "John Doe`nSoftware Engineer`n5 years experience in Java, Spring Boot, PostgreSQL."
    $extractBody = @{
        text = $testText
        doc_type = "RESUME"
    } | ConvertTo-Json
    
    $extractDirect = Invoke-RestMethod -Uri "http://localhost:5000/extract" -Method POST -Body $extractBody -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    if ($extractDirect.entities -and $extractDirect.entities.Count -gt 0) {
        Write-TestResult "Extract Service Direct Call" "PASS" "Successfully extracted $($extractDirect.entities.Count) entities"
    } else {
        Write-TestResult "Extract Service Direct Call" "FAIL" "No entities extracted"
    }
} catch {
    Write-TestResult "Extract Service Direct Call" "FAIL" "Call failed - $($_.Exception.Message)"
}

# 4.2 Create test resume to get documentId
Write-Host "  4.2 Creating test resume..." -ForegroundColor Gray
$testCandidateId = "verify_test_$(Get-Date -Format 'yyyyMMddHHmmss')"
$resumeText = "John Doe`nSoftware Engineer`n5 years experience in Java, Spring Boot, PostgreSQL. Skills: Java, Python, Docker, Kubernetes."
$resumeBody = @{
    candidateId = $testCandidateId
    text = $resumeText
} | ConvertTo-Json

$testDocId = $null
try {
    $resumeResponse = Invoke-RestMethod -Uri "$BaseUrl/api/resumes" -Method POST -Body $resumeBody -ContentType "application/json" -TimeoutSec 10 -ErrorAction Stop
    if ($resumeResponse.documentId) {
        $testDocId = $resumeResponse.documentId
        Write-TestResult "Create Test Resume" "PASS" "Document ID: $testDocId"
    } else {
        Write-TestResult "Create Test Resume" "FAIL" "No documentId returned"
    }
} catch {
    Write-TestResult "Create Test Resume" "FAIL" "Creation failed - $($_.Exception.Message)"
}

# 4.3 Test backend->extract business call
$extractRequestBody = $null
if ($testDocId) {
    Write-Host "  4.3 Testing backend->extract business call..." -ForegroundColor Gray
    $extractRequestBody = @{
        documentId = $testDocId
        text = $resumeText
        docType = "RESUME"
    } | ConvertTo-Json
    
    try {
        $extractResponse = Invoke-RestMethod -Uri "$BaseUrl/api/extract" -Method POST -Body $extractRequestBody -ContentType "application/json" -TimeoutSec 30 -ErrorAction Stop
        if ($extractResponse.runId -and $extractResponse.runId -gt 0) {
            Write-TestResult "Backend->Extract Business Call" "PASS" "Run ID: $($extractResponse.runId), Message: $($extractResponse.message)"
        } else {
            Write-TestResult "Backend->Extract Business Call" "FAIL" "Invalid runId returned"
        }
    } catch {
        Write-TestResult "Backend->Extract Business Call" "FAIL" "Call failed - $($_.Exception.Message)"
    }
} else {
    Write-TestResult "Backend->Extract Business Call" "FAIL" "Skipped (test resume not created)"
}
Write-Host ""

# ============================================
# Verification Summary
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[OK] Passed: $PassCount" -ForegroundColor Green
Write-Host "[X] Failed: $FailCount" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

# Final criteria check
Write-Host "[Final Criteria]" -ForegroundColor Yellow
$swaggerOk = ($swaggerResponse -ne $null -and $swaggerResponse.StatusCode -eq 200)
$uploadOk = ($uploadResponse -ne $null -and $uploadResponse.StatusCode -eq 200)
$extractHealthOk = ($extractHealth -ne $null -and $extractHealth.StatusCode -eq 200)

$criteria = @(
    @{ Name = "18080 LISTENING"; Status = ($portCheck -ne $null) }
    @{ Name = "Swagger / upload accessible"; Status = ($swaggerOk -or $uploadOk) }
    @{ Name = "DB Container Up"; Status = ($dbContainer -match "resume_blueprint_postgres") }
    @{ Name = "Extract Container Up"; Status = ($extractContainer -match "resume_blueprint_extract") }
    @{ Name = "localhost:5000/health OK"; Status = $extractHealthOk }
)

$allCriteriaMet = $true
foreach ($c in $criteria) {
    $symbol = if ($c.Status) { "[OK]" } else { "[X]" }
    $color = if ($c.Status) { "Green" } else { "Red" }
    Write-Host "$symbol $($c.Name)" -ForegroundColor $color
    if (-not $c.Status) { $allCriteriaMet = $false }
}

# Check critical path
$keyPathOk = $false
if ($testDocId -and $extractRequestBody) {
    try {
        $finalCheck = Invoke-RestMethod -Uri "$BaseUrl/api/extract" -Method POST -Body $extractRequestBody -ContentType "application/json" -TimeoutSec 30 -ErrorAction SilentlyContinue
        $keyPathOk = ($finalCheck.runId -and $finalCheck.runId -gt 0)
    } catch {
        $keyPathOk = $false
    }
}

if ($keyPathOk) {
    Write-Host "[OK] Real extraction API call returned successful result" -ForegroundColor Green
} else {
    Write-Host "[X] Real extraction API call returned successful result" -ForegroundColor Red
    $allCriteriaMet = $false
}

Write-Host ""
if ($allCriteriaMet -and $FailCount -eq 0) {
    Write-Host "[SUCCESS] System is running normally!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[WARNING] System has issues, please check failed items above" -ForegroundColor Red
    exit 1
}
