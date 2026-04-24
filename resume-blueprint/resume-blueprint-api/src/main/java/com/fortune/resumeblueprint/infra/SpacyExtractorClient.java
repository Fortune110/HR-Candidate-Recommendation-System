package com.fortune.resumeblueprint.infra;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Client for Python spaCy + SkillNER extraction service.
 * Integrates with 4-box framework at Box 1 (Extract stage).
 */
@Component
public class SpacyExtractorClient {

    private static final Logger log = LoggerFactory.getLogger(SpacyExtractorClient.class);

    public static final String DOC_TYPE_RESUME = "RESUME";
    public static final String DOC_TYPE_JD     = "JD";

    private final WebClient webClient;
    private final ObjectMapper om = new ObjectMapper();
    
    private final String extractServiceUrl;
    
    public SpacyExtractorClient(@Value("${extract.service.url:http://localhost:5000}") String extractServiceUrl) {
        this.extractServiceUrl = extractServiceUrl;
        this.webClient = WebClient.builder()
                .baseUrl(extractServiceUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }
    
    /**
     * Extract entities from English text using spaCy NER + SkillNER.
     * 
     * @param text Resume or JD text
     * @param docType "RESUME" or "JD"
     * @return Extraction result with entities and evidence
     */
    public ExtractionResult extract(String text, String docType) {
        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("text", text);
            payload.put("doc_type", docType != null ? docType : DOC_TYPE_RESUME);
            
            String raw = webClient.post()
                    .uri("/extract")
                    .bodyValue(payload)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            JsonNode response = raw != null ? om.readTree(raw) : null;
            
            if (response == null) {
                return new ExtractionResult(List.of(), "Extraction failed: no response", "spacy+skillner", "1.0");
            }
            
            List<ExtractedEntity> entities = new ArrayList<>();
            JsonNode entitiesNode = response.path("entities");
            
            if (entitiesNode.isArray()) {
                for (JsonNode entity : entitiesNode) {
                    entities.add(new ExtractedEntity(
                            entity.path("type").asText(""),
                            entity.path("label").asText(""),
                            entity.path("text").asText(""),
                            entity.path("normalized").asText(""),
                            entity.path("canonical").asText(""),
                            entity.path("start").asInt(0),
                            entity.path("end").asInt(0),
                            entity.path("evidence").asText("")
                    ));
                }
            }
            
            String summary = response.path("summary").asText("");
            String extractor = response.path("extractor").asText("spacy+skillner");
            String version = response.path("extractor_version").asText("1.0");
            
            return new ExtractionResult(entities, summary, extractor, version);
            
        } catch (Exception e) {
            log.error("extract() failed: docType={} error={}", docType, e.getMessage(), e);
            return new ExtractionResult(
                    List.of(),
                    "Extraction error: " + e.getMessage(),
                    "spacy+skillner",
                    "1.0"
            );
        }
    }
    
    /**
     * Upload a PDF or DOCX file to the extract service and return the raw extracted text.
     * Calls POST /extract/file and reads the "raw_text" field from the response.
     */
    public String extractFileText(byte[] fileBytes, String originalFilename, String docType) {
        String filename = originalFilename != null ? originalFilename : "upload.bin";
        MultipartBodyBuilder builder = new MultipartBodyBuilder();
        builder.part("file", new ByteArrayResource(fileBytes) {
            @Override
            public String getFilename() { return filename; }
        }).contentType(filename.toLowerCase().endsWith(".pdf")
                ? MediaType.APPLICATION_PDF
                : MediaType.APPLICATION_OCTET_STREAM);
        builder.part("doc_type", docType != null ? docType : DOC_TYPE_JD);

        try {
            String raw = WebClient.create(extractServiceUrl)
                    .post()
                    .uri("/extract/file")
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(BodyInserters.fromMultipartData(builder.build()))
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            if (raw == null || raw.isBlank()) {
                return "";
            }
            JsonNode response = om.readTree(raw);
            return response.path("raw_text").asText("");
        } catch (Exception e) {
            throw new RuntimeException("Failed to extract text from file via Python service: " + e.getMessage(), e);
        }
    }

    /**
     * Health check for extraction service
     */
    public boolean isHealthy() {
        try {
            String raw = webClient.get()
                    .uri("/health")
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            JsonNode response = raw != null ? om.readTree(raw) : null;

            return response != null && "ok".equals(response.path("status").asText(""));
        } catch (Exception e) {
            log.error("isHealthy() failed: {}", e.getMessage(), e);
            return false;
        }
    }
    
    public record ExtractionResult(
            List<ExtractedEntity> entities,
            String summary,
            String extractor,
            String extractorVersion
    ) {}
    
    public record ExtractedEntity(
            String type,           // "skill" | "ner"
            String label,          // "SKILL" | "PERSON" | "ORG" | "DATE" | ...
            String text,          // Original text
            String normalized,     // Normalized form
            String canonical,     // "skill/python" | "ner/ORG/Google" | ...
            int start,            // Character start position
            int end,              // Character end position
            String evidence       // Context around entity
    ) {}
}
