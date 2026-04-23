package com.fortune.resumeblueprint.infra;

import com.fortune.resumeblueprint.api.dto.AnalyzeResponse;
import java.util.ArrayList;
import java.util.List;

/**
 * Fallback LlmClient used when openai.apiKey is not configured.
 * Scans resume text against a list of known tech skills — no network call required.
 * Replace by setting OPENAI_API_KEY to activate OpenAIResponsesClient instead.
 */
public class StubLlmClient implements LlmClient {

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
            new String[]{"JUnit", "junit"},
            new String[]{"Hibernate", "hibernate"},
            new String[]{"JPA", "jpa"},
            new String[]{"SQL", "sql"},
            new String[]{"HTML", "html"},
            new String[]{"CSS", "css"},
            new String[]{"REST", "rest-api"},
            new String[]{"Machine Learning", "machine-learning"},
            new String[]{"TensorFlow", "tensorflow"},
            new String[]{"PyTorch", "pytorch"},
            new String[]{"Golang", "golang"},
            new String[]{"Kotlin", "kotlin"},
            new String[]{"Swift", "swift"},
            new String[]{"Flutter", "flutter"},
            new String[]{"Vue", "vue"},
            new String[]{"Angular", "angular"},
            new String[]{"Next.js", "nextjs"},
            new String[]{"Elasticsearch", "elasticsearch"},
            new String[]{"Nginx", "nginx"},
            new String[]{"Jenkins", "jenkins"},
            new String[]{"GitHub Actions", "github-actions"},
            new String[]{"Terraform", "terraform"}
    );

    @Override
    public AnalyzeResponse analyzeBootstrap(String resumeText) {
        List<AnalyzeResponse.KeywordItem> keywords = extractKeywords(resumeText);
        String summary = "Stub analysis — " + keywords.size() + " skills detected. "
                + "Set OPENAI_API_KEY for AI-powered analysis.";
        return new AnalyzeResponse(0L, "bootstrap", summary, keywords, List.of(), List.of(), null);
    }

    @Override
    public AnalyzeResponse analyzeWithBaseline(String resumeText, String[] baselineNormalized) {
        List<AnalyzeResponse.KeywordItem> keywords = extractKeywords(resumeText);
        List<String> baselineSet = List.of(baselineNormalized);
        List<String> selectedTerms = new ArrayList<>();
        List<AnalyzeResponse.KeywordItem> newTerms = new ArrayList<>();
        for (AnalyzeResponse.KeywordItem kw : keywords) {
            if (baselineSet.contains(kw.normalized())) {
                selectedTerms.add(kw.normalized());
            } else {
                newTerms.add(kw);
            }
        }
        return new AnalyzeResponse(0L, "baseline", "Stub baseline analysis.",
                List.of(), selectedTerms, newTerms, null);
    }

    private List<AnalyzeResponse.KeywordItem> extractKeywords(String text) {
        String lower = text.toLowerCase();
        List<AnalyzeResponse.KeywordItem> found = new ArrayList<>();
        for (String[] skill : KNOWN_SKILLS) {
            if (lower.contains(skill[0].toLowerCase())) {
                found.add(new AnalyzeResponse.KeywordItem(skill[0], skill[1], 0.75, ""));
            }
        }
        return found;
    }
}
