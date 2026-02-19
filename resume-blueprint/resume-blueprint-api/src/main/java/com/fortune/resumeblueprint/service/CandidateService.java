package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.api.dto.CandidateResponse;
import com.fortune.resumeblueprint.api.dto.CandidateStage;
import com.fortune.resumeblueprint.api.dto.ChangeStageRequest;
import com.fortune.resumeblueprint.api.dto.StageHistoryItem;
import com.fortune.resumeblueprint.repo.CandidateRepo;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Service for managing candidate pipeline stages and history
 */
@Service
public class CandidateService {
    private final CandidateRepo repo;

    public CandidateService(CandidateRepo repo) {
        this.repo = repo;
    }

    /**
     * Update candidate stage with validation and history tracking
     * 
     * @param candidateId Candidate ID
     * @param request Stage change request
     * @return Updated candidate response
     * @throws IllegalArgumentException if stage transition is invalid
     */
    @Transactional
    public CandidateResponse updateStage(String candidateId, ChangeStageRequest request) {
        // 1. Get or create candidate (defaults to 'new' stage)
        String currentStage = repo.getOrCreateCandidate(candidateId);
        
        // 2. Parse target stage
        CandidateStage targetStage;
        try {
            targetStage = CandidateStage.fromString(request.toStage());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid stage: " + request.toStage(), e);
        }
        
        // 3. Validate transition (unless force is true)
        if (!request.force()) {
            CandidateStage fromStageEnum = currentStage != null 
                ? CandidateStage.fromString(currentStage) 
                : null;
            
            if (!targetStage.isValidTransition(fromStageEnum)) {
                throw new IllegalArgumentException(
                    String.format("Invalid stage transition from '%s' to '%s'", 
                        currentStage, request.toStage())
                );
            }
        }
        
        // 4. Check if already in target stage (idempotency)
        if (currentStage != null && currentStage.equalsIgnoreCase(request.toStage())) {
            // Still create history entry to track the action
            repo.insertStageHistory(
                    candidateId,
                    currentStage,
                    request.toStage(),
                    request.changedBy(),
                    request.note(),
                    request.reasonCode(),
                    request.jobId()
            );
            
            // Return existing candidate info
            return repo.getCandidate(candidateId)
                    .map(c -> new CandidateResponse(
                            c.candidateId(),
                            c.stage(),
                            c.stageUpdatedAt(),
                            c.createdAt(),
                            c.updatedAt()
                    ))
                    .orElseThrow(() -> new IllegalStateException("Candidate not found: " + candidateId));
        }
        
        // 5. Update candidate stage
        int updated = repo.updateCandidateStage(candidateId, request.toStage());
        if (updated == 0) {
            throw new IllegalStateException("Failed to update candidate stage: " + candidateId);
        }
        
        // 6. Insert history record (with reasonCode and jobId)
        repo.insertStageHistory(
                candidateId,
                currentStage != null ? currentStage : "new",
                request.toStage(),
                request.changedBy(),
                request.note(),
                request.reasonCode(),
                request.jobId()
        );
        
        // 7. Return updated candidate
        return repo.getCandidate(candidateId)
                .map(c -> new CandidateResponse(
                        c.candidateId(),
                        c.stage(),
                        c.stageUpdatedAt(),
                        c.createdAt(),
                        c.updatedAt()
                ))
                .orElseThrow(() -> new IllegalStateException("Candidate not found after update: " + candidateId));
    }

    /**
     * Get candidate info
     */
    public CandidateResponse getCandidate(String candidateId) {
        return repo.getCandidate(candidateId)
                .map(c -> new CandidateResponse(
                        c.candidateId(),
                        c.stage(),
                        c.stageUpdatedAt(),
                        c.createdAt(),
                        c.updatedAt()
                ))
                .orElseThrow(() -> new IllegalArgumentException("Candidate not found: " + candidateId));
    }

    /**
     * Get stage history for a candidate
     */
    public List<StageHistoryItem> getStageHistory(String candidateId) {
        return repo.getStageHistory(candidateId);
    }
}
