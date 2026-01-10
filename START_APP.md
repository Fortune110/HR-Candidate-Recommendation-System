# 启动应用说明

## ✅ Java 21 已正确安装

验证结果：
- Java 版本: 21.0.8 ✅
- javac 编译器: 可用 ✅
- Maven 已识别 Java 21 ✅

---

## 🚀 启动应用（请在前台运行以查看日志）

**重要：** 请在 PowerShell 中手动运行以下命令，不要关闭窗口，这样可以看到启动日志和任何错误：

```powershell
# 1. 进入后端目录
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api

# 2. 启动应用（保持窗口打开）
.\mvnw.cmd spring-boot:run
```

**首次启动可能需要 1-2 分钟**（下载依赖、编译代码等）。

---

## 📋 启动过程中你应该看到：

### ✅ 成功启动的标志：

```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v4.0.1)

...（Flyway 迁移日志）...

Started ResumeBlueprintApiApplication in X.XXX seconds
```

### ❌ 如果看到错误：

**数据库连接错误：**
```
org.postgresql.util.PSQLException: Connection refused
```
→ 检查数据库容器是否运行：`docker compose ps` (在 talent-archive-core 目录)

**端口被占用：**
```
Web server failed to start. Port 18080 was already in use.
```
→ 检查端口占用：`netstat -ano | findstr :18080`

**Flyway 迁移失败：**
```
FlywayException: ...
```
→ 检查数据库配置是否正确（应该是 55434 / resume_blueprint_db / rb_user）

---

## 🔍 启动成功后验证

**在新开一个 PowerShell 窗口**，执行：

```powershell
# 健康检查
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
```

**应该返回：**
```
StatusCode        : 200
Content           : {"runId":0,"message":"Extraction service is available"}
```

---

## 🧪 然后运行 E2E 测试

```powershell
cd C:\HR-Candidate-Recommendation-System
.\requests\e2e_smoke.ps1
```

---

## 💡 提示

- **首次启动较慢**：Maven 需要下载依赖、编译代码，可能需要 1-2 分钟
- **保持窗口打开**：启动日志会显示在这个窗口中
- **如果有错误**：把错误信息复制给我，我可以帮你排查
