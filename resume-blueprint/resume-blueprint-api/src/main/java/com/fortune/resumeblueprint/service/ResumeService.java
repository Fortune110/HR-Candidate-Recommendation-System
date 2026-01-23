package com.fortune.resumeblueprint.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import com.fortune.resumeblueprint.api.dto.ResumeDocumentResponse;
import com.fortune.resumeblueprint.api.dto.ResumeSummaryResponse;
import com.fortune.resumeblueprint.infra.LlmClient;
import com.fortune.resumeblueprint.repo.BaselineRepo;
import com.fortune.resumeblueprint.repo.BlueprintRepo;
import com.fortune.resumeblueprint.repo.ReviewRepo;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
public class ResumeService {
    private final BlueprintRepo repo;
    private final BaselineRepo baselineRepo;
    private final ReviewRepo reviewRepo;
    private final LlmClient llm;
    private final ObjectMapper om = new ObjectMapper();

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

    public ResumeService(BlueprintRepo repo, BaselineRepo baselineRepo, ReviewRepo reviewRepo, LlmClient llm) {
        this.repo = repo;
        this.baselineRepo = baselineRepo;
        this.reviewRepo = reviewRepo;
        this.llm = llm;
    }

    public long ingest(String candidateId, String text) {
        String hash = "sha256:" + sha256(text);
        return repo.saveDocument("candidate_resume", candidateId, hash, text);
    }

    public AnalyzeResponse analyzeBootstrap(long documentId, String resumeText) {
        AnalyzeResponse out = llm.analyzeBootstrap(resumeText);

        long runId = repo.saveRun(
                documentId,
                "bootstrap_v1",
                model,
                toJson(Map.of("mode", "bootstrap"))
        );

        for (AnalyzeResponse.KeywordItem k : out.keywords()) {
            long canonicalId = repo.upsertCanonicalTag(k.normalized(), k.term());
            long extractedId = repo.insertExtractedTag(runId, canonicalId, k.score());
            if (k.evidence() != null && !k.evidence().isBlank()) {
                repo.insertEvidence(extractedId, k.evidence());
            }
        }

        return new AnalyzeResponse(runId, out.mode(), out.summary(), out.keywords(), out.selectedTerms(), out.newTerms());
    }

    public AnalyzeResponse analyzeBaseline(long documentId, String resumeText, long baselineSetId) {
        var baselineList = baselineRepo.listBaselineNormalized(baselineSetId, 300);
        String[] baseline = baselineList.toArray(new String[0]);

        AnalyzeResponse out = llm.analyzeWithBaseline(resumeText, baseline);

        long runId = repo.saveRun(
                documentId,
                "baseline_v1",
                model,
                toJson(Map.of("mode", "baseline", "baselineSetId", baselineSetId, "baselineSize", baseline.length))
        );

        // selectedTerms: Persist as tags
        for (String normalized : out.selectedTerms()) {
            long canonicalId = repo.upsertCanonicalTag(normalized, normalized);
            repo.insertExtractedTag(runId, canonicalId, 0.80);
        }

        // newTerms: Persist as tags + enter review pending (not directly into baseline)
        for (AnalyzeResponse.KeywordItem k : out.newTerms()) {
            long canonicalId = repo.upsertCanonicalTag(k.normalized(), k.term());
            long extractedId = repo.insertExtractedTag(runId, canonicalId, k.score());
            if (k.evidence() != null && !k.evidence().isBlank()) {
                repo.insertEvidence(extractedId, k.evidence());
            }
            reviewRepo.upsertPending(baselineSetId, runId, k.term(), k.normalized(), k.score(), k.evidence());
        }

        return new AnalyzeResponse(runId, out.mode(), out.summary(), out.keywords(), out.selectedTerms(), out.newTerms());
    }

    public Optional<ResumeDocumentResponse> findDocument(long documentId) {
        return repo.findDocument(documentId)
                .map(row -> new ResumeDocumentResponse(
                        row.documentId(),
                        row.entityId(),
                        row.entityType(),
                        row.contentHash(),
                        row.contentText(),
                        row.createdAt()
                ));
    }

    public List<ResumeSummaryResponse> listDocuments(int limit, int offset) {
        return repo.listDocuments(limit, offset).stream()
                .map(row -> new ResumeSummaryResponse(
                        row.documentId(),
                        row.entityId(),
                        row.entityType(),
                        row.contentHash(),
                        row.createdAt()
                ))
                .toList();
    }

    private String toJson(Object o) {
        try { return om.writeValueAsString(o); }
        catch (Exception e) { return "{}"; }
    }

    private String sha256(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] dig = md.digest(s.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(dig);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
