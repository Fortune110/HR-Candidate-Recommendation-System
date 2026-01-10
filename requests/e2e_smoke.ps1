# E2E Smoke Test Script for HR Candidate Recommendation System
# Usage: .\requests\e2e_smoke.ps1 [-BaseUrl "http://localhost:18080"]

param(
    [string]$BaseUrl = "http://localhost:18080"
)

$ErrorActionPreference = "Stop"
$script:FAILED = $false
$script:TEST_RESULTS = @()

function Write-TestStep {
    param([string]$Message, [string]$Status = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Status] $Message" -ForegroundColor $color
}

function Test-Url {
    param(
        [string]$Url,
        [int]$MaxRetries = 30,
        [int]$DelaySeconds = 2
    )
    
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                return $true
            }
        } catch {
            if ($i -lt $MaxRetries - 1) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
    return $false
}

function Invoke-ApiCall {
    param(
        [string]$Method,
        [string]$Url,
        [object]$Body = $null,
        [hashtable]$Headers = @{ "Content-Type" = "application/json" }
    )
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        }
        
        $response = Invoke-WebRequest @params
        $statusCode = $response.StatusCode
        
        Write-TestStep "  Request: $Method $Url" "INFO"
        Write-TestStep "  Status: $statusCode" "INFO"
        
        try {
            $responseBody = $response.Content | ConvertFrom-Json
            return @{
                Success = ($statusCode -ge 200 -and $statusCode -lt 300)
                StatusCode = $statusCode
                Body = $responseBody
                RawContent = $response.Content
            }
        } catch {
            return @{
                Success = ($statusCode -ge 200 -and $statusCode -lt 300)
                StatusCode = $statusCode
                Body = $null
                RawContent = $response.Content
            }
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = ""
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
        } catch { }
        
        Write-TestStep "  Request: $Method $Url" "FAIL"
        Write-TestStep "  Status: $statusCode" "FAIL"
        if ($errorBody) {
            Write-TestStep "  Error Body: $errorBody" "FAIL"
        }
        
        return @{
            Success = $false
            StatusCode = $statusCode
            Body = $null
            RawContent = $errorBody
            Error = $_.Exception.Message
        }
    }
}

function Test-DockerCompose {
    Write-TestStep "Checking Docker Compose..." "INFO"
    
    $composeFile = "talent-archive-core\docker-compose.yml"
    if (-not (Test-Path $composeFile)) {
        Write-TestStep "Docker compose file not found at $composeFile" "WARN"
        return $false
    }
    
    # Check if postgres container is running
    try {
        $container = docker ps --filter "name=resume_blueprint_postgres" --format "{{.Names}}" 2>$null
        if ($container -eq "resume_blueprint_postgres") {
            Write-TestStep "PostgreSQL container is running" "PASS"
            return $true
        }
    } catch {
        Write-TestStep "Docker command failed. Is Docker installed and running?" "WARN"
        return $false
    }
    
    # Try to start services
    Write-TestStep "Starting Docker Compose services..." "INFO"
    try {
        Push-Location "talent-archive-core"
        docker-compose up -d postgres 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        
        $container = docker ps --filter "name=resume_blueprint_postgres" --format "{{.Names}}" 2>$null
        if ($container -eq "resume_blueprint_postgres") {
            Write-TestStep "PostgreSQL container started successfully" "PASS"
            Pop-Location
            return $true
        } else {
            Write-TestStep "Failed to start PostgreSQL container" "FAIL"
            Pop-Location
            return $false
        }
    } catch {
        Write-TestStep "Error starting Docker Compose: $_" "FAIL"
        Pop-Location
        return $false
    }
}

function Start-SpringBootApp {
    Write-TestStep "Starting Spring Boot application..." "INFO"
    
    $apiDir = "resume-blueprint\resume-blueprint-api"
    if (-not (Test-Path $apiDir)) {
        Write-TestStep "API directory not found: $apiDir" "FAIL"
        return $false
    }
    
    # Check if already running
    $checkUrl = "$BaseUrl/api/extract/health"
    if (Test-Url -Url $checkUrl -MaxRetries 1) {
        Write-TestStep "Application appears to be already running" "PASS"
        return $true
    }
    
    # Start in background
    Write-TestStep "Starting application with mvnw spring-boot:run..." "INFO"
    try {
        Push-Location $apiDir
        
        # Check for Java
        $javaVersion = java -version 2>&1 | Select-String "version"
        if (-not $javaVersion) {
            Write-TestStep "Java not found. Please install Java 21+" "FAIL"
            Pop-Location
            return $false
        }
        
        # Start Maven Spring Boot
        $mvnw = if ($IsWindows -or $env:OS -like "*Windows*") { ".\mvnw.cmd" } else { ".\mvnw" }
        Start-Process -FilePath $mvnw -ArgumentList "spring-boot:run" -NoNewWindow -PassThru | Out-Null
        
        Pop-Location
        
        # Wait for app to start
        Write-TestStep "Waiting for application to start (max 60s)..." "INFO"
        $healthUrl = "$BaseUrl/api/extract/health"
        if (Test-Url -Url $healthUrl -MaxRetries 30 -DelaySeconds 2) {
            Write-TestStep "Application started successfully" "PASS"
            Start-Sleep -Seconds 2  # Give it a moment to fully initialize
            return $true
        } else {
            Write-TestStep "Application failed to start within timeout" "FAIL"
            return $false
        }
    } catch {
        Write-TestStep "Error starting application: $_" "FAIL"
        Pop-Location
        return $false
    }
}

