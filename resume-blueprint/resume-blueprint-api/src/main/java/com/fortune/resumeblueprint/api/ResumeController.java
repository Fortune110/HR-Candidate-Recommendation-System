package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.AnalyzeRequest;
import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import com.fortune.resumeblueprint.api.dto.ResumeDocumentResponse;
import com.fortune.resumeblueprint.api.dto.ResumeIngestRequest;
import com.fortune.resumeblueprint.api.dto.ResumeIngestResponse;
import com.fortune.resumeblueprint.api.dto.ResumeSummaryResponse;
import com.fortune.resumeblueprint.service.ResumeService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.List;

import static org.springframework.http.HttpStatus.NOT_FOUND;

@RestController
@RequestMapping("/api/resumes")
public class ResumeController {

    private static final Logger log = LoggerFactory.getLogger(ResumeController.class);

    private final ResumeService service;

    public ResumeController(ResumeService service) {
        this.service = service;
    }

    @PostMapping
    public ResumeIngestResponse ingest(@RequestBody @Valid ResumeIngestRequest req) {
        long documentId = service.ingest(req.candidateId(), req.text());
        return new ResumeIngestResponse(documentId);
    }

    @PostMapping("/file")
    public ResumeIngestResponse ingestFile(
            @RequestParam("candidateId") String candidateId,
            @RequestParam("file") MultipartFile file) {

        if (file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File must not be empty");
        }
        String filename = file.getOriginalFilename();
        if (filename == null || filename.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Filename is missing");
        }

        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            log.error("ingestFile read error: candidateId={} filename={}", candidateId, filename, e);
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to read uploaded file");
        }

        try {
            long documentId = service.ingestFile(candidateId, bytes, filename);
            return new ResumeIngestResponse(documentId);
        } catch (RuntimeException e) {
            log.error("ingestFile extract error: candidateId={} filename={}", candidateId, filename, e);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Extract service failed: " + e.getMessage());
        }
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
