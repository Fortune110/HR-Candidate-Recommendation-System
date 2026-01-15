# System Verification Script
# Verify Spring Boot application, Flyway migrations and API endpoints

$BaseUrl = "http://127.0.0.1:18080"
$PassCount = 0
$FailCount = 0
$WarnCount = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    
    Write-Host "[$Status] $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "  $Message" -ForegroundColor Gray
    }
    
    switch ($Status) {
        "PASS" { $script:PassCount++ }
        "FAIL" { $script:FailCount++ }
        "WARN" { $script:WarnCount++ }
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  System Verification Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check if application is running
Write-Host "1. Checking application status..." -ForegroundColor Yellow
$portCheck = netstat -ano | findstr :18080 | findstr LISTENING
if ($portCheck) {
    Write-TestResult "Port 18080 Listening" "PASS" "Application is running"
} else {
    Write-TestResult "Port 18080 Listening" "FAIL" "Application is not running"
    exit 1
}

# 2. Health check endpoint
Write-Host "`n2. Testing health check endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/extract/health" -Method GET -ErrorAction Stop
    if ($response.message) {
        Write-TestResult "Health Check Endpoint" "PASS" "Response: $($response.message)"
    } else {
        Write-TestResult "Health Check Endpoint" "WARN" "Unexpected response format"
    }
} catch {
    Write-TestResult "Health Check Endpoint" "FAIL" "Error: $($_.Exception.Message)"
}

# 3. Test /upload page
Write-Host "`n3. Testing /upload page..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/upload" -Method GET -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-TestResult "/upload Page" "PASS" "HTTP $($response.StatusCode), Content-Length: $($response.RawContentLength)"
    } else {
        Write-TestResult "/upload Page" "FAIL" "HTTP $($response.StatusCode)"
    }
} catch {
    Write-TestResult "/upload Page" "FAIL" "Error: $($_.Exception.Message)"
}

# 4. Test Swagger UI
Write-Host "`n4. Testing Swagger UI..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/swagger-ui/index.html" -Method GET -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-TestResult "Swagger UI" "PASS" "HTTP $($response.StatusCode)"
    } else {
        Write-TestResult "Swagger UI" "FAIL" "HTTP $($response.StatusCode)"
    }
} catch {
    Write-TestResult "Swagger UI" "FAIL" "Error: $($_.Exception.Message)"
}

# 5. Test Swagger API documentation
Write-Host "`n5. Testing Swagger API documentation..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/v3/api-docs" -Method GET -ErrorAction Stop
    if ($response.paths) {
        $pathCount = ($response.paths | Get-Member -MemberType NoteProperty).Count
        Write-TestResult "Swagger API Documentation" "PASS" "Found $pathCount API endpoints"
    } else {
        Write-TestResult "Swagger API Documentation" "WARN" "Unexpected API documentation format"
    }
} catch {
    Write-TestResult "Swagger API Documentation" "FAIL" "Error: $($_.Exception.Message)"
}

# 6. Test resume upload API
Write-Host "`n6. Testing resume upload API..." -ForegroundColor Yellow
try {
    $body = @{
        candidateId = "verify_test_$(Get-Date -Format 'yyyyMMddHHmmss')"
        text = "John Doe`nSoftware Engineer`n5 years experience in Java, Spring Boot, PostgreSQL"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/resumes" -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop
    if ($response.documentId) {
        Write-TestResult "Resume Upload API" "PASS" "Document ID: $($response.documentId)"
        $script:DocumentId = $response.documentId
    } else {
        Write-TestResult "Resume Upload API" "FAIL" "No documentId returned"
    }
} catch {
    Write-TestResult "Resume Upload API" "FAIL" "Error: $($_.Exception.Message)"
    $script:DocumentId = $null
}

# 7. Verify database connection and table structure
Write-Host "`n7. Verifying database status..." -ForegroundColor Yellow
try {
    $dbCheck = docker compose -f "C:\HR-Candidate-Recommendation-System\talent-archive-core\docker-compose.yml" exec -T postgres psql -U rb_user -d resume_blueprint_db -c "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tableCount = ($dbCheck | Select-String -Pattern "\d+").Matches[0].Value
        Write-TestResult "Database Connection" "PASS" "Found $tableCount tables"
    } else {
        Write-TestResult "Database Connection" "FAIL" "Cannot connect to database"
    }
} catch {
    Write-TestResult "Database Connection" "WARN" "Docker command execution failed"
}

# 8. Verify V14 view
Write-Host "`n8. Verifying V14 ml_training_examples_v1 view..." -ForegroundColor Yellow
try {
    $viewCheck = docker compose -f "C:\HR-Candidate-Recommendation-System\talent-archive-core\docker-compose.yml" exec -T postgres psql -U rb_user -d resume_blueprint_db -c "\dv ml_training_examples_v1" 2>&1
    if ($viewCheck -match "ml_training_examples_v1") {
        Write-TestResult "V14 View" "PASS" "View created"
    } else {
        Write-TestResult "V14 View" "FAIL" "View does not exist"
    }
} catch {
    Write-TestResult "V14 View" "WARN" "Cannot verify view"
}

# 9. Verify Flyway migration history
Write-Host "`n9. Verifying Flyway migration history..." -ForegroundColor Yellow
try {
    $flywayCheck = docker compose -f "C:\HR-Candidate-Recommendation-System\talent-archive-core\docker-compose.yml" exec -T postgres psql -U rb_user -d resume_blueprint_db -c "SELECT version, description FROM flyway_schema_history WHERE version = '14';" 2>&1
    if ($flywayCheck -match "ml training view") {
        Write-TestResult "Flyway V14 Migration" "PASS" "V14 migration successfully recorded"
    } else {
        Write-TestResult "Flyway V14 Migration" "FAIL" "V14 migration record not found"
    }
} catch {
    Write-TestResult "Flyway V14 Migration" "WARN" "Cannot verify migration history"
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $PassCount" -ForegroundColor Green
Write-Host "Failed: $FailCount" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host "Warnings: $WarnCount" -ForegroundColor $(if ($WarnCount -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($FailCount -eq 0) {
    Write-Host "✓ All critical tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed, please check the errors above" -ForegroundColor Red
    exit 1
}
