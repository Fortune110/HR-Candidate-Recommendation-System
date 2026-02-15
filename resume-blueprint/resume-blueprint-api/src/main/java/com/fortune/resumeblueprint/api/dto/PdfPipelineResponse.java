package com.fortune.resumeblueprint.api.dto;

/**
 * Response for PDF pipeline processing.
 */
public record PdfPipelineResponse(
        boolean ok,
        String message,
        String traceId,
        Long documentId,
        Long extractRunId,
        Integer textLength,
        MatchResponse matchResult
) {
    public static PdfPipelineResponse success(
            long documentId,
            long extractRunId,
            int textLength,
            MatchResponse matchResult,
            String message,
            String traceId
    ) {
        return new PdfPipelineResponse(true, message, traceId, documentId, extractRunId, textLength, matchResult);
    }
    
    public static PdfPipelineResponse error(String message, String traceId, Integer textLength) {
        return new PdfPipelineResponse(false, message, traceId, null, null, textLength, null);
    }
}
