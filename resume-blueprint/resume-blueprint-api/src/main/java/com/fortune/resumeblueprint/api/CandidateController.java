package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.CandidateListItemResponse;
import com.fortune.resumeblueprint.repo.BlueprintRepo;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/candidates")
public class CandidateController {

    private final BlueprintRepo repo;

    public CandidateController(BlueprintRepo repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<CandidateListItemResponse> list(
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(defaultValue = "0") int offset
    ) {
        int safeLimit = Math.min(Math.max(limit, 1), 200);
        int safeOffset = Math.max(offset, 0);
        return repo.listCandidates(safeLimit, safeOffset).stream()
                .map(r -> new CandidateListItemResponse(
                        r.documentId(),
                        r.candidateId(),
                        r.entityType(),
                        r.createdAt(),
                        r.experienceYears(),
                        r.seniorityLevel()
                ))
                .toList();
    }
}
