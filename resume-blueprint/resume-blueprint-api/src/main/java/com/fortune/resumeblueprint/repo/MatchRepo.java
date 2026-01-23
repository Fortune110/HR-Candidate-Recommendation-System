package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class MatchRepo {
    private final JdbcTemplate jdbc;

    public MatchRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Create a match run
     */
    public long createMatchRun(long resumeDocumentId, String target, String roleFilter, String levelFilter, 
                              String algoVersion, String configJson) {
        String sql = """
            insert into rb_match_run(resume_document_id, target, role_filter, level_filter, algo_version, config)
            values (?, ?, ?, ?, ?, cast(? as jsonb))
            returning match_run_id
            """;
        return jdbc.queryForObject(sql, Long.class, resumeDocumentId, target, roleFilter, levelFilter, 
                algoVersion, configJson);
    }

    /**
     * Insert match result
     */
    public void insertMatchResult(long matchRunId, long profileId, double score, 
                                 double overlapScore, double gapPenalty, double bonusScore,
                                 String overlapTopkJson, String gapsTopkJson, String strengthsTopkJson,
                                 String explainJson) {
        String sql = """
            insert into rb_match_result(match_run_id, profile_id, score, overlap_score, gap_penalty, bonus_score,
                                       overlap_topk, gaps_topk, strengths_topk, explain_json)
            values (?, ?, ?, ?, ?, ?, cast(? as jsonb), cast(? as jsonb), cast(? as jsonb), cast(? as jsonb))
            """;
        jdbc.update(sql, matchRunId, profileId, score, overlapScore, gapPenalty, bonusScore,
                overlapTopkJson, gapsTopkJson, strengthsTopkJson, explainJson);
    }

    /**
     * Get resume tags aggregated (from projects or document-level)
     */
    public List<TagWeight> getResumeTags(long resumeDocumentId) {
        // Get tags from projects
        String sql = """
            select 
                rpt.canonical,
                sum(rpt.weight) as total_weight,
                count(*) as tag_count,
                avg(rpt.weight) as avg_weight
            from rb_resume_project_tag rpt
            join rb_resume_project rp on rp.project_id = rpt.project_id
            where rp.resume_document_id = ?
            group by rpt.canonical
            union
            -- Also include document-level tags from rb_extracted_tag
            select 
                ct.canonical_id as canonical,
                sum(et.score) as total_weight,
                count(*) as tag_count,
                avg(et.score) as avg_weight
            from rb_extracted_tag et
            join rb_canonical_tag ct on ct.canonical_tag_id = et.canonical_tag_id
            join rb_run r on r.run_id = et.run_id
            where r.document_id = ?
            group by ct.canonical_id
            """;
        return jdbc.query(sql, (rs, rowNum) -> new TagWeight(
                rs.getString("canonical"),
                rs.getDouble("total_weight"),
                rs.getInt("tag_count"),
                rs.getDouble("avg_weight")
        ), resumeDocumentId, resumeDocumentId);
    }

    public Optional<MatchRun> getMatchRun(long matchRunId) {
        String sql = """
            select match_run_id, resume_document_id, target, role_filter, level_filter, algo_version, config, created_at
            from rb_match_run
            where match_run_id = ?
            """;
        List<MatchRun> results = jdbc.query(sql, (rs, rowNum) -> new MatchRun(
                rs.getLong("match_run_id"),
                rs.getLong("resume_document_id"),
                rs.getString("target"),
                rs.getString("role_filter"),
                rs.getString("level_filter"),
                rs.getString("algo_version"),
                rs.getString("config"),
                rs.getObject("created_at", java.time.OffsetDateTime.class)
        ), matchRunId);
        return results.stream().findFirst();
    }

    public List<MatchResult> getMatchResults(long matchRunId) {
        String sql = """
            select r.match_run_id, r.profile_id, p.source, r.score, r.overlap_score, r.gap_penalty, r.bonus_score,
                   r.overlap_topk, r.gaps_topk, r.strengths_topk
            from rb_match_result r
            join rb_success_profile p on p.profile_id = r.profile_id
            where r.match_run_id = ?
            order by r.score desc
            """;
        return jdbc.query(sql, (rs, rowNum) -> new MatchResult(
                rs.getLong("match_run_id"),
                rs.getLong("profile_id"),
                rs.getString("source"),
                rs.getDouble("score"),
                rs.getDouble("overlap_score"),
                rs.getDouble("gap_penalty"),
                rs.getDouble("bonus_score"),
                rs.getString("overlap_topk"),
                rs.getString("gaps_topk"),
                rs.getString("strengths_topk")
        ), matchRunId);
    }

    public record TagWeight(String canonical, double totalWeight, int tagCount, double avgWeight) {}

    public record MatchRun(
            long matchRunId,
            long resumeDocumentId,
            String target,
            String roleFilter,
            String levelFilter,
            String algoVersion,
            String configJson,
            java.time.OffsetDateTime createdAt
    ) {}

    public record MatchResult(
            long matchRunId,
            long profileId,
            String source,
            double score,
            double overlapScore,
            double gapPenalty,
            double bonusScore,
            String overlapTopkJson,
            String gapsTopkJson,
            String strengthsTopkJson
    ) {}
}
