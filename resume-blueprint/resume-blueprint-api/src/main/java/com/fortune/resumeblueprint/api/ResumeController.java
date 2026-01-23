package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.AnalyzeRequest;
import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import com.fortune.resumeblueprint.api.dto.ResumeDocumentResponse;
import com.fortune.resumeblueprint.api.dto.ResumeIngestRequest;
import com.fortune.resumeblueprint.api.dto.ResumeIngestResponse;
import com.fortune.resumeblueprint.api.dto.ResumeSummaryResponse;
import com.fortune.resumeblueprint.service.ResumeService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

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
    public ResumeDocumentResponse getById(@PathVariable long documentId) {
        return service.getResume(documentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Resume not found"));
    }

    @GetMapping
    public List<ResumeSummaryResponse> list(@RequestParam(defaultValue = "50") int limit) {
        return service.listResumes(limit);
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
