# Smoke Test Script for PDF Pipeline API
# Usage: .\scripts\smoke_pipeline.ps1
#        $env:RESUME_PDF_PATH="path\to\resume.pdf"; .\scripts\smoke_pipeline.ps1

param(
    [string]$BaseUrl = "http://localhost:18080",
    [string]$PdfPath = $env:RESUME_PDF_PATH
)

$ErrorActionPreference = "Stop"

# Check if PDF path is provided
if (-not $PdfPath -or -not (Test-Path $PdfPath)) {
    Write-Host "Error: RESUME_PDF_PATH environment variable not set or file does not exist" -ForegroundColor Red
    Write-Host "Usage: `$env:RESUME_PDF_PATH='path\to\resume.pdf'; .\scripts\smoke_pipeline.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "PDF Pipeline Smoke Test" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "PDF Path: $PdfPath" -ForegroundColor Gray
Write-Host ""

# Call the API
$uri = "$BaseUrl/api/pipeline/ingest-pdf-and-match"
$formData = @{
    candidateId = "smoke_test_script"
    jobId = "Java Backend Engineer"
    docType = "candidate_resume"
    file = Get-Item $PdfPath
}

try {
    Write-Host "Calling API: POST $uri" -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri $uri -Method Post -Form $formData -ErrorAction Stop
    
    # Print key fields
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Green
    Write-Host "  traceId: $($response.traceId)" -ForegroundColor White
    Write-Host "  ok: $($response.ok)" -ForegroundColor $(if ($response.ok) { "Green" } else { "Red" })
    Write-Host "  message: $($response.message)" -ForegroundColor White
    
    if ($response.ok) {
        Write-Host "  documentId: $($response.documentId)" -ForegroundColor Gray
        Write-Host "  extractRunId: $($response.extractRunId)" -ForegroundColor Gray
        Write-Host "  textLength: $($response.textLength)" -ForegroundColor Gray
        Write-Host "  matchResult: $(if ($response.matchResult) { 'present' } else { 'null' })" -ForegroundColor Gray
    }
    
    exit 0
} catch {
    Write-Host ""
    Write-Host "Error calling API:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
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
