# Starting the App Without Running Tests

## Problem

Test classes have compilation errors, but the main application code is fine.

## Solution — Skip Tests at Startup

```bash
cd ~/Desktop/HR-Candidate-Recommendation-System/resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run -DskipTests
```

## Alternative — Rename Test Files Temporarily

```bash
cd src/test/java/com/fortune/resumeblueprint/api
mv ResumeControllerIntegrationTest.java ResumeControllerIntegrationTest.java.bak
mv ExtractControllerIntegrationTest.java ExtractControllerIntegrationTest.java.bak
mv MatchControllerIntegrationTest.java MatchControllerIntegrationTest.java.bak

# Then start normally
cd ~/Desktop/HR-Candidate-Recommendation-System/resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
```
