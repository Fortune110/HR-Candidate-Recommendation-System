package com.fortune.resumeblueprint.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fortune.resumeblueprint.api.dto.MatchResponse;
import com.fortune.resumeblueprint.repo.MatchRepo;
import com.fortune.resumeblueprint.repo.SuccessProfileRepo;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Service for Box 3/4: Compare resume tags with success cohort tags.
 * Implements weighted Jaccard similarity + gap analysis.
 */
@Service
public class MatchService {
    private final MatchRepo matchRepo;
    private final SuccessProfileRepo successProfileRepo;
    private final ObjectMapper om = new ObjectMapper();

    public MatchService(MatchRepo matchRepo, SuccessProfileRepo successProfileRepo) {
        this.matchRepo = matchRepo;
        this.successProfileRepo = successProfileRepo;
    }

    /**
     * Match resume against success cohorts (internal/external)
     * 
     * @param resumeDocumentId Resume document ID
     * @param target "internal" | "external" | "both"
     * @param roleFilter Optional role filter (e.g., "Java Backend Engineer")
     * @param levelFilter Optional level filter (e.g., "mid")
     * @return Match results with scores and gaps
     */
    public MatchResult matchResume(long resumeDocumentId, String target, String roleFilter, String levelFilter) {
        // Get resume tags
        List<MatchRepo.TagWeight> resumeTags = matchRepo.getResumeTags(resumeDocumentId);
        Map<String, Double> resumeTagMap = resumeTags.stream()
                .collect(Collectors.toMap(
                        MatchRepo.TagWeight::canonical,
                        t -> t.avgWeight(),
                        (v1, v2) -> v1 + v2  // Sum weights if duplicate
                ));

        // Create match run
        String algoVersion = "v1";
        String configJson = toJson(Map.of(
                "target", target,
                "roleFilter", roleFilter != null ? roleFilter : "",
                "levelFilter", levelFilter != null ? levelFilter : ""
        ));
        long matchRunId = matchRepo.createMatchRun(resumeDocumentId, target, roleFilter, levelFilter, 
                algoVersion, configJson);

        List<ProfileMatch> profileMatches = new ArrayList<>();

        // Match against internal cohort
        if ("internal".equals(target) || "both".equals(target)) {
            List<SuccessProfileRepo.TagWeight> internalTags = successProfileRepo.getCohortTags(
                    "internal_employee", roleFilter != null ? roleFilter : "Java Backend Engineer", levelFilter);
            ProfileMatch internalMatch = calculateMatch("internal_employee", resumeTagMap, internalTags, matchRunId);
            profileMatches.add(internalMatch);
        }

        // Match against external cohort
        if ("external".equals(target) || "both".equals(target)) {
            List<SuccessProfileRepo.TagWeight> externalTags = successProfileRepo.getCohortTags(
                    "external_success", roleFilter != null ? roleFilter : "Java Backend Engineer", levelFilter);
            ProfileMatch externalMatch = calculateMatch("external_success", resumeTagMap, externalTags, matchRunId);
            profileMatches.add(externalMatch);
        }

        return new MatchResult(matchRunId, profileMatches);
    }

    public Optional<MatchResponse> getMatchRun(long matchRunId) {
        Optional<MatchRepo.MatchRun> run = matchRepo.getMatchRun(matchRunId);
        if (run.isEmpty()) {
            return Optional.empty();
        }

        List<MatchResponse.ProfileMatch> responseMatches = matchRepo.getMatchResults(matchRunId).stream()
                .map(result -> new MatchResponse.ProfileMatch(
                        result.source(),
                        result.score(),
                        result.overlapScore(),
                        result.gapPenalty(),
                        result.bonusScore(),
                        readList(result.overlapTopkJson(), new TypeReference<List<MatchResponse.OverlapItem>>() {}),
                        readList(result.gapsTopkJson(), new TypeReference<List<MatchResponse.GapItem>>() {}),
                        readList(result.strengthsTopkJson(), new TypeReference<List<MatchResponse.StrengthItem>>() {})
                ))
                .toList();

        return Optional.of(new MatchResponse(matchRunId, responseMatches));
    }

