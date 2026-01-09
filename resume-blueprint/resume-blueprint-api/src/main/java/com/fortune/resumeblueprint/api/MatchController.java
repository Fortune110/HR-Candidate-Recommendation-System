package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.MatchRequest;
import com.fortune.resumeblueprint.api.dto.MatchResponse;
import com.fortune.resumeblueprint.service.MatchService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/match")
public class MatchController {
    
    private final MatchService matchService;
    
    public MatchController(MatchService matchService) {
        this.matchService = matchService;
    }
    
    /**
     * Match resume against success cohorts
     * 
     * POST /api/match
     * Body: {
     *   "resumeDocumentId": 1,
     *   "target": "both",  // "internal" | "external" | "both"
     *   "roleFilter": "Java Backend Engineer",  // optional
     *   "levelFilter": "mid"  // optional
     * }
     */
    @PostMapping
    public MatchResponse match(@RequestBody @Valid MatchRequest req) {
        var result = matchService.matchResume(
                req.resumeDocumentId(),
                req.target() != null ? req.target() : "both",
                req.roleFilter(),
                req.levelFilter()
        );
        
        return new MatchResponse(result.matchRunId(), result.matches());
    }
}
