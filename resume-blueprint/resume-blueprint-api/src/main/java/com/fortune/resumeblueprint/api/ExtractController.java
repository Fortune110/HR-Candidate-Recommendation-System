package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.ExtractRequest;
import com.fortune.resumeblueprint.api.dto.ExtractResponse;
import com.fortune.resumeblueprint.service.ExtractService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/extract")
public class ExtractController {
    
    private final ExtractService extractService;
    
    public ExtractController(ExtractService extractService) {
        this.extractService = extractService;
    }
    
    /**
     * Extract entities from resume/JD text using spaCy + SkillNER.
     * 
     * POST /api/extract
     * Body: { "documentId": 1, "text": "...", "docType": "RESUME" }
     */
    @PostMapping
    public ExtractResponse extract(@RequestBody @Valid ExtractRequest req) {
        long runId = extractService.extractAndPersist(
                req.documentId(),
                req.text(),
                req.docType() != null ? req.docType() : "RESUME"
        );
        
        return new ExtractResponse(runId, "Extraction completed successfully");
    }
    
    /**
     * Health check for extraction service
     */
    @GetMapping("/health")
    public ExtractResponse health() {
        boolean available = extractService.isExtractorAvailable();
        return new ExtractResponse(
                0L,
                available ? "Extraction service is available" : "Extraction service is unavailable"
        );
    }
}
