package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.repo.BaselineRepo;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Service
public class BaselineService {
    private final BaselineRepo repo;

    public BaselineService(BaselineRepo repo) {
        this.repo = repo;
    }

    /**
     * Aggregate tags from the last lastN rb_run entries, terms with cnt>=minCount become baseline terms.
     * Limit is fixed at 300 for now (sufficient and keeps prompt length reasonable)
     */
    public BuildResult buildBaseline(int lastN, int minCount) {
        String name = "baseline_" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        long baselineSetId = repo.createBaselineSet(name);

        int created = 0;
        var terms = repo.aggregateTopTerms(lastN, minCount, 300);
        for (var t : terms) {
            String canonical = (t.label() == null || t.label().isBlank()) ? t.normalized() : t.label();
            String sourceNote = "from lastN=" + lastN + ", minCount=" + minCount + ", cnt=" + t.cnt();
            created += repo.insertBaselineTerm(baselineSetId, canonical, t.normalized(), sourceNote);
        }

        return new BuildResult(baselineSetId, created);
    }

    public record BuildResult(long baselineSetId, int createdTerms) {}
}
