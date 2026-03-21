package com.fortune.resumeblueprint.api.dto;

import java.util.List;

public record JdAnalyzeResponse(
        long jdId,
        List<String> requiredSkills,
        List<String> preferredSkills,
        Integer minYearsExperience,
        String level,
        String summary
) {}
