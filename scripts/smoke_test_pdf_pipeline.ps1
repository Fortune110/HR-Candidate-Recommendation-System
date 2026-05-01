<#
Usage examples:
  ./scripts/smoke_test_pdf_pipeline.ps1 -PdfPath "./samples/resume.pdf"
  ./scripts/smoke_test_pdf_pipeline.ps1 -PdfPath "C:\files\resume.pdf" -BaseUrl "http://localhost:18080"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PdfPath,

    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://localhost:18080"
)

$ErrorActionPreference = "Stop"

function Write-ErrorAndExit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 1
    )

    Write-Error $Message
    exit $ExitCode
}

if (-not (Test-Path -Path $PdfPath -PathType Leaf)) {
    Write-ErrorAndExit "PDF file not found: $PdfPath"
}

$healthUrl = "$BaseUrl/api/extract/health"
$timeoutSec = 5

try {
    $healthResponse = Invoke-WebRequest -Uri $healthUrl -Method Get -TimeoutSec $timeoutSec -ErrorAction Stop
} catch {
    Write-ErrorAndExit "Health check failed for $healthUrl. $($_.Exception.Message)"
}

if (-not $healthResponse.StatusCode -or $healthResponse.StatusCode -lt 200 -or $healthResponse.StatusCode -ge 300) {
    Write-ErrorAndExit "Health check returned non-2xx status code: $($healthResponse.StatusCode)"
}

$pipelineUrl = "$BaseUrl/api/pipeline/ingest-pdf-and-match"

try {
    $pipelineResponse = Invoke-WebRequest -Uri $pipelineUrl -Method Post -TimeoutSec $timeoutSec -Form @{ file = Get-Item -LiteralPath $PdfPath } -ErrorAction Stop
} catch {
    Write-ErrorAndExit "PDF upload failed for $pipelineUrl. $($_.Exception.Message)"
}

Write-Host "Status Code: $($pipelineResponse.StatusCode)"
Write-Host "Response Body:"
Write-Host $pipelineResponse.Content

if (-not $pipelineResponse.StatusCode -or $pipelineResponse.StatusCode -lt 200 -or $pipelineResponse.StatusCode -ge 300) {
    Write-ErrorAndExit "PDF upload returned non-2xx status code: $($pipelineResponse.StatusCode)"
}

try {
    $jsonResponse = $pipelineResponse.Content | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-ErrorAndExit "Failed to parse JSON response. $($_.Exception.Message)"
}

Write-Host "Pretty JSON:"
Write-Host ($jsonResponse | ConvertTo-Json -Depth 10)

$foundKeys = @()
if ($null -ne $jsonResponse.PSObject -and $null -ne $jsonResponse.PSObject.Properties) {
    $foundKeys = $jsonResponse.PSObject.Properties.Name
}

$normalizedKeys = $foundKeys | ForEach-Object { $_.ToLowerInvariant() }
$requiredKeys = @(
    "final_score",
    "finalscore",
    "matchrunid",
    "match_run_id",
    "documentid",
    "document_id",
    "runid",
    "run_id"
)

$hasRequiredKey = $false
foreach ($key in $requiredKeys) {
    if ($normalizedKeys -contains $key) {
        $hasRequiredKey = $true
        break
    }
}

if (-not $hasRequiredKey) {
    $foundKeysDisplay = if ($foundKeys.Count -gt 0) { $foundKeys -join ", " } else { "(none)" }
    Write-ErrorAndExit "Response JSON missing expected keys. Found keys: $foundKeysDisplay"
}

exit 0
