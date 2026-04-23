package com.fortune.resumeblueprint.infra;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class LlmClientConfig {

    private static final Logger log = LoggerFactory.getLogger(LlmClientConfig.class);

    @Bean
    public LlmClient llmClient(@Value("${openai.apiKey:}") String apiKey) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("openai.apiKey not set — using StubLlmClient (keyword scan only). Set OPENAI_API_KEY for AI analysis.");
            return new StubLlmClient();
        }
        log.info("openai.apiKey configured — using OpenAIResponsesClient.");
        return new OpenAIResponsesClient(apiKey);
    }
}
