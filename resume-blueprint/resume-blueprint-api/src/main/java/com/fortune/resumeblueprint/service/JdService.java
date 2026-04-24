package com.fortune.resumeblueprint.service;

import com.fortune.resumeblueprint.api.dto.JdAnalyzeResponse;
import com.fortune.resumeblueprint.infra.JdAnalyzer;
import com.fortune.resumeblueprint.infra.ParsedJdResult;
import com.fortune.resumeblueprint.infra.SpacyExtractorClient;
import com.fortune.resumeblueprint.repo.JdRepo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;

@Service
public class JdService {

    private static final Logger log = LoggerFactory.getLogger(JdService.class);

    private final JdRepo jdRepo;
    private final SpacyExtractorClient spacyClient;
    private final JdAnalyzer jdAnalyzer;

    public JdService(JdRepo jdRepo, SpacyExtractorClient spacyClient, JdAnalyzer jdAnalyzer) {
        this.jdRepo = jdRepo;
        this.spacyClient = spacyClient;
        this.jdAnalyzer = jdAnalyzer;
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

        ParsedJdResult parsed = jdAnalyzer.analyze(text);

        long jdId = jdRepo.saveJd(
                contentHash,
                text,
                parsed.requiredSkills(),
                parsed.preferredSkills(),
                parsed.minYearsExperience(),
                parsed.level(),
                parsed.summary(),
                jdAnalyzer.modelName()
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

    private String sha256(String s) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] dig = md.digest(s.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(dig);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
