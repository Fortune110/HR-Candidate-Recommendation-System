package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.MatchRequest;
import com.fortune.resumeblueprint.api.dto.MatchResponse;
import com.fortune.resumeblueprint.service.MatchService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

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
        
        // Convert MatchService.ProfileMatch to MatchResponse.ProfileMatch
        List<MatchResponse.ProfileMatch> responseMatches = result.matches().stream()
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
        
        return new MatchResponse(result.matchRunId(), responseMatches);
    }

    @GetMapping("/{matchRunId}")
    public MatchResponse getMatchRun(@PathVariable long matchRunId) {
        return matchService.getMatchRun(matchRunId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Match run not found"));
    }
}
