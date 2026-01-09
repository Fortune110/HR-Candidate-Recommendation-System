package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

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

    public record TagWeight(String canonical, double totalWeight, int tagCount, double avgWeight) {}
}
