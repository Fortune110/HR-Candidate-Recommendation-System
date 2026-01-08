package com.fortune.resumeblueprint.infra;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.*;

@Component
public class OpenAIResponsesClient implements LlmClient {

    private final WebClient webClient;
    private final ObjectMapper om = new ObjectMapper();

    @Value("${openai.model:gpt-4o-mini}")
    private String model;

    public OpenAIResponsesClient(@Value("${openai.apiKey:}") String apiKey) {
        this.webClient = WebClient.builder()
                .baseUrl("https://api.openai.com/v1")
                .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    @Override
    public AnalyzeResponse analyzeBootstrap(String resumeText) {
        String prompt = """
你是一个招聘分析助手。请从简历文本中提取“可复用的关键词/技能/技术栈/职位级别/领域词”。
输出必须是 JSON，字段固定：
{
  "summary": "...",
  "keywords": [
    {"term":"...", "normalized":"...", "score":0.0, "evidence":"..."}
  ],
  "selectedTerms": [],
  "newTerms": []
}
规则：
- normalized：小写、空格用 '-'，去掉多余符号，例如 "Spring Boot" -> "spring-boot"
- score：0~1，越确定越高
- evidence：从简历中摘一句最能证明该词的原文片段
- keywords 最多 30 个，按重要性排序
简历文本：
""" + resumeText;

        JsonNode root = callResponsesJson(prompt);
        return parseAnalyzeResponse(root, "bootstrap");
    }

    @Override
    public AnalyzeResponse analyzeWithBaseline(String resumeText, String[] baselineNormalized) {
        String baselineList = String.join(", ", baselineNormalized);

        String prompt = """
你是一个招聘分析助手。给你一份“基本词表 baseline”，你必须优先从 baseline 中选择匹配项。
输出必须是 JSON，字段固定：
{
  "summary": "...",
  "keywords": [],
  "selectedTerms": ["..."],
  "newTerms": [
    {"term":"...", "normalized":"...", "score":0.0, "evidence":"..."}
  ]
}
规则：
- selectedTerms 只能来自 baseline（用 normalized 值）
- newTerms 用于 baseline 之外但很重要的新词（最多 10 个）
- normalized：小写、空格用 '-'，去掉多余符号
baseline（normalized 列表）：
""" + baselineList + """
简历文本：
""" + resumeText;

        JsonNode root = callResponsesJson(prompt);
        return parseAnalyzeResponse(root, "baseline");
    }

    private JsonNode callResponsesJson(String prompt) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("model", model);
        payload.put("input", prompt);

        // 让模型“尽量输出 JSON”——后续我们也可以升级到严格 schema
        payload.put("text", Map.of("format", Map.of("type", "json_object")));

        return webClient.post()
                .uri("/responses")
                .bodyValue(payload)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .block();
    }

    private AnalyzeResponse parseAnalyzeResponse(JsonNode root, String mode) {
        // 从 responses 的 output_text 取 JSON 字符串
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
            // 兜底：如果没拿到 output_text，就返回空结构
            return new AnalyzeResponse(0L, mode, "", List.of(), List.of(), List.of());
        }

        try {
            JsonNode j = om.readTree(jsonText);
            String summary = j.path("summary").asText("");

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

            return new AnalyzeResponse(0L, mode, summary, keywords, selected, newTerms);
        } catch (Exception e) {
            return new AnalyzeResponse(0L, mode, "", List.of(), List.of(), List.of());
        }
    }
}
