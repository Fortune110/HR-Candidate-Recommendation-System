package com.fortune.resumeblueprint.infra;

import java.util.ArrayList;
import java.util.List;

/**
 * Fallback JdAnalyzer used when openai.apiKey is not configured.
 * Scans JD text against a list of known tech skills — no network call required.
 * Replace by setting OPENAI_API_KEY to activate OpenAiJdAnalyzer instead.
 */
public class StubJdAnalyzer implements JdAnalyzer {

    // {display term, normalized form}
    private static final List<String[]> KNOWN_SKILLS = List.of(
            new String[]{"Java", "java"},
            new String[]{"Python", "python"},
            new String[]{"JavaScript", "javascript"},
            new String[]{"TypeScript", "typescript"},
            new String[]{"Spring Boot", "spring-boot"},
            new String[]{"Spring", "spring"},
            new String[]{"React", "react"},
            new String[]{"Node.js", "nodejs"},
            new String[]{"Docker", "docker"},
            new String[]{"Kubernetes", "kubernetes"},
            new String[]{"PostgreSQL", "postgresql"},
            new String[]{"MySQL", "mysql"},
            new String[]{"MongoDB", "mongodb"},
            new String[]{"Redis", "redis"},
            new String[]{"AWS", "aws"},
            new String[]{"GCP", "gcp"},
            new String[]{"Azure", "azure"},
            new String[]{"Git", "git"},
            new String[]{"CI/CD", "ci-cd"},
            new String[]{"GraphQL", "graphql"},
            new String[]{"Kafka", "kafka"},
            new String[]{"Microservices", "microservices"},
            new String[]{"Linux", "linux"},
            new String[]{"Maven", "maven"},
            new String[]{"Gradle", "gradle"},
            new String[]{"REST", "rest-api"},
            new String[]{"Machine Learning", "machine-learning"},
            new String[]{"Golang", "golang"},
            new String[]{"Kotlin", "kotlin"},
            new String[]{"Terraform", "terraform"}
    );

    @Override
    public ParsedJdResult analyze(String jdText) {
        List<String> required = extractSkills(jdText);
        String summary = "Stub analysis — " + required.size() + " skills detected. "
                + "Set OPENAI_API_KEY for AI-powered JD analysis.";
        return new ParsedJdResult(required, List.of(), null, null, summary);
    }

    @Override
    public String modelName() {
        return "stub";
    }

    private List<String> extractSkills(String text) {
        String lower = text.toLowerCase();
        List<String> found = new ArrayList<>();
        for (String[] skill : KNOWN_SKILLS) {
            if (lower.contains(skill[0].toLowerCase())) {
                found.add(skill[1]);
            }
        }
        return found;
    }
}