    /**
     * Calculate match score between resume tags and cohort tags
     */
    private ProfileMatch calculateMatch(String source, Map<String, Double> resumeTags, 
                                       List<SuccessProfileRepo.TagWeight> cohortTags, long matchRunId) {
        // Convert cohort tags to map (normalized by count)
        Map<String, Double> cohortTagMap = cohortTags.stream()
                .collect(Collectors.toMap(
                        SuccessProfileRepo.TagWeight::canonical,
                        t -> t.avgWeight(),  // Use average weight
                        (v1, v2) -> Math.max(v1, v2)
                ));

        // Calculate overlap (weighted Jaccard)
        Set<String> allTags = new HashSet<>(resumeTags.keySet());
        allTags.addAll(cohortTagMap.keySet());

        double intersectionSum = 0.0;
        double unionSum = 0.0;

        for (String tag : allTags) {
            double resumeWeight = resumeTags.getOrDefault(tag, 0.0);
            double cohortWeight = cohortTagMap.getOrDefault(tag, 0.0);
            
            intersectionSum += Math.min(resumeWeight, cohortWeight);
            unionSum += Math.max(resumeWeight, cohortWeight);
        }

        double overlapScore = unionSum > 0 ? intersectionSum / unionSum : 0.0;

        // Calculate gaps (high-weight cohort tags missing in resume)
        List<MatchResponse.GapItem> gaps = new ArrayList<>();
        for (SuccessProfileRepo.TagWeight tag : cohortTags) {
            if (!resumeTags.containsKey(tag.canonical()) && tag.avgWeight() > 0.5) {
                gaps.add(new MatchResponse.GapItem(tag.canonical(), tag.avgWeight(), "Missing high-weight tag"));
            }
        }
        gaps.sort((a, b) -> Double.compare(b.weight(), a.weight()));
        List<MatchResponse.GapItem> topGaps = gaps.stream().limit(10).collect(Collectors.toList());

        double gapPenalty = topGaps.stream()
                .mapToDouble(g -> g.weight() * 0.1)  // 10% penalty per gap
                .sum();
        gapPenalty = Math.min(gapPenalty, 0.3);  // Cap at 30%

        // Calculate strengths (resume tags not in cohort or with higher weight)
        List<MatchResponse.StrengthItem> strengths = new ArrayList<>();
        for (Map.Entry<String, Double> entry : resumeTags.entrySet()) {
            String tag = entry.getKey();
            double resumeWeight = entry.getValue();
            double cohortWeight = cohortTagMap.getOrDefault(tag, 0.0);
            
            if (resumeWeight > cohortWeight * 1.2) {  // 20% higher
                strengths.add(new MatchResponse.StrengthItem(tag, resumeWeight, "Stronger than cohort average"));
            }
        }
        strengths.sort((a, b) -> Double.compare(b.weight(), a.weight()));
        List<MatchResponse.StrengthItem> topStrengths = strengths.stream().limit(5).collect(Collectors.toList());

        double bonusScore = topStrengths.stream()
                .mapToDouble(s -> Math.min(s.weight() * 0.05, 0.1))  // 5% bonus per strength, cap at 10%
                .sum();
        bonusScore = Math.min(bonusScore, 0.15);  // Cap at 15%

        // Final score
        double finalScore = Math.max(0.0, Math.min(1.0, overlapScore - gapPenalty + bonusScore));

        // Get top overlaps
        List<MatchResponse.OverlapItem> overlaps = new ArrayList<>();
        for (String tag : resumeTags.keySet()) {
            if (cohortTagMap.containsKey(tag)) {
                overlaps.add(new MatchResponse.OverlapItem(tag, 
                        Math.min(resumeTags.get(tag), cohortTagMap.get(tag)),
                        "Matched tag"));
            }
        }
        overlaps.sort((a, b) -> Double.compare(b.weight(), a.weight()));
        List<MatchResponse.OverlapItem> topOverlaps = overlaps.stream().limit(10).collect(Collectors.toList());

        // Get profile IDs for this cohort (for storing results)
        List<Long> profileIds = successProfileRepo.getProfileIds(source, "Java Backend Engineer", null);
        
        // Store results (for first profile as representative)
        if (!profileIds.isEmpty()) {
            String explainJson = toJson(Map.of(
                    "overlapScore", overlapScore,
                    "gapPenalty", gapPenalty,
                    "bonusScore", bonusScore,
                    "finalScore", finalScore
            ));
            matchRepo.insertMatchResult(matchRunId, profileIds.get(0), finalScore, 
                    overlapScore, gapPenalty, bonusScore,
                    toJson(topOverlaps), toJson(topGaps), toJson(topStrengths),
                    explainJson);
        }

        return new ProfileMatch(source, finalScore, overlapScore, gapPenalty, bonusScore,
                topOverlaps, topGaps, topStrengths);
    }

    private String toJson(Object o) {
        try {
            return om.writeValueAsString(o);
        } catch (Exception e) {
            return "{}";
        }
    }

    private <T> List<T> readList(String json, TypeReference<List<T>> typeRef) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            return om.readValue(json, typeRef);
        } catch (Exception e) {
            return List.of();
        }
    }

    // DTOs
    public record MatchResult(long matchRunId, List<ProfileMatch> matches) {}

    public record ProfileMatch(
            String source,  // "internal_employee" | "external_success"
            double score,
            double overlapScore,
            double gapPenalty,
            double bonusScore,
            List<MatchResponse.OverlapItem> topOverlaps,
            List<MatchResponse.GapItem> topGaps,
            List<MatchResponse.StrengthItem> topStrengths
    ) {}
}
