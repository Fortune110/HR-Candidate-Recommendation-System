package com.fortune.resumeblueprint.repo;

import com.fortune.resumeblueprint.api.dto.StageHistoryItem;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public class CandidateRepo {
    private final JdbcTemplate jdbc;

    public CandidateRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Get current stage of a candidate, or create candidate if not exists (defaults to 'new')
     */
    public String getOrCreateCandidate(String candidateId) {
        // Try to get existing stage first
        try {
            String existingStage = jdbc.queryForObject(
                "select stage from rb_candidate where candidate_id = ?",
                String.class,
                candidateId
            );
            if (existingStage != null) {
                return existingStage;
            }
        } catch (Exception e) {
            // Candidate doesn't exist yet, will create below
        }
        
        // If not exists, try insert (with ON CONFLICT to handle race conditions)
        String sql = """
            insert into rb_candidate(candidate_id, stage, stage_updated_at, created_at, updated_at)
            values (?, 'new', now(), now(), now())
            on conflict (candidate_id) do nothing
            """;
        jdbc.update(sql, candidateId);
        
        // Query again to get the stage (either newly created or existing from race condition)
        return jdbc.queryForObject(
            "select stage from rb_candidate where candidate_id = ?",
            String.class,
            candidateId
        );
    }

    /**
     * Update candidate stage
     */
    public int updateCandidateStage(String candidateId, String newStage) {
        String sql = """
            update rb_candidate
            set stage = ?,
                stage_updated_at = now(),
                updated_at = now()
            where candidate_id = ?
            """;
        return jdbc.update(sql, newStage, candidateId);
    }

    /**
     * Insert stage history record
     */
    public long insertStageHistory(
            String candidateId,
            String fromStage,
            String toStage,
            String changedBy,
            String note,
            String reasonCode,
            Long jobId) {
        String sql = """
            insert into rb_candidate_stage_history(
                candidate_id, from_stage, to_stage, changed_by, note, reason_code, job_id, changed_at
            )
            values (?, ?, ?, ?, ?, ?, ?, now())
            on conflict (candidate_id, to_stage, changed_at, coalesce(changed_by, '')) do nothing
            returning history_id
            """;
        try {
            return jdbc.queryForObject(sql, Long.class,
                    candidateId, fromStage, toStage, changedBy, note, reasonCode, jobId);
        } catch (Exception e) {
            // If conflict, return 0 to indicate no new record was created
            return 0L;
        }
    }

    /**
     * Get stage history for a candidate (ordered by changed_at descending)
     */
    public List<StageHistoryItem> getStageHistory(String candidateId) {
        String sql = """
            select history_id, candidate_id, from_stage, to_stage, changed_by, note, reason_code, job_id, changed_at
            from rb_candidate_stage_history
            where candidate_id = ?
            order by changed_at desc
            """;
        return jdbc.query(sql, (rs, rowNum) -> new StageHistoryItem(
                rs.getLong("history_id"),
                rs.getString("candidate_id"),
                rs.getString("from_stage"),
                rs.getString("to_stage"),
                rs.getString("changed_by"),
                rs.getString("note"),
                rs.getString("reason_code"),
                rs.getObject("job_id", Long.class),
                rs.getTimestamp("changed_at").toInstant()
        ), candidateId);
    }

    /**
     * Get candidate info
     */
    public Optional<CandidateInfo> getCandidate(String candidateId) {
        String sql = """
            select candidate_id, stage, stage_updated_at, created_at, updated_at
            from rb_candidate
            where candidate_id = ?
            """;
        try {
            CandidateInfo info = jdbc.queryForObject(sql, (rs, rowNum) -> new CandidateInfo(
                    rs.getString("candidate_id"),
                    rs.getString("stage"),
                    rs.getTimestamp("stage_updated_at") != null 
                        ? rs.getTimestamp("stage_updated_at").toInstant() : null,
                    rs.getTimestamp("created_at").toInstant(),
                    rs.getTimestamp("updated_at").toInstant()
            ), candidateId);
            return Optional.ofNullable(info);
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    public record CandidateInfo(
            String candidateId,
            String stage,
            Instant stageUpdatedAt,
            Instant createdAt,
            Instant updatedAt
    ) {}
}
