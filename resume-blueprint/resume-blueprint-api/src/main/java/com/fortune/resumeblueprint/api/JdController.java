package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.JdAnalyzeRequest;
import com.fortune.resumeblueprint.api.dto.JdAnalyzeResponse;
import com.fortune.resumeblueprint.service.JdService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/jd")
public class JdController {

    private final JdService jdService;

    public JdController(JdService jdService) {
        this.jdService = jdService;
    }

    /**
     * Analyze a job description text using OpenAI.
     *
     * POST /api/jd/analyze
     * Body: { "text": "We are looking for a senior Java engineer..." }
     *
     * Response: structured JD analysis including required skills,
     * preferred skills, experience requirement, and seniority level.
     */
    @PostMapping("/analyze")
    public JdAnalyzeResponse analyze(@RequestBody @Valid JdAnalyzeRequest req) {
        return jdService.analyze(req.text());
    }

    /**
     * Upload a JD file (.pdf or .docx), extract its text via the Python service,
     * and return the raw text for the frontend to fill into the textarea.
     *
     * POST /api/jd/upload-file
     * Request: multipart/form-data with field "file"
     * Response: { "text": "..." }
     */
    @PostMapping("/upload-file")
    public Map<String, String> uploadFile(@RequestParam("file") MultipartFile file) {
        String text = jdService.extractTextFromFile(file);
        return Map.of("text", text);
    }
}
