package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.AnalyzeRequest;
import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import com.fortune.resumeblueprint.api.dto.ResumeDocumentResponse;
import com.fortune.resumeblueprint.api.dto.ResumeIngestRequest;
import com.fortune.resumeblueprint.api.dto.ResumeIngestResponse;
import com.fortune.resumeblueprint.api.dto.ResumeSummaryResponse;
import com.fortune.resumeblueprint.service.ResumeService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

import static org.springframework.http.HttpStatus.NOT_FOUND;

@RestController
@RequestMapping("/api/resumes")
public class ResumeController {

    private final ResumeService service;

    public ResumeController(ResumeService service) {
        this.service = service;
    }

    @PostMapping
    public ResumeIngestResponse ingest(@RequestBody @Valid ResumeIngestRequest req) {
        long documentId = service.ingest(req.candidateId(), req.text());
        return new ResumeIngestResponse(documentId);
    }

    @GetMapping("/{documentId}")
    public ResumeDocumentResponse getDocument(@PathVariable long documentId) {
        return service.findDocument(documentId)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "Resume document not found"));
    }

    @GetMapping
    public List<ResumeSummaryResponse> listDocuments(
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(defaultValue = "0") int offset
    ) {
        int safeLimit = Math.min(Math.max(limit, 1), 200);
        int safeOffset = Math.max(offset, 0);
        return service.listDocuments(safeLimit, safeOffset);
    }

    @PostMapping("/{documentId}/analyze/bootstrap")
    public AnalyzeResponse analyzeBootstrap(@PathVariable long documentId,
                                           @RequestBody @Valid AnalyzeRequest req) {
        return service.analyzeBootstrap(documentId, req.text());
    }

    @PostMapping("/{documentId}/analyze/baseline")
    public AnalyzeResponse analyzeBaseline(@PathVariable long documentId,
                                          @RequestParam long baselineSetId,
                                          @RequestBody @Valid AnalyzeRequest req) {
        return service.analyzeBaseline(documentId, req.text(), baselineSetId);
    }
}
