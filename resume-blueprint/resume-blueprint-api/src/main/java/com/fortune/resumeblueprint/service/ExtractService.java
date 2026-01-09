package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.infra.SpacyExtractorClient;
import com.fortune.resumeblueprint.infra.SpacyExtractorClient.ExtractedEntity;
import com.fortune.resumeblueprint.infra.SpacyExtractorClient.ExtractionResult;
import com.fortune.resumeblueprint.repo.BlueprintRepo;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Service for Box 1: Extract stage using spaCy + SkillNER.
 * Integrates extracted entities into rb_run / rb_extracted_tag / rb_tag_evidence tables.
 */
@Service
public class ExtractService {
    
    private final SpacyExtractorClient extractorClient;
    private final BlueprintRepo repo;
    
    public ExtractService(SpacyExtractorClient extractorClient, BlueprintRepo repo) {
        this.extractorClient = extractorClient;
        this.repo = repo;
    }
    
    /**
     * Extract entities from text and persist to database.
     * 
     * @param documentId Document ID in rb_document table
     * @param text Resume or JD text
     * @param docType "RESUME" or "JD"
     * @return Run ID for the extraction
     */
    public long extractAndPersist(long documentId, String text, String docType) {
        // 1. Call Python extraction service
        ExtractionResult result = extractorClient.extract(text, docType);
        
        // 2. Create run record
        long runId = repo.saveRun(
                documentId,
                "spacy_skillner_v1",
                result.extractor(),
                String.format("{\"extractor_version\":\"%s\",\"summary\":\"%s\"}", 
                        result.extractorVersion(), result.summary())
        );
        
        // 3. Persist extracted entities as tags
        for (ExtractedEntity entity : result.entities()) {
            // Upsert canonical tag
            long canonicalId = repo.upsertCanonicalTag(entity.canonical(), entity.text());
            
            // Calculate score based on entity type
            double score = calculateScore(entity);
            
            // Insert extracted tag
            long extractedId = repo.insertExtractedTag(runId, canonicalId, score);
            
            // Insert evidence (always include evidence for traceability)
            if (entity.evidence() != null && !entity.evidence().isBlank()) {
                repo.insertEvidence(extractedId, entity.evidence());
            } else {
                // Fallback: use original text as evidence
                repo.insertEvidence(extractedId, entity.text());
            }
        }
        
        return runId;
    }
    
    /**
     * Calculate confidence score for extracted entity.
     * Skills from SkillNER get higher score, NER entities get medium score.
     */
    private double calculateScore(ExtractedEntity entity) {
        if ("skill".equals(entity.type())) {
            return 0.85; // High confidence for skills
        } else if ("ner".equals(entity.type())) {
            // Different NER labels have different confidence
            String label = entity.label();
            if ("PERSON".equals(label) || "ORG".equals(label)) {
                return 0.80;
            } else if ("DATE".equals(label) || "GPE".equals(label)) {
                return 0.75;
            } else {
                return 0.70;
            }
        } else {
            return 0.60; // Default for unknown types
        }
    }
    
    /**
     * Check if extraction service is available
     */
    public boolean isExtractorAvailable() {
        return extractorClient.isHealthy();
    }
}
