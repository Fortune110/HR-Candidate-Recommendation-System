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
     * 从最近 lastN 次 rb_run 中聚合标签，cnt>=minCount 的作为 baseline 基本词。
     * limit 先固定 300（够用且不至于 prompt 太长）
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
