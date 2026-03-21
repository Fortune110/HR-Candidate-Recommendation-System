package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.MatchResponse;
import com.fortune.resumeblueprint.api.dto.RecommendResponse;
import com.fortune.resumeblueprint.repo.BlueprintRepo;
import com.fortune.resumeblueprint.repo.JdRepo;
import com.fortune.resumeblueprint.service.MatchService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@RestController
@RequestMapping("/api/recommend")
public class RecommendController {

    private final JdRepo jdRepo;
    private final BlueprintRepo blueprintRepo;
    private final MatchService matchService;

    public RecommendController(JdRepo jdRepo, BlueprintRepo blueprintRepo, MatchService matchService) {
        this.jdRepo = jdRepo;
        this.blueprintRepo = blueprintRepo;
        this.matchService = matchService;
    }

    /**
     * Rank all candidate documents against a given JD.
     *
     * GET /api/recommend?jdId=1&limit=10
     *
     * Returns candidates sorted by match score (descending).
     */
    @GetMapping
    public RecommendResponse recommend(
            @RequestParam long jdId,
            @RequestParam(defaultValue = "10") int limit
    ) {
        JdRepo.JdRow jd = jdRepo.findById(jdId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "JD not found: " + jdId));

        // Load all candidate documents (cap at 500 to avoid OOM)
        List<BlueprintRepo.DocumentSummaryRow> docs = blueprintRepo.listDocuments(500, 0);

        List<RecommendResponse.CandidateResult> results = new ArrayList<>();

        for (BlueprintRepo.DocumentSummaryRow doc : docs) {
            MatchService.MatchResult matchResult =
                    matchService.matchResume(doc.documentId(), "both", null, jd.level());

            // Take the best score across internal/external matches
            double bestScore = matchResult.matches().stream()
                    .mapToDouble(MatchService.ProfileMatch::score)
                    .max()
                    .orElse(0.0);

            // Gaps and strengths from the highest-scoring profile
            MatchService.ProfileMatch best = matchResult.matches().stream()
                    .max(Comparator.comparingDouble(MatchService.ProfileMatch::score))
                    .orElse(null);

            List<MatchResponse.GapItem> topGaps = best != null ? best.topGaps() : List.of();
            List<MatchResponse.StrengthItem> topStrengths = best != null ? best.topStrengths() : List.of();

            results.add(new RecommendResponse.CandidateResult(
                    doc.entityId(),
                    doc.documentId(),
                    bestScore,
                    topGaps,
                    topStrengths
            ));
        }

        // Sort descending by score, take top-N
        results.sort(Comparator.comparingDouble(RecommendResponse.CandidateResult::score).reversed());
        List<RecommendResponse.CandidateResult> topN = results.stream().limit(limit).toList();

        return new RecommendResponse(jdId, topN.size(), topN);
    }
}