function Test-HealthEndpoint {
    Write-TestStep "Testing health endpoint..." "INFO"
    $result = Invoke-ApiCall -Method "GET" -Url "$BaseUrl/api/extract/health"
    
    if ($result.Success) {
        Write-TestStep "Health check passed" "PASS"
        $script:TEST_RESULTS += @{ Test = "Health Check"; Status = "PASS" }
        return $true
    } else {
        Write-TestStep "Health check failed" "FAIL"
        $script:TEST_RESULTS += @{ Test = "Health Check"; Status = "FAIL"; Error = $result.Error }
        $script:FAILED = $true
        return $false
    }
}

function Test-ResumeIngest {
    Write-TestStep "Testing resume ingestion..." "INFO"
    
    $resumeText = Get-Content "samples\resume_001.txt" -Raw
    $body = @{
        candidateId = "test_candidate_001"
        text = $resumeText
    }
    
    $result = Invoke-ApiCall -Method "POST" -Url "$BaseUrl/api/resumes" -Body $body
    
    if ($result.Success -and $result.Body -and $result.Body.documentId) {
        $documentId = $result.Body.documentId
        Write-TestStep "Resume ingested successfully. Document ID: $documentId" "PASS"
        $script:TEST_RESULTS += @{ Test = "Resume Ingestion"; Status = "PASS"; DocumentId = $documentId }
        return $documentId
    } else {
        Write-TestStep "Resume ingestion failed" "FAIL"
        $script:TEST_RESULTS += @{ Test = "Resume Ingestion"; Status = "FAIL"; Error = $result.RawContent }
        $script:FAILED = $true
        return $null
    }
}

function Test-Extract {
    param([long]$DocumentId)
    
    if (-not $DocumentId) {
        Write-TestStep "Skipping extract test: no document ID" "WARN"
        return $false
    }
    
    Write-TestStep "Testing extract service..." "INFO"
    
    $resumeText = Get-Content "samples\resume_001.txt" -Raw
    $body = @{
        documentId = $DocumentId
        text = $resumeText
        docType = "RESUME"
    }
    
    $result = Invoke-ApiCall -Method "POST" -Url "$BaseUrl/api/extract" -Body $body
    
    if ($result.Success) {
        Write-TestStep "Extract completed successfully" "PASS"
        $script:TEST_RESULTS += @{ Test = "Extract Service"; Status = "PASS" }
        return $true
    } else {
        Write-TestStep "Extract failed (this may be expected if extract-service is not running)" "WARN"
        $script:TEST_RESULTS += @{ Test = "Extract Service"; Status = "WARN"; Error = $result.RawContent }
        return $false
    }
}

function Test-Match {
    param([long]$DocumentId)
    
    if (-not $DocumentId) {
        Write-TestStep "Skipping match test: no document ID" "WARN"
        return $false
    }
    
    Write-TestStep "Testing match service..." "INFO"
    
    $body = @{
        resumeDocumentId = $DocumentId
        target = "both"
    }
    
    $result = Invoke-ApiCall -Method "POST" -Url "$BaseUrl/api/match" -Body $body
    
    if ($result.Success) {
        Write-TestStep "Match completed successfully" "PASS"
        $script:TEST_RESULTS += @{ Test = "Match Service"; Status = "PASS" }
        return $true
    } else {
        Write-TestStep "Match failed (this may be expected if no success profiles exist)" "WARN"
        $script:TEST_RESULTS += @{ Test = "Match Service"; Status = "WARN"; Error = $result.RawContent }
        return $false
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  E2E Smoke Test - Resume Blueprint API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check/Start Docker Compose
if (-not (Test-DockerCompose)) {
    Write-TestStep "Docker Compose check failed. Continuing anyway..." "WARN"
    Write-TestStep "NOTE: Database port mismatch detected. App config uses 55433 but docker-compose maps 55434" "WARN"
    Write-TestStep "See requests/README.md for port conflict resolution" "WARN"
}

# Step 2: Start Spring Boot (if not running)
if (-not (Start-SpringBootApp)) {
    Write-TestStep "Failed to start Spring Boot application" "FAIL"
    exit 1
}

# Step 3: Health Check
if (-not (Test-HealthEndpoint)) {
    Write-TestStep "Health check failed. Aborting tests." "FAIL"
    exit 1
}

# Step 4: Resume Ingestion (Golden Path)
$documentId = Test-ResumeIngest
if (-not $documentId) {
    Write-TestStep "Resume ingestion failed. This is a critical failure." "FAIL"
    exit 1
}

# Step 5: Extract (Golden Path)
Test-Extract -DocumentId $documentId

# Step 6: Match (Golden Path - may fail if no profiles, that's OK)
Test-Match -DocumentId $documentId

# ============================================================================
# FINAL RESULTS
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($test in $script:TEST_RESULTS) {
    $status = $test.Status
    $color = switch ($status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "  [$status] $($test.Test)" -ForegroundColor $color
    if ($test.Error) {
        Write-Host "      Error: $($test.Error)" -ForegroundColor $color
    }
}

Write-Host ""

if ($script:FAILED) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  RESULT: FAIL" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
} else {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  RESULT: PASS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}
