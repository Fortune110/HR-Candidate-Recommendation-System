package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.CandidateResponse;
import com.fortune.resumeblueprint.api.dto.ChangeStageRequest;
import com.fortune.resumeblueprint.api.dto.StageHistoryItem;
import com.fortune.resumeblueprint.service.CandidateService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/candidates")
public class CandidateController {
    
    private final CandidateService candidateService;
    
    public CandidateController(CandidateService candidateService) {
        this.candidateService = candidateService;
    }
    
    /**
     * Get candidate info
     * 
     * GET /api/candidates/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<CandidateResponse> getCandidate(@PathVariable String id) {
        CandidateResponse response = candidateService.getCandidate(id);
        return ResponseEntity.ok(response);
    }
    
    /**
     * Update candidate stage
     * 
     * PATCH /api/candidates/{id}/stage
     * Body: {
     *   "toStage": "rejected",
     *   "changedBy": "hr_user_001",
     *   "note": "Candidate declined offer",
     *   "reasonCode": "CANDIDATE_DECLINED",
     *   "jobId": 123,
     *   "force": false
     * }
     */
    @PatchMapping("/{id}/stage")
    public ResponseEntity<CandidateResponse> updateStage(
            @PathVariable String id,
            @RequestBody @Valid ChangeStageRequest request) {
        CandidateResponse response = candidateService.updateStage(id, request);
        return ResponseEntity.ok(response);
    }
    
    /**
     * Get stage history for a candidate
     * 
     * GET /api/candidates/{id}/stage/history
     */
    @GetMapping("/{id}/stage/history")
    public ResponseEntity<List<StageHistoryItem>> getStageHistory(@PathVariable String id) {
        List<StageHistoryItem> history = candidateService.getStageHistory(id);
        return ResponseEntity.ok(history);
    }
}
