# Installing JDK 21

## Problem

The project requires **Java 21 JDK**. If you see:
```
No compiler is provided in this environment. Perhaps you are running on a JRE rather than a JDK?
```
you need to install JDK 21.

---

## macOS (Recommended)

### Option 1 — Homebrew

```bash
brew install --cask temurin@21
```

Verify:
```bash
java -version
# openjdk version "21.x.x" ...
javac -version
# javac 21.x.x
```

### Option 2 — Manual Download

1. Go to: https://adoptium.net/temurin/releases/?version=21
2. Select: macOS, x64 (or aarch64 for Apple Silicon), JDK package
3. Download and run the `.pkg` installer
4. Open a new terminal and verify with `java -version`

---

## Windows

1. Go to: https://adoptium.net/temurin/releases/?version=21
2. Select: Windows, x64, JDK, `.msi` package
3. During installation, check:
   - "Add to PATH"
   - "Set JAVA_HOME variable"
4. Open a new PowerShell window and verify:
   ```powershell
   java -version
   javac -version
   ```

---

## Set JAVA_HOME manually (if needed)

**macOS/Linux:**
```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH=$JAVA_HOME/bin:$PATH
```

Add to `~/.zshrc` or `~/.bashrc` to persist.

**Windows (PowerShell):**
```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

---

## Verify Maven Uses JDK 21

```bash
cd resume-blueprint/resume-blueprint-api
./mvnw --version
# Should show: Java version: 21
```
