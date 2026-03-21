package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

@Repository
public class SuccessProfileRepo {
    private final JdbcTemplate jdbc;

    public SuccessProfileRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Create a success profile
     */
    public long createProfile(String source, String role, String level, String company, String rawText) {
        String sql = """
            insert into rb_success_profile(source, role, level, company, raw_text)
            values (?, ?, ?, ?, ?)
            returning profile_id
            """;
        return jdbc.queryForObject(sql, Long.class, source, role, level, company, rawText);
    }

    /**
     * Insert tag for a success profile
     */
    public void insertProfileTag(long profileId, String canonical, double weight, String evidence, String via) {
        String sql = """
            insert into rb_success_profile_tag(profile_id, canonical, weight, evidence, via)
            values (?, ?, ?, ?, ?)
            """;
        jdbc.update(sql, profileId, canonical, weight, evidence, via);
    }

    /**
     * Get aggregated tags for a cohort (by source, role, level)
     * Returns: canonical -> aggregated weight (sum of weights / count)
     */
    public List<TagWeight> getCohortTags(String source, String role, String level) {
        String sql = """
            select 
                spt.canonical,
                sum(spt.weight) as total_weight,
                count(*) as tag_count,
                avg(spt.weight) as avg_weight
            from rb_success_profile_tag spt
            join rb_success_profile sp on sp.profile_id = spt.profile_id
            where sp.source = ?
              and sp.role = ?
              and (cast(? as text) is null or sp.level = ?)
            group by spt.canonical
            order by total_weight desc
            """;
        return jdbc.query(sql, (rs, rowNum) -> new TagWeight(
                rs.getString("canonical"),
                rs.getDouble("total_weight"),
                rs.getInt("tag_count"),
                rs.getDouble("avg_weight")
        ), source, role, level, level);
    }

    /**
     * Get all profiles matching criteria
     */
    public List<Long> getProfileIds(String source, String role, String level) {
        String sql = """
            select profile_id
            from rb_success_profile
            where source = ?
              and role = ?
              and (cast(? as text) is null or level = ?)
            """;
        return jdbc.queryForList(sql, Long.class, source, role, level, level);
    }

    public record TagWeight(String canonical, double totalWeight, int tagCount, double avgWeight) {}
}
