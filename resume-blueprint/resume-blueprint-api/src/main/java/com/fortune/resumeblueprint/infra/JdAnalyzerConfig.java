package com.fortune.resumeblueprint.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JdAnalyzerConfig {

    private static final Logger log = LoggerFactory.getLogger(JdAnalyzerConfig.class);

    @Bean
    public JdAnalyzer jdAnalyzer(
            @Value("${openai.apiKey:}") String apiKey,
            @Value("${openai.model:gpt-4o-mini}") String model) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("openai.apiKey not set — using StubJdAnalyzer (keyword scan only). Set OPENAI_API_KEY for AI analysis.");
            return new StubJdAnalyzer();
        }
        log.info("openai.apiKey configured — using OpenAiJdAnalyzer (model={}).", model);
        return new OpenAiJdAnalyzer(apiKey, model);
    }
}
