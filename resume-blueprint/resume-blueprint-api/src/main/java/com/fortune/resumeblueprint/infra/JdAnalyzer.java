package com.fortune.resumeblueprint.infra;

/**
 * Strategy interface for JD analysis.
 * Implementations: OpenAiJdAnalyzer (live), StubJdAnalyzer (fallback).
 */
public interface JdAnalyzer {
    ParsedJdResult analyze(String jdText);

    default String modelName() {
        return "none";
    }
}
