package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.infra.SpacyExtractorClient;
import com.fortune.resumeblueprint.infra.SpacyExtractorClient.ExtractedEntity;
import com.fortune.resumeblueprint.infra.SpacyExtractorClient.ExtractionResult;
import com.fortune.resumeblueprint.repo.SuccessProfileRepo;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * Service for importing success profiles (internal/external).
 * Extracts tags from profile text and stores in database.
 */
@Service
public class SuccessProfileService {
    private final SuccessProfileRepo repo;
    private final SpacyExtractorClient extractorClient;

    public SuccessProfileService(SuccessProfileRepo repo, SpacyExtractorClient extractorClient) {
        this.repo = repo;
        this.extractorClient = extractorClient;
    }

    /**
     * Import a success profile from text.
     * 
     * @param source "internal_employee" | "external_success"
     * @param role Role name (e.g., "Java Backend Engineer")
     * @param level "junior" | "mid" | "senior" | null
     * @param company Company name (optional)
     * @param text Profile text (resume/project description)
     * @return Profile ID
     */
    public long importProfile(String source, String role, String level, String company, String text) {
        // 1. Create profile
        long profileId = repo.createProfile(source, role, level, company, text);

        // 2. Extract tags using spaCy + SkillNER
        ExtractionResult extraction = extractorClient.extract(text, "RESUME");

        // 3. Store tags with weights
        for (ExtractedEntity entity : extraction.entities()) {
            // Calculate weight: skills get higher weight, NER gets medium
            double weight = calculateWeight(entity);
            
            repo.insertProfileTag(
                    profileId,
                    entity.canonical(),
                    weight,
                    entity.evidence(),
                    entity.type()  // "skill" | "ner"
            );
        }

        return profileId;
    }

    /**
     * Calculate weight for a tag based on entity type
     */
    private double calculateWeight(ExtractedEntity entity) {
        if ("skill".equals(entity.type())) {
            return 1.0;  // Skills are most important
        } else if ("ner".equals(entity.type())) {
            String label = entity.label();
            if ("ORG".equals(label) || "PERSON".equals(label)) {
                return 0.8;
            } else {
                return 0.6;
            }
        } else {
            return 0.5;
        }
    }

    /**
     * Batch import from CSV-like data
     * Format: source, role, level, company, text
     */
    public void batchImport(String[][] data) {
        for (String[] row : data) {
            if (row.length >= 5) {
                importProfile(row[0], row[1], row[2], row[3], row[4]);
            }
        }
    }
}
