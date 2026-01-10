# Test script for extract-service
# Tests health check and extraction endpoints with sample resume and JD

$baseUrl = "http://localhost:5000"

Write-Host "=== Testing Extract Service ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Check
Write-Host "1. Testing GET /health" -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -UseBasicParsing
    $healthJson = $healthResponse.Content | ConvertFrom-Json
    Write-Host "Status Code: $($healthResponse.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $healthJson | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 2: Extract from Resume
Write-Host "2. Testing POST /extract with RESUME" -ForegroundColor Yellow
$resumeText = @"
John Doe
Email: john.doe@email.com | Location: Sydney, AU | LinkedIn: linkedin.com/in/johndoe

Summary:
Backend Engineer with 3+ years experience building REST APIs and data pipelines.

Skills:
Python3, SQL (PostgreSQL), Docker, Linux, Git, AWS

Experience:
- Backend Engineer, ABC Fintech (2022-2025)
  Built Python FastAPI services, optimized SQL queries, deployed with Docker on Linux.
  Developed ETL jobs and improved latency by 30%.

Education:
Bachelor's degree in Computer Science (2018-2022)
"@

$resumeBody = @{
    text = $resumeText
    doc_type = "RESUME"
} | ConvertTo-Json

try {
    $resumeResponse = Invoke-WebRequest -Uri "$baseUrl/extract" -Method POST -Body $resumeBody -ContentType "application/json" -UseBasicParsing
    $resumeJson = $resumeResponse.Content | ConvertFrom-Json
    Write-Host "Status Code: $($resumeResponse.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $resumeJson | ConvertTo-Json -Depth 10
    Write-Host ""
    Write-Host "Summary: $($resumeJson.summary)" -ForegroundColor Cyan
    Write-Host "Extracted $($resumeJson.entities.Count) entities" -ForegroundColor Cyan
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

# Test 3: Extract from JD
Write-Host "3. Testing POST /extract with JD" -ForegroundColor Yellow
$jdText = @"
Role: Backend Engineer (Python)
Requirements:
- 3-5 years of backend development experience
- Strong Python and SQL skills
- Experience with Docker and Linux
- Git and CI/CD experience
- Bachelor's degree required
Nice to have:
- AWS, FastAPI, data pipeline experience
"@

$jdBody = @{
    text = $jdText
    doc_type = "JD"
} | ConvertTo-Json

try {
    $jdResponse = Invoke-WebRequest -Uri "$baseUrl/extract" -Method POST -Body $jdBody -ContentType "application/json" -UseBasicParsing
    $jdJson = $jdResponse.Content | ConvertFrom-Json
    Write-Host "Status Code: $($jdResponse.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $jdJson | ConvertTo-Json -Depth 10
    Write-Host ""
    Write-Host "Summary: $($jdJson.summary)" -ForegroundColor Cyan
    Write-Host "Extracted $($jdJson.entities.Count) entities" -ForegroundColor Cyan
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "=== Tests Complete ===" -ForegroundColor Cyan
