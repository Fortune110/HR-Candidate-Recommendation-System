package com.fortune.resumeblueprint.repo;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Repository;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.util.List;

@Repository
public class JdRepo {

    private final JdbcTemplate jdbc;
    private final ObjectMapper om = new ObjectMapper();

    public JdRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Insert a new JD analysis row. Returns the generated jd_id.
     * If content_hash already exists, returns the existing jd_id (idempotent).
     */
    public long saveJd(
            String contentHash,
            String rawText,
            List<String> requiredSkills,
            List<String> preferredSkills,
            Integer minYearsExp,
            String level,
            String summary,
            String modelName
    ) {
        // Check for existing record with same hash
        List<Long> existing = jdbc.query(
                "SELECT jd_id FROM rb_job_description WHERE content_hash = ?",
                (rs, i) -> rs.getLong("jd_id"),
                contentHash
        );
        if (!existing.isEmpty()) {
            return existing.get(0);
        }

        String requiredJson = toJson(requiredSkills);
        String preferredJson = toJson(preferredSkills);

        GeneratedKeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(con -> {
            PreparedStatement ps = con.prepareStatement(
                    """
                    INSERT INTO rb_job_description
                      (content_hash, raw_text, required_skills, preferred_skills,
                       min_years_exp, level, summary, model_name)
                    VALUES (?, ?, ?::jsonb, ?::jsonb, ?, ?, ?, ?)
                    """,
                    new String[]{"jd_id"}
            );
            ps.setString(1, contentHash);
            ps.setString(2, rawText);
            ps.setString(3, requiredJson);
            ps.setString(4, preferredJson);
            if (minYearsExp != null) {
                ps.setInt(5, minYearsExp);
            } else {
                ps.setNull(5, java.sql.Types.INTEGER);
            }
            ps.setString(6, level);
            ps.setString(7, summary);
            ps.setString(8, modelName);
            return ps;
        }, keyHolder);

        return keyHolder.getKey().longValue();
    }

    /**
     * Find a JD row by its primary key. Returns empty if not found.
     */
    public java.util.Optional<JdRow> findById(long jdId) {
        List<JdRow> rows = jdbc.query(
                "SELECT jd_id, level, required_skills, summary FROM rb_job_description WHERE jd_id = ?",
                (rs, i) -> new JdRow(
                        rs.getLong("jd_id"),
                        rs.getString("level"),
                        rs.getString("required_skills"),
                        rs.getString("summary")
                ),
                jdId
        );
        return rows.stream().findFirst();
    }

    public record JdRow(long jdId, String level, String requiredSkillsJson, String summary) {}

    private String toJson(Object o) {
        try {
            return om.writeValueAsString(o);
        } catch (JsonProcessingException e) {
            return "[]";
        }
    }
}
