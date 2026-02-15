package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.service.MLTrainingService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/ml")
public class MLTrainingController {
    
    private final MLTrainingService service;
    
    public MLTrainingController(MLTrainingService service) {
        this.service = service;
    }
    
    /**
     * Get training examples in CSV or JSON format
     * 
     * GET /api/ml/training-examples?jobId=123&format=csv
     * GET /api/ml/training-examples?format=json
     */
    @GetMapping("/training-examples")
    public ResponseEntity<?> getTrainingExamples(
            @RequestParam(required = false) Long jobId,
            @RequestParam(defaultValue = "csv") String format) {
        
        List<Map<String, Object>> examples = service.getTrainingExamples(jobId);
        
        if ("json".equalsIgnoreCase(format)) {
            List<Map<String, Object>> jsonData = service.toJson(examples);
            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(jsonData);
        } else {
            // Default to CSV
            String csv = service.toCsv(examples);
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=training_examples.csv")
                    .contentType(MediaType.parseMediaType("text/csv"))
                    .body(csv);
        }
    }
}
