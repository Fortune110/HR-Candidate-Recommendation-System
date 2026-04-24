package com.fortune.resumeblueprint.infra;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.*;

public class OpenAIResponsesClient implements LlmClient {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(OpenAIResponsesClient.class);

    private final WebClient webClient;
    private final ObjectMapper om = new ObjectMapper();

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

    public OpenAIResponsesClient(String apiKey) {
        this.webClient = WebClient.builder()
                .baseUrl("https://api.openai.com/v1")
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    @Override
    public AnalyzeResponse analyzeBootstrap(String resumeText) {
        String prompt = """
You are a recruitment analysis assistant. Please extract "reusable keywords/skills/tech stack/job levels/domain terms" from the resume text.
Output must be JSON with fixed fields:
{
  "summary": "...",
  "experience_years": null,
  "keywords": [
    {"term":"...", "normalized":"...", "score":0.0, "evidence":"..."}
  ],
  "selectedTerms": [],
  "newTerms": []
}
Rules:
- normalized: lowercase, use '-' for spaces, remove extra symbols, e.g. "Spring Boot" -> "spring-boot"
- score: 0~1, higher for more certainty
- evidence: extract a sentence from the resume that best proves this term
- keywords: maximum 30, sorted by importance
- experience_years: integer, total years of relevant work experience inferred from dates/roles; null if not determinable
Resume text:
""" + resumeText;

        JsonNode root = callResponsesJson(prompt);
        return parseAnalyzeResponse(root, "bootstrap");
    }

    @Override
    public AnalyzeResponse analyzeWithBaseline(String resumeText, String[] baselineNormalized) {
        String baselineList = String.join(", ", baselineNormalized);

        String prompt = """
You are a recruitment analysis assistant. Given a "baseline term list", you must prioritize selecting matches from the baseline.
Output must be JSON with fixed fields:
{
  "summary": "...",
  "keywords": [],
  "selectedTerms": ["..."],
  "newTerms": [
    {"term":"...", "normalized":"...", "score":0.0, "evidence":"..."}
  ]
}
Rules:
- selectedTerms can only come from baseline (use normalized values)
- newTerms are for important new terms outside baseline (maximum 10)
- normalized: lowercase, use '-' for spaces, remove extra symbols
baseline (normalized list):
""" + baselineList + """
Resume text:
""" + resumeText;

        JsonNode root = callResponsesJson(prompt);
        return parseAnalyzeResponse(root, "baseline");
    }

    private JsonNode callResponsesJson(String prompt) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", model);
        payload.put("input", prompt);

        // Make the model "try to output JSON" - we can upgrade to strict schema later
        payload.put("text", Map.of("format", Map.of("type", "json_object")));

        return webClient.post()
                .uri("/responses")
                .bodyValue(payload)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .block();
    }

    private AnalyzeResponse parseAnalyzeResponse(JsonNode root, String mode) {
        // Extract JSON string from responses' output_text
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
            // Fallback: if output_text is not obtained, return empty structure
            return new AnalyzeResponse(0L, mode, "", List.of(), List.of(), List.of(), null);
        }

        try {
            JsonNode j = om.readTree(jsonText);
            String summary = j.path("summary").asText("");

            JsonNode expNode = j.path("experience_years");
            Integer experienceYears = (!expNode.isMissingNode() && !expNode.isNull()) ? expNode.asInt() : null;

            List<AnalyzeResponse.KeywordItem> keywords = new ArrayList<>();
            for (JsonNode k : j.path("keywords")) {
                keywords.add(new AnalyzeResponse.KeywordItem(
                        k.path("term").asText(),
                        k.path("normalized").asText(),
                        k.path("score").asDouble(0.5),
                        k.path("evidence").asText("")
                ));
            }

            List<String> selected = new ArrayList<>();
            for (JsonNode s : j.path("selectedTerms")) {
                selected.add(s.asText());
            }

            List<AnalyzeResponse.KeywordItem> newTerms = new ArrayList<>();
            for (JsonNode k : j.path("newTerms")) {
                newTerms.add(new AnalyzeResponse.KeywordItem(
                        k.path("term").asText(),
                        k.path("normalized").asText(),
                        k.path("score").asDouble(0.5),
                        k.path("evidence").asText("")
                ));
            }

            return new AnalyzeResponse(0L, mode, summary, keywords, selected, newTerms, experienceYears);
        } catch (Exception e) {
            log.error("parseAnalyzeResponse() failed: mode={} error={}", mode, e.getMessage(), e);
            return new AnalyzeResponse(0L, mode, "", List.of(), List.of(), List.of(), null);
        }
    }
}
