package com.fortune.resumeblueprint.infra;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * OpenAI-backed JdAnalyzer using the Responses API.
 * Activated when openai.apiKey is configured (see JdAnalyzerConfig).
 */
public class OpenAiJdAnalyzer implements JdAnalyzer {

    private static final Logger log = LoggerFactory.getLogger(OpenAiJdAnalyzer.class);

    private static final String PROMPT_TEMPLATE = """
You are a recruitment analysis assistant. Extract structured information from the job description below.
Output must be valid JSON with exactly this structure:
{
  "summary": "one sentence describing the role and seniority",
  "requiredSkills": ["skill-one", "skill-two"],
  "preferredSkills": ["skill-three"],
  "minYearsExperience": 3,
  "level": "mid"
}
Rules:
- requiredSkills: skills explicitly marked as required, must-have, or essential (normalized: lowercase, spaces → hyphens)
- preferredSkills: skills marked as nice-to-have, preferred, bonus, or plus (same normalization)
- minYearsExperience: integer; use the minimum stated; null if not mentioned
- level: one of "junior", "mid", "senior"; infer from years or title; null if genuinely unclear
- summary: concise, one sentence, mention tech stack and seniority if available
Job description:
""";

    private final WebClient webClient;
    private final ObjectMapper om = new ObjectMapper();
    private final String model;

    public OpenAiJdAnalyzer(String apiKey, String model) {
        this.model = model;
        this.webClient = WebClient.builder()
                .baseUrl("https://api.openai.com/v1")
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    @Override
    public ParsedJdResult analyze(String jdText) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", model);
        payload.put("input", PROMPT_TEMPLATE + jdText);
        payload.put("text", Map.of("format", Map.of("type", "json_object")));

        try {
            String raw = webClient.post()
                    .uri("/responses")
                    .bodyValue(payload)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            if (raw == null || raw.isBlank()) {
                return ParsedJdResult.empty();
            }

            JsonNode root = om.readTree(raw);

            String jsonText = null;
            JsonNode output = root.path("output");
            if (output.isArray()) {
                for (JsonNode item : output) {
                    JsonNode content = item.path("content");
                    if (content.isArray()) {
                        for (JsonNode c : content) {
                            if ("output_text".equals(c.path("type").asText())) {
                                jsonText = c.path("text").asText();
                                break;
                            }
                        }
                    }
                }
            }

            if (jsonText == null || jsonText.isBlank()) {
                return ParsedJdResult.empty();
            }

            JsonNode j = om.readTree(jsonText);
            return new ParsedJdResult(
                    readStringList(j.path("requiredSkills")),
                    readStringList(j.path("preferredSkills")),
                    j.path("minYearsExperience").isNull() ? null : j.path("minYearsExperience").asInt(),
                    j.path("level").isNull() || j.path("level").isMissingNode() ? null : j.path("level").asText(null),
                    j.path("summary").asText("")
            );

        } catch (Exception e) {
            log.error("OpenAiJdAnalyzer.analyze() failed: error={}", e.getMessage(), e);
            return ParsedJdResult.empty();
        }
    }

    @Override
    public String modelName() {
        return model;
    }

    private List<String> readStringList(JsonNode node) {
        List<String> result = new ArrayList<>();
        if (node.isArray()) {
            for (JsonNode item : node) {
                String v = item.asText("").strip();
                if (!v.isEmpty()) result.add(v);
            }
        }
        return result;
    }
}
