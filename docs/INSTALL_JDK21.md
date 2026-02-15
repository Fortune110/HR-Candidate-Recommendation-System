# Install JDK 21 (Windows)

## Why
The project requires **Java 21 JDK**. If you only have a JRE, builds fail with:
```
No compiler is provided in this environment. Perhaps you are running on a JRE rather than a JDK?
```

## Option 1: Eclipse Temurin (recommended)
1. Download: https://adoptium.net/temurin/releases/?version=21  
   - Version: 21 (LTS)
   - OS: Windows
   - Architecture: x64
   - Package: JDK (not JRE)
2. Run the MSI installer
   - Enable **Add to PATH**
   - Enable **Set JAVA_HOME**
3. Verify in a new PowerShell window:
```powershell
java -version
where.exe javac
```

## Option 2: Microsoft OpenJDK
```powershell
winget install Microsoft.OpenJDK.21
```
Then set `JAVA_HOME` to the install path and add `%JAVA_HOME%\bin` to `Path`.

## Verify Maven uses JDK 21
```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd -version
```
You should see `Java version: 21.x` in the output.
