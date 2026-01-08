package com.fortune.resumeblueprint.infra;

import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;

public interface LlmClient {
    AnalyzeResponse analyzeBootstrap(String resumeText);
    AnalyzeResponse analyzeWithBaseline(String resumeText, String[] baselineNormalized);
}
