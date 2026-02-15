package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.api.dto.CandidateResponse;
import com.fortune.resumeblueprint.api.dto.ChangeStageRequest;
import com.fortune.resumeblueprint.api.dto.StageHistoryItem;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
class CandidateServiceTest {

    @Autowired
    private CandidateService candidateService;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void testUpdateStageWithReasonCode() {
        // Given: A candidate ID
        String candidateId = "test_candidate_reason_code_001";

        // When: Update stage with reasonCode
        ChangeStageRequest request = new ChangeStageRequest(
                "screened",
                "hr_user_001",
                "Initial screening completed",
                "TECH_MISMATCH",
                123L,
                false
        );

        CandidateResponse response = candidateService.updateStage(candidateId, request);

        // Then: Verify stage is updated
        assertEquals("screened", response.stage());
        assertNotNull(response.stageUpdatedAt());

        // Then: Verify history record contains reason_code and job_id
        List<StageHistoryItem> history = candidateService.getStageHistory(candidateId);
        assertFalse(history.isEmpty(), "History should not be empty");

        StageHistoryItem latestHistory = history.get(0);
        assertEquals("new", latestHistory.fromStage());
        assertEquals("screened", latestHistory.toStage());
        assertEquals("TECH_MISMATCH", latestHistory.reasonCode(), "reason_code should be set in history");
        assertEquals(123L, latestHistory.jobId(), "job_id should be set in history");
        assertEquals("hr_user_001", latestHistory.changedBy());
        assertEquals("Initial screening completed", latestHistory.note());
    }

    @Test
    void testUpdateStageWithNullReasonCode() {
        // Given: A candidate ID
        String candidateId = "test_candidate_no_reason_001";

        // When: Update stage without reasonCode
        ChangeStageRequest request = new ChangeStageRequest(
                "shortlisted",
                "hr_user_002",
                "Candidate looks good",
                null,  // reasonCode is null
                null,  // jobId is null
                false
        );

        CandidateResponse response = candidateService.updateStage(candidateId, request);

        // Then: Verify stage is updated
        assertEquals("shortlisted", response.stage());

        // Then: Verify history record exists with null reason_code
        List<StageHistoryItem> history = candidateService.getStageHistory(candidateId);
        assertFalse(history.isEmpty());

        StageHistoryItem latestHistory = history.get(0);
        assertEquals("shortlisted", latestHistory.toStage());
        assertNull(latestHistory.reasonCode(), "reason_code should be null when not provided");
        assertNull(latestHistory.jobId(), "job_id should be null when not provided");
    }

    @Test
    void testMultipleStageUpdatesWithReasonCodes() {
        // Given: A candidate ID
        String candidateId = "test_candidate_multiple_001";

        // When: Perform multiple stage updates with different reason codes
        candidateService.updateStage(candidateId, new ChangeStageRequest(
                "screened", "hr_user_001", "First screening", "TECH_MISMATCH", 123L, false));
        
        candidateService.updateStage(candidateId, new ChangeStageRequest(
                "shortlisted", "hr_user_002", "Re-evaluated", null, 123L, false));
        
        candidateService.updateStage(candidateId, new ChangeStageRequest(
                "rejected", "hr_user_003", "Final decision", "SALARY", 123L, false));

        // Then: Verify all history records are saved with correct reason codes
        List<StageHistoryItem> history = candidateService.getStageHistory(candidateId);
        assertEquals(3, history.size(), "Should have 3 history records");

        // Verify latest (rejected)
        StageHistoryItem latest = history.get(0);
        assertEquals("rejected", latest.toStage());
        assertEquals("SALARY", latest.reasonCode());

        // Verify second (shortlisted)
        StageHistoryItem second = history.get(1);
        assertEquals("shortlisted", second.toStage());
        assertNull(second.reasonCode());

        // Verify first (screened)
        StageHistoryItem first = history.get(2);
        assertEquals("screened", first.toStage());
        assertEquals("TECH_MISMATCH", first.reasonCode());
    }

    @Test
    void testUpdateStageWithVariousReasonCodes() {
        // Given: A candidate ID
        String candidateId = "test_candidate_reasons_001";

        // Test various reason codes
        String[] reasonCodes = {
                "TECH_MISMATCH",
                "SALARY",
                "CANDIDATE_DECLINED",
                "HC_FROZEN",
                "NO_SHOW",
                "OTHER"
        };

        // When: Update stage with each reason code
        for (int i = 0; i < reasonCodes.length; i++) {
            candidateService.updateStage(candidateId, new ChangeStageRequest(
                    i == 0 ? "screened" : "rejected",
                    "hr_user_001",
                    "Test reason: " + reasonCodes[i],
                    reasonCodes[i],
                    (long) (100 + i),
                    i == 0 ? false : true  // Force for rejected stage
            ));
        }

        // Then: Verify all reason codes are saved
        List<StageHistoryItem> history = candidateService.getStageHistory(candidateId);
        assertEquals(reasonCodes.length, history.size());

        // Verify each history item has the correct reason code
        for (int i = 0; i < reasonCodes.length; i++) {
            StageHistoryItem item = history.get(reasonCodes.length - 1 - i); // History is reversed
            assertEquals(reasonCodes[i], item.reasonCode(), 
                    "History item " + i + " should have reason_code: " + reasonCodes[i]);
        }
    }

    @Test
    void testDirectDatabaseVerification() {
        // Given: A candidate ID
        String candidateId = "test_db_verification_001";

        // When: Update stage with reasonCode
        ChangeStageRequest request = new ChangeStageRequest(
                "interviewed",
                "hr_user_db_test",
                "Database verification test",
                "CANDIDATE_DECLINED",
                456L,
                false
        );

        candidateService.updateStage(candidateId, request);

        // Then: Verify directly in database that reason_code and job_id are stored
        String sql = """
            select reason_code, job_id, from_stage, to_stage, changed_by
            from rb_candidate_stage_history
            where candidate_id = ?
            order by changed_at desc
            limit 1
            """;

        var result = jdbc.queryForMap(sql, candidateId);

        assertEquals("CANDIDATE_DECLINED", result.get("reason_code"), 
                "reason_code should be stored in database");
        assertEquals(456L, result.get("job_id"), 
                "job_id should be stored in database");
        assertEquals("new", result.get("from_stage"));
        assertEquals("interviewed", result.get("to_stage"));
        assertEquals("hr_user_db_test", result.get("changed_by"));
    }
}
