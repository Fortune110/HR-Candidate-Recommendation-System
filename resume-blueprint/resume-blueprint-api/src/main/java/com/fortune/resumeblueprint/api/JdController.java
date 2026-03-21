package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.JdAnalyzeRequest;
import com.fortune.resumeblueprint.api.dto.JdAnalyzeResponse;
import com.fortune.resumeblueprint.service.JdService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
}
