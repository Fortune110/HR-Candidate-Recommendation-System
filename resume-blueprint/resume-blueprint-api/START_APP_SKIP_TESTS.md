# Start the app (skip tests)

## Problem
Test classes fail to compile, but the main app code is fine.

## Solution: temporarily rename test files

Before starting the app, run:

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api

# Temporarily rename test files to avoid compilation
Move-Item -Path "src\test\java\com\fortune\resumeblueprint\api\ResumeControllerIntegrationTest.java" -Destination "src\test\java\com\fortune\resumeblueprint\api\ResumeControllerIntegrationTest.java.bak" -ErrorAction SilentlyContinue
Move-Item -Path "src\test\java\com\fortune\resumeblueprint\api\ExtractControllerIntegrationTest.java" -Destination "src\test\java\com\fortune\resumeblueprint\api\ExtractControllerIntegrationTest.java.bak" -ErrorAction SilentlyContinue
Move-Item -Path "src\test\java\com\fortune\resumeblueprint\api\MatchControllerIntegrationTest.java" -Destination "src\test\java\com\fortune\resumeblueprint\api\MatchControllerIntegrationTest.java.bak" -ErrorAction SilentlyContinue

# Then start the app
.\mvnw.cmd spring-boot:run
```

## Alternative: skip tests with PowerShell syntax

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
$env:MAVEN_OPTS="-DskipTests"; .\mvnw.cmd spring-boot:run
```

Or:

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run "-DskipTests=true"
```
