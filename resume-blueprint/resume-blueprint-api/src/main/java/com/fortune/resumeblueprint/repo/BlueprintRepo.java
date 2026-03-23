package com.fortune.resumeblueprint.repo;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public class BlueprintRepo {
    private final JdbcTemplate jdbc;

    public BlueprintRepo(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long saveDocument(String entityType, String entityId, String contentHash, String contentText) {
        String sql = """
        with up as (
          insert into rb_document(entity_type, entity_id, content_hash, content_text)
          values (?, ?, ?, ?)
          on conflict (entity_type, entity_id, content_hash)
          do update set content_text = excluded.content_text
          returning document_id
        )
        select document_id from up
        """;
        return jdbc.queryForObject(sql, Long.class, entityType, entityId, contentHash, contentText);
    }

    public long saveRun(long documentId, String promptVersion, String modelName, String configJson) {
        String sql = """
        insert into rb_run(document_id, analyzer, analyzer_version, model_name, prompt_version, config, status)
        values (?, 'openai_responses', 'v1', ?, ?, cast(? as jsonb), 'success')
        returning run_id
        """;
        return jdbc.queryForObject(sql, Long.class, documentId, modelName, promptVersion, configJson);
    }

    public long upsertCanonicalTag(String canonicalId, String label) {
        String sql = """
        insert into rb_canonical_tag(framework, canonical_id, label, tag_type)
        values ('INTERNAL', ?, ?, 'keyword')
        on conflict (framework, canonical_id)
        do update set label = excluded.label, updated_at = now()
        returning canonical_tag_id
        """;
        return jdbc.queryForObject(sql, Long.class, canonicalId, label);
    }

    public long insertExtractedTag(long runId, long canonicalTagId, double score) {
        String sql = """
        insert into rb_extracted_tag(run_id, canonical_tag_id, score, weight)
        values (?, ?, ?, 1.0)
        returning extracted_tag_id
        """;
        return jdbc.queryForObject(sql, Long.class, runId, canonicalTagId, score);
    }

    public void insertEvidence(long extractedTagId, String evidenceText) {
        jdbc.update("insert into rb_tag_evidence(extracted_tag_id, evidence_text) values (?, ?)",
                extractedTagId, evidenceText);
    }

    public Optional<DocumentRow> findDocument(long documentId) {
        String sql = """
        select document_id, entity_type, entity_id, content_hash, content_text, created_at
        from rb_document
        where document_id = ?
        """;
        List<DocumentRow> rows = jdbc.query(sql, (rs, rowNum) -> new DocumentRow(
                rs.getLong("document_id"),
                rs.getString("entity_type"),
                rs.getString("entity_id"),
                rs.getString("content_hash"),
                rs.getString("content_text"),
                rs.getObject("created_at", OffsetDateTime.class)
        ), documentId);
        return rows.stream().findFirst();
    }

    public String findEntityId(long documentId) {
        List<String> rows = jdbc.query(
                "select entity_id from rb_document where document_id = ?",
                (rs, rn) -> rs.getString("entity_id"),
                documentId
        );
        return rows.isEmpty() ? null : rows.get(0);
    }

    public void upsertCandidateSeniority(String candidateId, Integer experienceYears, String seniorityLevel) {
        String sql = """
        insert into rb_candidate(candidate_id, stage, experience_years, seniority_level)
        values (?, 'new', ?, ?)
        on conflict (candidate_id)
        do update set experience_years = excluded.experience_years,
                      seniority_level  = excluded.seniority_level,
                      updated_at       = now()
        """;
        jdbc.update(sql, candidateId, experienceYears, seniorityLevel);
    }

    public List<CandidateListRow> listCandidates(int limit, int offset) {
        String sql = """
        select d.document_id,
               d.entity_id    as candidate_id,
               d.entity_type,
               d.created_at,
               c.experience_years,
               c.seniority_level
        from rb_document d
        left join rb_candidate c on c.candidate_id = d.entity_id
        where d.entity_type = 'candidate_resume'
        order by d.document_id desc
        limit ? offset ?
        """;
        return jdbc.query(sql, (rs, rn) -> new CandidateListRow(
                rs.getLong("document_id"),
                rs.getString("candidate_id"),
                rs.getString("entity_type"),
                rs.getObject("created_at", OffsetDateTime.class),
                rs.getObject("experience_years") != null ? rs.getInt("experience_years") : null,
                rs.getString("seniority_level")
        ), limit, offset);
    }

    public List<DocumentSummaryRow> listDocuments(int limit, int offset) {
        String sql = """
        select document_id, entity_type, entity_id, content_hash, created_at
        from rb_document
        order by document_id desc
        limit ? offset ?
        """;
        return jdbc.query(sql, (rs, rowNum) -> new DocumentSummaryRow(
                rs.getLong("document_id"),
                rs.getString("entity_type"),
                rs.getString("entity_id"),
                rs.getString("content_hash"),
                rs.getObject("created_at", OffsetDateTime.class)
        ), limit, offset);
    }

    public record CandidateListRow(
            long documentId,
            String candidateId,
            String entityType,
            OffsetDateTime createdAt,
            Integer experienceYears,
            String seniorityLevel
    ) {}

    public record DocumentRow(
            long documentId,
            String entityType,
            String entityId,
            String contentHash,
            String contentText,
            OffsetDateTime createdAt
    ) {}

    public record DocumentSummaryRow(
            long documentId,
            String entityType,
            String entityId,
            String contentHash,
            OffsetDateTime createdAt
    ) {}
}
