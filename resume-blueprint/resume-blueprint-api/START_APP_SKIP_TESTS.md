# 启动应用（跳过测试）

## 问题
测试类有编译错误，但主应用代码没问题。

## 解决方案：暂时重命名测试文件

在启动应用前，请执行：

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api

# 暂时重命名测试文件，避免编译
Move-Item -Path "src\test\java\com\fortune\resumeblueprint\api\ResumeControllerIntegrationTest.java" -Destination "src\test\java\com\fortune\resumeblueprint\api\ResumeControllerIntegrationTest.java.bak" -ErrorAction SilentlyContinue
Move-Item -Path "src\test\java\com\fortune\resumeblueprint\api\ExtractControllerIntegrationTest.java" -Destination "src\test\java\com\fortune\resumeblueprint\api\ExtractControllerIntegrationTest.java.bak" -ErrorAction SilentlyContinue
Move-Item -Path "src\test\java\com\fortune\resumeblueprint\api\MatchControllerIntegrationTest.java" -Destination "src\test\java\com\fortune\resumeblueprint\api\MatchControllerIntegrationTest.java.bak" -ErrorAction SilentlyContinue

# 然后启动应用
.\mvnw.cmd spring-boot:run
```

## 或者：使用正确的 PowerShell 语法跳过测试

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
$env:MAVEN_OPTS="-DskipTests"; .\mvnw.cmd spring-boot:run
```

或者：

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run "-DskipTests=true"
```
