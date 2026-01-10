# 安装 JDK 21 指南

## 问题说明

当前环境只有 Java 8 JRE，但项目需要 **Java 21 JDK**。

**错误信息：**
```
No compiler is provided in this environment. Perhaps you are running on a JRE rather than a JDK?
```

---

## 解决方案

### 方法 1: 使用 Adoptium Eclipse Temurin（推荐）

#### 步骤 1: 下载 JDK 21

访问：https://adoptium.net/temurin/releases/?version=21

选择：
- **Version:** 21 (LTS)
- **Operating System:** Windows
- **Architecture:** x64
- **Package Type:** JDK
- **Image Type:** jdk (not jre)

下载文件：例如 `OpenJDK21U-jdk_x64_windows_hotspot_21.0.x_x64.msi`

#### 步骤 2: 安装

1. 运行下载的 `.msi` 文件
2. 安装向导中：
   - ✅ 勾选 "Add to PATH"
   - ✅ 勾选 "Set JAVA_HOME variable"
   - 安装路径使用默认：`C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot\`

#### 步骤 3: 验证安装

**打开新的 PowerShell 窗口**（重要！需要重新加载环境变量），执行：

```powershell
java -version
```

**应该看到：**
```
openjdk version "21.0.x" ...
```

**检查是否是 JDK：**
```powershell
where.exe javac
```

**如果显示 javac 路径（如 `C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot\bin\javac.exe`），说明安装成功！**

---

### 方法 2: 使用 Microsoft OpenJDK（Windows 官方版本）

#### 步骤 1: 使用 winget 安装（最简单）

```powershell
winget install Microsoft.OpenJDK.21
```

#### 步骤 2: 配置环境变量

安装后，JDK 通常在：`C:\Program Files\Microsoft\jdk-21.x.x\`

**手动设置环境变量：**

1. 右键"此电脑" → "属性" → "高级系统设置" → "环境变量"
2. 在"系统变量"中：
   - 新建或编辑 `JAVA_HOME`：`C:\Program Files\Microsoft\jdk-21.x.x`
   - 编辑 `Path`：添加 `%JAVA_HOME%\bin`

#### 步骤 3: 验证

打开新的 PowerShell 窗口：
```powershell
java -version
javac -version
```

---

### 方法 3: 使用 Chocolatey（如果你有安装）

```powershell
choco install openjdk21
```

---

## 安装后验证

### 1. 检查 Java 版本

```powershell
java -version
```

**应该显示：**
```
openjdk version "21.0.x" ...
```

### 2. 检查是否有 javac（编译器）

```powershell
javac -version
```

**应该显示：**
```
javac 21.0.x
```

如果没有 `javac`，说明安装的是 JRE 而不是 JDK，需要重新下载 JDK 版本。

### 3. 检查 JAVA_HOME

```powershell
$env:JAVA_HOME
```

**应该显示 JDK 安装路径：**
```
C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot
```

如果没有设置，手动设置（见下方"手动配置环境变量"）。

---

## 手动配置环境变量（如果自动配置失败）

### Windows 10/11:

1. 按 `Win + R`，输入 `sysdm.cpl`，回车
2. 点击"高级"标签 → "环境变量"
3. 在"系统变量"区域：
   - 点击"新建" → 变量名：`JAVA_HOME`，变量值：`C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot`（替换为你的实际路径）
   - 找到 `Path` 变量 → 编辑 → 新建 → 添加：`%JAVA_HOME%\bin`

4. 点击"确定"保存

5. **重要：关闭并重新打开 PowerShell 窗口**，环境变量才会生效

---

## 验证 Maven 能找到 JDK

安装 JDK 21 后，在新窗口执行：

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api

# 检查 Maven 使用的 Java
.\mvnw.cmd -version
```

**应该显示：**
```
Apache Maven 3.x.x
Maven home: ...
Java version: 21.0.x, vendor: Eclipse Adoptium
Java home: C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot
```

---

## 如果多个 Java 版本共存

如果系统有多个 Java 版本，需要确保：

1. `JAVA_HOME` 指向 JDK 21
2. `Path` 中 `%JAVA_HOME%\bin` 在最前面

**检查当前使用的 Java：**
```powershell
where.exe java
javac -version
```

**临时切换 Java 版本（如果需要）：**
```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

---

## 安装完成后重新启动应用

```powershell
# 在新的 PowerShell 窗口
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

---

## 常见问题

### Q: 安装后 `java -version` 还是显示 Java 8？

**A:** 
1. 关闭并重新打开 PowerShell 窗口
2. 检查 `Path` 环境变量中，JDK 21 的路径是否在 Java 8 路径之前
3. 使用 `where.exe java` 查看使用的是哪个 java

### Q: `javac` 命令找不到？

**A:** 说明安装的是 JRE 而不是 JDK。请重新下载 JDK 版本（不是 JRE）。

### Q: Maven 还是报错找不到编译器？

**A:** 
1. 检查 `JAVA_HOME` 是否指向 JDK（不是 JRE）
2. 重启 PowerShell 窗口
3. 运行 `.\mvnw.cmd -version` 确认 Maven 使用的 Java 版本

---

**推荐下载地址：**
- Eclipse Adoptium: https://adoptium.net/temurin/releases/?version=21
- Microsoft OpenJDK: https://learn.microsoft.com/en-us/java/openjdk/download#openjdk-21
