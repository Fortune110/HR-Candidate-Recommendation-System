# Smoke Test Script for PDF Pipeline API
# Usage: .\scripts\smoke_test_pdf_pipeline.ps1 -PdfPath "path\to\resume.pdf"
#        .\scripts\smoke_test_pdf_pipeline.ps1 -PdfPath "C:\path\to\resume.pdf" -BaseUrl "http://localhost:18080"

param(
    [Parameter(Mandatory=$true)]
    [string]$PdfPath,
    [string]$BaseUrl = "http://localhost:18080"
)

$ErrorActionPreference = "Stop"

# Check if PDF path is provided and exists
if (-not $PdfPath -or -not (Test-Path $PdfPath)) {
    Write-Host "Error: PDF file does not exist at: $PdfPath" -ForegroundColor Red
    Write-Host "Usage: .\scripts\smoke_test_pdf_pipeline.ps1 -PdfPath 'path\to\resume.pdf'" -ForegroundColor Yellow
    exit 1
}

Write-Host "PDF Pipeline Smoke Test" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "PDF Path: $PdfPath" -ForegroundColor Gray
Write-Host ""

# Call the API
# Field names verified from PdfPipelineController.java:
# - candidateId: @RequestParam("candidateId") String (required)
# - jobId: @RequestParam(value = "jobId", required = false) String (optional)
# - docType: @RequestParam(value = "docType", required = false, defaultValue = "candidate_resume") String (optional)
# - file: @RequestPart("file") MultipartFile (required)
$uri = "$BaseUrl/api/pipeline/ingest-pdf-and-match"
$formData = @{
    candidateId = "smoke_test_script"
    jobId = "Java Backend Engineer"
    docType = "candidate_resume"
    file = Get-Item $PdfPath
}

try {
    Write-Host "Calling API: POST $uri" -ForegroundColor Gray
    Write-Host "Form fields: candidateId, jobId, docType, file" -ForegroundColor Gray
    Write-Host ""
    
    $response = Invoke-RestMethod -Uri $uri -Method Post -Form $formData -ErrorAction Stop
    
    # Print key fields
    Write-Host "Response (Status: 200 OK):" -ForegroundColor Green
    Write-Host "  traceId: $($response.traceId)" -ForegroundColor White
    Write-Host "  ok: $($response.ok)" -ForegroundColor $(if ($response.ok) { "Green" } else { "Red" })
    Write-Host "  message: $($response.message)" -ForegroundColor White
    
    if ($response.ok) {
        Write-Host "  documentId: $($response.documentId)" -ForegroundColor Gray
        Write-Host "  extractRunId: $($response.extractRunId)" -ForegroundColor Gray
        Write-Host "  textLength: $($response.textLength)" -ForegroundColor Gray
        Write-Host "  matchResult: $(if ($response.matchResult) { 'present' } else { 'null' })" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "✅ PASS: Pipeline call succeeded" -ForegroundColor Green
    exit 0
} catch {
    Write-Host ""
    Write-Host "❌ FAIL: Error calling API" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    # Check HTTP status code
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
        Write-Host "HTTP Status Code: $statusCode" -ForegroundColor Yellow
        
        if ($statusCode -eq 400) {
            Write-Host ""
            Write-Host "400 Bad Request - Likely multipart field name mismatch" -ForegroundColor Yellow
            Write-Host "Expected fields (from PdfPipelineController.java):" -ForegroundColor Yellow
            Write-Host "  - candidateId (required)" -ForegroundColor Yellow
            Write-Host "  - jobId (optional)" -ForegroundColor Yellow
            Write-Host "  - docType (optional, default: candidate_resume)" -ForegroundColor Yellow
            Write-Host "  - file (required, @RequestPart)" -ForegroundColor Yellow
        } elseif ($statusCode -eq 500) {
            Write-Host ""
            Write-Host "500 Internal Server Error - Check Spring Boot logs:" -ForegroundColor Yellow
            Write-Host "  Location: resume-blueprint\resume-blueprint-api\logs\" -ForegroundColor Yellow
            Write-Host "  Or console output if running: .\mvnw.cmd spring-boot:run" -ForegroundColor Yellow
            Write-Host "  Search for: 'pdf-pipeline' in logs" -ForegroundColor Yellow
        }
    }
    
    # Try to parse error response
    if ($_.ErrorDetails.Message) {
        try {
            $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Host ""
            Write-Host "Error Response:" -ForegroundColor Yellow
            Write-Host "  traceId: $($errorResponse.traceId)" -ForegroundColor White
            Write-Host "  ok: $($errorResponse.ok)" -ForegroundColor Red
            Write-Host "  message: $($errorResponse.message)" -ForegroundColor White
        } catch {
            Write-Host "  Raw response: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
        }
    }
    
    exit 1
}
