package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.repo.MLTrainingRepo;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class MLTrainingService {
    private final MLTrainingRepo repo;

    public MLTrainingService(MLTrainingRepo repo) {
        this.repo = repo;
    }

    /**
     * Get training examples as maps
     */
    public List<Map<String, Object>> getTrainingExamples(Long jobId) {
        return repo.getTrainingExamples(jobId);
    }

    /**
     * Convert training examples to CSV format
     */
    public String toCsv(List<Map<String, Object>> examples) {
        if (examples.isEmpty()) {
            return "";
        }

        // Define column order (matching the VIEW structure)
        List<String> columns = List.of(
                "job_id", "candidate_id", "history_id",
                "label", "final_stage",
                "match_score", "overlap_score", "gap_penalty", "bonus_score",
                "skill_match_count", "year_diff", "risk_score",
                "stage_changed_at", "match_created_at", "reason_code"
        );

        // Build CSV header
        StringBuilder csv = new StringBuilder();
        csv.append(String.join(",", columns));
        csv.append("\n");

        // Build CSV rows
        for (Map<String, Object> example : examples) {
            List<String> values = columns.stream()
                    .map(col -> {
                        Object value = example.get(col);
                        if (value == null) {
                            return "";
                        }
                        String str = value.toString();
                        // Escape commas and quotes in CSV
                        if (str.contains(",") || str.contains("\"") || str.contains("\n")) {
                            str = "\"" + str.replace("\"", "\"\"") + "\"";
                        }
                        return str;
                    })
                    .collect(Collectors.toList());
            csv.append(String.join(",", values));
            csv.append("\n");
        }

        return csv.toString();
    }

    /**
     * Convert training examples to JSON format
     */
    public List<Map<String, Object>> toJson(List<Map<String, Object>> examples) {
        return examples;
    }
}
