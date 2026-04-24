package com.fortune.resumeblueprint.infra;

import java.util.List;

/**
 * Structured result of JD analysis — shared across JdAnalyzer implementations.
 */
public record ParsedJdResult(
        List<String> requiredSkills,
        List<String> preferredSkills,
        Integer minYearsExperience,
        String level,
        String summary
) {
    public static ParsedJdResult empty() {
        return new ParsedJdResult(List.of(), List.of(), null, null, "");
    }
}
