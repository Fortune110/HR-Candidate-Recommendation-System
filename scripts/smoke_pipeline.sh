#!/bin/bash
# Smoke Test Script for PDF Pipeline API
# Usage: ./scripts/smoke_pipeline.sh
#        RESUME_PDF_PATH=path/to/resume.pdf ./scripts/smoke_pipeline.sh

set -e

BASE_URL="${BASE_URL:-http://localhost:18080}"
PDF_PATH="${RESUME_PDF_PATH:-}"

# Check if PDF path is provided
if [ -z "$PDF_PATH" ] || [ ! -f "$PDF_PATH" ]; then
    echo "Error: RESUME_PDF_PATH environment variable not set or file does not exist" >&2
    echo "Usage: RESUME_PDF_PATH=path/to/resume.pdf ./scripts/smoke_pipeline.sh" >&2
    exit 1
fi

echo "PDF Pipeline Smoke Test"
echo "======================="
echo "Base URL: $BASE_URL"
echo "PDF Path: $PDF_PATH"
echo ""

# Call the API
URI="$BASE_URL/api/pipeline/ingest-pdf-and-match"

echo "Calling API: POST $URI"

# Check if jq is available for JSON parsing
if command -v jq >/dev/null 2>&1; then
    RESPONSE=$(curl -s -X POST "$URI" \
        -F "candidateId=smoke_test_script" \
        -F "jobId=Java Backend Engineer" \
        -F "docType=candidate_resume" \
        -F "file=@$PDF_PATH" \
        -w "\nHTTP_STATUS:%{http_code}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    JSON_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
    
    echo ""
    echo "Response:"
    echo "  traceId: $(echo "$JSON_BODY" | jq -r '.traceId // "N/A"')"
    echo "  ok: $(echo "$JSON_BODY" | jq -r '.ok // false')"
    echo "  message: $(echo "$JSON_BODY" | jq -r '.message // "N/A"')"
    
    OK=$(echo "$JSON_BODY" | jq -r '.ok // false')
    if [ "$OK" = "true" ]; then
        echo "  documentId: $(echo "$JSON_BODY" | jq -r '.documentId // "null"')"
        echo "  extractRunId: $(echo "$JSON_BODY" | jq -r '.extractRunId // "null"')"
        echo "  textLength: $(echo "$JSON_BODY" | jq -r '.textLength // "null"')"
        MATCH_RESULT=$(echo "$JSON_BODY" | jq -r 'if .matchResult == null then "null" else "present" end')
        echo "  matchResult: $MATCH_RESULT"
    fi
else
    # Fallback without jq - just show raw response
    RESPONSE=$(curl -s -X POST "$URI" \
        -F "candidateId=smoke_test_script" \
        -F "jobId=Java Backend Engineer" \
        -F "docType=candidate_resume" \
        -F "file=@$PDF_PATH")
    
    echo ""
    echo "Response (raw JSON):"
    echo "$RESPONSE"
    echo ""
    echo "Note: Install 'jq' for formatted output: brew install jq (macOS) or apt-get install jq (Linux)"
fi

# Check HTTP status
if [ "$HTTP_STATUS" != "200" ]; then
    echo ""
    echo "Warning: HTTP status code is $HTTP_STATUS (expected 200)" >&2
    exit 1
fi

exit 0
