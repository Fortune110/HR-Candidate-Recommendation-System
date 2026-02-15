package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.service.CandidateService;
import com.fortune.resumeblueprint.api.dto.ChangeStageRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@SpringBootTest
@Transactional
class MLTrainingControllerIntegrationTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    @Autowired
    private CandidateService candidateService;

    @Autowired
    private JdbcTemplate jdbc;

    private MockMvc mockMvc;

    @org.junit.jupiter.api.BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    @Test
    void testGetTrainingExamples_Csv() throws Exception {
        // Given: Create test data with job_id and final_stage = 'hired'
        String candidateId = "test_ml_hired_001";
        Long jobId = 999L;

        // Create candidate and update stage to hired with job_id
        candidateService.updateStage(candidateId, new ChangeStageRequest(
                "hired",
                "hr_user_001",
                "Test hired for ML training",
                null,
                jobId,
                false
        ));

        // When: Call the API with CSV format
        mockMvc.perform(get("/api/ml/training-examples")
                        .param("jobId", jobId.toString())
                        .param("format", "csv"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(header().string("Content-Disposition", 
                        "attachment; filename=training_examples.csv"))
                .andExpect(content().string(containsString("job_id")))
                .andExpect(content().string(containsString("label")))
                .andExpect(content().string(containsString("match_score")))
                .andExpect(content().string(containsString("skill_match_count")));
    }

    @Test
    void testGetTrainingExamples_Json() throws Exception {
        // Given: Create test data with job_id and final_stage = 'rejected'
        String candidateId = "test_ml_rejected_001";
        Long jobId = 888L;

        // Create candidate and update stage to rejected with job_id
        candidateService.updateStage(candidateId, new ChangeStageRequest(
                "rejected",
                "hr_user_002",
                "Test rejected for ML training",
                "TECH_MISMATCH",
                jobId,
                false
        ));

        // When: Call the API with JSON format
        mockMvc.perform(get("/api/ml/training-examples")
                        .param("jobId", jobId.toString())
                        .param("format", "json"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0].job_id").value(jobId.intValue()))
                .andExpect(jsonPath("$[0].candidate_id").value(candidateId))
                .andExpect(jsonPath("$[0].label").value(0))  // rejected -> 0
                .andExpect(jsonPath("$[0].final_stage").value("rejected"));
    }

    @Test
    void testGetTrainingExamples_WithoutJobId() throws Exception {
        // Given: Create test data without job_id filter
        String candidateId1 = "test_ml_no_filter_001";
        Long jobId1 = 777L;
        
        candidateService.updateStage(candidateId1, new ChangeStageRequest(
                "hired",
                "hr_user_003",
                "Test for no filter",
                null,
                jobId1,
                false
        ));

        // When: Call the API without jobId parameter
        mockMvc.perform(get("/api/ml/training-examples")
                        .param("format", "csv"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(containsString("job_id")))
                .andExpect(content().string(containsString(candidateId1)));
    }

    @Test
    void testGetTrainingExamples_EmptyResult() throws Exception {
        // Given: No data for a non-existent job_id
        Long nonExistentJobId = 99999L;

        // When: Call the API with non-existent job_id
        mockMvc.perform(get("/api/ml/training-examples")
                        .param("jobId", nonExistentJobId.toString())
                        .param("format", "csv"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("text/csv"))
                .andExpect(content().string(""));
    }
}
