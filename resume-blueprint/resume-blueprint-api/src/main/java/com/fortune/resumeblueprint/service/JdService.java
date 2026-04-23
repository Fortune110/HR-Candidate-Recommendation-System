package com.fortune.resumeblueprint.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortune.resumeblueprint.api.dto.JdAnalyzeResponse;
import com.fortune.resumeblueprint.infra.SpacyExtractorClient;
import com.fortune.resumeblueprint.repo.JdRepo;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.client.WebClient;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class JdService {

    private final JdRepo jdRepo;
    private final SpacyExtractorClient spacyClient;
    private final WebClient webClient;
    private final ObjectMapper om = new ObjectMapper();

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

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

    public JdService(JdRepo jdRepo,
                     SpacyExtractorClient spacyClient,
                     @Value("${openai.apiKey:}") String apiKey) {
        this.jdRepo = jdRepo;
        this.spacyClient = spacyClient;
        this.webClient = WebClient.builder()
                .baseUrl("https://api.openai.com/v1")
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    public String extractTextFromFile(MultipartFile file) {
        try {
            String filename = file.getOriginalFilename() != null ? file.getOriginalFilename() : "upload.bin";
            return spacyClient.extractFileText(file.getBytes(), filename, SpacyExtractorClient.DOC_TYPE_JD);
        } catch (Exception e) {
            throw new RuntimeException("Failed to extract text from uploaded JD file: " + e.getMessage(), e);
        }
    }

    public JdAnalyzeResponse analyze(String text) {
        String contentHash = "sha256:" + sha256(text);

        // Call OpenAI
        ParsedJd parsed = callOpenAI(text);

        // Persist and get jd_id (idempotent on same hash)
        long jdId = jdRepo.saveJd(
                contentHash,
                text,
                parsed.requiredSkills(),
                parsed.preferredSkills(),
                parsed.minYearsExperience(),
                parsed.level(),
                parsed.summary(),
                model
        );

        return new JdAnalyzeResponse(
                jdId,
                parsed.requiredSkills(),
                parsed.preferredSkills(),
                parsed.minYearsExperience(),
                parsed.level(),
                parsed.summary()
        );
    }

    private ParsedJd callOpenAI(String jdText) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", model);
        payload.put("input", PROMPT_TEMPLATE + jdText);
        payload.put("text", Map.of("format", Map.of("type", "json_object")));

        try {
            // Use String + om.readTree() — bodyToMono(JsonNode.class) has a WebFlux codec issue
            String raw = webClient.post()
                    .uri("/responses")
                    .bodyValue(payload)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            if (raw == null || raw.isBlank()) {
                return ParsedJd.empty();
            }

            JsonNode root = om.readTree(raw);

            // Extract output_text from the Responses API envelope
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
                return ParsedJd.empty();
            }

            JsonNode j = om.readTree(jsonText);
            return new ParsedJd(
                    readStringList(j.path("requiredSkills")),
                    readStringList(j.path("preferredSkills")),
                    j.path("minYearsExperience").isNull() ? null : j.path("minYearsExperience").asInt(),
                    j.path("level").isNull() || j.path("level").isMissingNode() ? null : j.path("level").asText(null),
                    j.path("summary").asText("")
            );

        } catch (Exception e) {
            return ParsedJd.empty();
        }
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

    private String sha256(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] dig = md.digest(s.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(dig);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private record ParsedJd(
            List<String> requiredSkills,
            List<String> preferredSkills,
            Integer minYearsExperience,
            String level,
            String summary
    ) {
        static ParsedJd empty() {
            return new ParsedJd(List.of(), List.of(), null, null, "");
        }
    }
}
