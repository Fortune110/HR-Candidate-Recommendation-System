package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public class MLTrainingRepo {
    private final JdbcTemplate jdbc;

    public MLTrainingRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Get training examples from ml_training_examples_v1 view
     * 
     * @param jobId Optional job ID filter
     * @return List of training examples as maps (column name -> value)
     */
    public List<Map<String, Object>> getTrainingExamples(Long jobId) {
        String sql = """
            select 
                job_id,
                candidate_id,
                history_id,
                label,
                final_stage,
                match_score,
                overlap_score,
                gap_penalty,
                bonus_score,
                skill_match_count,
                year_diff,
                risk_score,
                stage_changed_at,
                match_created_at,
                reason_code
            from ml_training_examples_v1
            where (? is null or job_id = ?)
            order by job_id, candidate_id, stage_changed_at desc
            """;
        return jdbc.queryForList(sql, jobId, jobId);
    }

    /**
     * Get column names from the view
     */
    public List<String> getColumnNames() {
        String sql = """
            select column_name
            from information_schema.columns
            where table_schema = 'rb'
              and table_name = 'ml_training_examples_v1'
            order by ordinal_position
            """;
        return jdbc.queryForList(sql, String.class);
    }
}
