package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ReviewRepo {
    private final JdbcTemplate jdbc;

    public ReviewRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public int upsertPending(long baselineSetId, long runId, String term, String normalized, double score, String evidence) {
        String sql = """
        insert into rb_term_review(baseline_set_id, run_id, term, normalized, score, evidence_text, status)
        values (?, ?, ?, ?, ?, ?, 'pending')
        on conflict (run_id, normalized)
        do update set term = excluded.term,
                      score = excluded.score,
                      evidence_text = excluded.evidence_text
        """;
        return jdbc.update(sql, baselineSetId, runId, term, normalized, score, evidence);
    }

    public int approveToBaseline(long reviewId) {
        // Only responsible for changing pending -> approved, actual write to baseline_term is handled by service
        return jdbc.update("update rb_term_review set status='approved' where review_id=? and status='pending'", reviewId);
    }

    public int reject(long reviewId) {
        return jdbc.update("update rb_term_review set status='rejected' where review_id=? and status='pending'", reviewId);
    }
}
