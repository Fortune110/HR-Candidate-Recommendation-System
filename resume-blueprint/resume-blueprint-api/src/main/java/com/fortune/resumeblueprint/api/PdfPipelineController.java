package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.MatchResponse;
import com.fortune.resumeblueprint.api.dto.PdfPipelineResponse;
import com.fortune.resumeblueprint.infra.PdfTextExtractor;
import com.fortune.resumeblueprint.service.ExtractService;
import com.fortune.resumeblueprint.service.MatchService;
import com.fortune.resumeblueprint.service.ResumeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Controller for PDF pipeline: ingest PDF → extract → match
 */
@RestController
@RequestMapping("/api/pipeline")
public class PdfPipelineController {

    private static final Logger log = LoggerFactory.getLogger(PdfPipelineController.class);
    
    private final PdfTextExtractor pdfTextExtractor;
    private final ResumeService resumeService;
    private final ExtractService extractService;
    private final MatchService matchService;
    
    public PdfPipelineController(
            PdfTextExtractor pdfTextExtractor,
            ResumeService resumeService,
            ExtractService extractService,
            MatchService matchService
    ) {
        this.pdfTextExtractor = pdfTextExtractor;
        this.resumeService = resumeService;
        this.extractService = extractService;
        this.matchService = matchService;
    }
    
    /**
     * Process PDF: extract text → ingest → extract entities → match
     * 
     * POST /api/pipeline/ingest-pdf-and-match
     * Content-Type: multipart/form-data
     * 
     * Parameters:
     * - candidateId: String (required)
     * - jobId: String (optional, used as roleFilter for match)
     * - docType: String (optional, default: "candidate_resume")
     * - file: MultipartFile (required, PDF file)
     */
    @PostMapping(value = "/ingest-pdf-and-match", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PdfPipelineResponse ingestPdfAndMatch(
            @RequestParam("candidateId") String candidateId,
            @RequestParam(value = "jobId", required = false) String jobId,
            @RequestParam(value = "docType", required = false, defaultValue = "candidate_resume") String docType,
            @RequestPart("file") MultipartFile file
    ) {
        String traceId = UUID.randomUUID().toString();
        log.info("pdf-pipeline start traceId={} candidateId={} jobId={} docType={} filename={}",
                traceId, candidateId, jobId, docType, file.getOriginalFilename());

        if (file.isEmpty()) {
            return PdfPipelineResponse.error("Empty upload; PDF file is required.", traceId, 0);
        }

        String extractDocType = normalizeDocType(docType);
        if (extractDocType == null) {
            return PdfPipelineResponse.error("Unsupported docType: " + docType, traceId, 0);
        }

        // 1. Extract text from PDF
        String text;
        try (InputStream inputStream = new BufferedInputStream(file.getInputStream())) {
            if (!isPdfFile(file, inputStream)) {
                return PdfPipelineResponse.error("Invalid file type; expected a PDF upload.", traceId, 0);
            }
            text = pdfTextExtractor.extract(inputStream);
        } catch (IOException e) {
            return PdfPipelineResponse.error("Failed to read PDF: " + e.getMessage(), traceId, 0);
        }

        int textLength = text != null ? text.length() : 0;
        
        // 2. Check if text is too short (likely scanned PDF)
        if (textLength < 50) {
            return PdfPipelineResponse.error("Extracted text is too short (" + textLength + " chars). Likely scanned PDF, OCR not implemented.", traceId, textLength);
        }
        
        // 3. Ingest text to database
        long documentId = resumeService.ingest(candidateId, text);
        log.info("pdf-pipeline ingest done traceId={} documentId={} textLength={}", traceId, documentId, textLength);
        
        // 4. Extract entities using ExtractService
        long extractRunId = extractService.extractAndPersist(documentId, text, extractDocType);
        log.info("pdf-pipeline extract done traceId={} extractRunId={}", traceId, extractRunId);
        
        // 5. Match against success cohorts
        // Use jobId as roleFilter if provided
        MatchResponse matchResponse = null;
        String message = "PDF processed successfully";
        if (jobId != null && !jobId.isBlank()) {
            var matchResult = matchService.matchResume(documentId, "both", jobId, null);
            
            // 6. Convert MatchService.MatchResult to MatchResponse
            List<MatchResponse.ProfileMatch> responseMatches = matchResult.matches().stream()
                    .map(m -> new MatchResponse.ProfileMatch(
                            m.source(),
                            m.score(),
                            m.overlapScore(),
                            m.gapPenalty(),
                            m.bonusScore(),
                            m.topOverlaps(),
                            m.topGaps(),
                            m.topStrengths()
                    ))
                    .toList();
            
            matchResponse = new MatchResponse(matchResult.matchRunId(), responseMatches);
            log.info("pdf-pipeline match done traceId={} matchRunId={}", traceId, matchResult.matchRunId());
        } else {
            message = "PDF ingested and extracted; jobId not provided, skipped match.";
            log.info("pdf-pipeline match skipped traceId={}", traceId);
        }
        
        // 7. Return success response
        return PdfPipelineResponse.success(documentId, extractRunId, textLength, matchResponse, message, traceId);
    }

    private static String normalizeDocType(String docType) {
        if (docType == null) {
            return "RESUME";
        }
        String normalized = docType.trim().toLowerCase(Locale.ROOT);
        return switch (normalized) {
            case "candidate_resume", "resume" -> "RESUME";
            case "jd", "job_description", "job" -> "JD";
            default -> null;
        };
    }

    private static boolean isPdfFile(MultipartFile file, InputStream inputStream) throws IOException {
        String name = file.getOriginalFilename();
        if (name != null && name.toLowerCase(Locale.ROOT).endsWith(".pdf")) {
            return true;
        }
        if (!inputStream.markSupported()) {
            return false;
        }
        inputStream.mark(8);
        byte[] header = inputStream.readNBytes(4);
        inputStream.reset();
        return header.length == 4
                && header[0] == 0x25
                && header[1] == 0x50
                && header[2] == 0x44
                && header[3] == 0x46;
    }
}
