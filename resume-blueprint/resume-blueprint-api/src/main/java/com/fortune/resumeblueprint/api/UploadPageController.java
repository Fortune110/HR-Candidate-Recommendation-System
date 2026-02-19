package com.fortune.resumeblueprint.api;

import org.springframework.core.io.ClassPathResource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * Controller for serving the upload page.
 */
@RestController
public class UploadPageController {
    
    @GetMapping(value = "/upload", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> uploadPage() {
        try {
            ClassPathResource resource = new ClassPathResource("static/upload.html");
            String html = StreamUtils.copyToString(resource.getInputStream(), StandardCharsets.UTF_8);
            return ResponseEntity.ok(html);
        } catch (IOException e) {
            return ResponseEntity.ok(getDefaultHtml());
        }
    }
    
    private String getDefaultHtml() {
        return """
            <!DOCTYPE html>
            <html>
            <head><title>Upload Page Error</title></head>
            <body><h1>Upload page not found</h1></body>
            </html>
            """;
    }
}
