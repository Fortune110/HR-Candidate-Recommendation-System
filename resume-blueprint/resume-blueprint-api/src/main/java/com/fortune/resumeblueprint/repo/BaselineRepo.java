package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class BaselineRepo {
    private final JdbcTemplate jdbc;

    public BaselineRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long createBaselineSet(String name) {
        String sql = """
        insert into rb_baseline_set(name, is_active)
        values (?, true)
        returning baseline_set_id
        """;
        return jdbc.queryForObject(sql, Long.class, name);
    }

    public int insertBaselineTerm(long baselineSetId, String canonical, String normalized, String sourceNote) {
        String sql = """
        insert into rb_baseline_term(baseline_set_id, tag_type, canonical, normalized, source_note, status)
        values (?, 'keyword', ?, ?, ?, 'active')
        on conflict (baseline_set_id, normalized)
        do nothing
        """;
        return jdbc.update(sql, baselineSetId, canonical, normalized, sourceNote);
    }

    public List<String> listBaselineNormalized(long baselineSetId, int limit) {
        String sql = """
        select normalized
        from rb_baseline_term
        where baseline_set_id = ? and status = 'active'
        order by created_at asc
        limit ?
        """;
        return jdbc.queryForList(sql, String.class, baselineSetId, limit);
    }

    /** Aggregate tags from the last lastN runs, returns normalized/cnt/label */
    public List<AggregatedTerm> aggregateTopTerms(int lastN, int minCount, int limit) {
        String sql = """
        with recent as (
          select run_id
          from rb_run
          order by run_id desc
          limit ?
        ),
        agg as (
          select ct.canonical_id as normalized,
                 max(ct.label) as label,
                 count(*) as cnt
          from rb_extracted_tag et
          join recent r on r.run_id = et.run_id
          join rb_canonical_tag ct on ct.canonical_tag_id = et.canonical_tag_id
          group by ct.canonical_id
        )
        select normalized, label, cnt
        from agg
        where cnt >= ?
        order by cnt desc, normalized asc
        limit ?
        """;
        return jdbc.query(sql, (rs, rowNum) ->
                new AggregatedTerm(
                        rs.getString("normalized"),
                        rs.getString("label"),
                        rs.getInt("cnt")
                ), lastN, minCount, limit);
    }

    public record AggregatedTerm(String normalized, String label, int cnt) {}
}
