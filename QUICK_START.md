# 快速启动指南

## 当前状态 ✅

- ✅ PostgreSQL 数据库：运行中（端口 55434）
- ✅ Extract Service (Python)：运行中（端口 5000）
- ⚠️ 后端应用：未启动（需要手动启动）

---

## 启动步骤

### 步骤 1: 启动后端应用

**打开一个新的 PowerShell 窗口**，执行：

```powershell
# 进入项目根目录
cd C:\HR-Candidate-Recommendation-System

# 进入后端目录
cd resume-blueprint\resume-blueprint-api

# 启动应用（这会占用当前窗口，显示日志）
.\mvnw.cmd spring-boot:run
```

**等待看到：**
```
Started ResumeBlueprintApiApplication in X.XXX seconds
```

**如果看到数据库连接错误：**
- 检查 application.yml 中的数据库配置是否正确（应该是 55434 / resume_blueprint_db / rb_user）
- 确认数据库容器正在运行：`docker compose ps` (在 talent-archive-core 目录)

---

### 步骤 2: 验证应用启动（在新窗口或原窗口）

**打开另一个 PowerShell 窗口**，执行：

```powershell
# 健康检查
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
```

**预期输出：**
```
StatusCode        : 200
Content           : {"runId":0,"message":"Extraction service is available"}
```

---

### 步骤 3: 运行 E2E 测试

```powershell
# 回到项目根目录
cd C:\HR-Candidate-Recommendation-System

# 运行 E2E 测试
.\requests\e2e_smoke.ps1
```

**预期输出：**
```
========================================
  E2E Smoke Test - Resume Blueprint API
========================================
[PASS] Health Check
[PASS] Resume Ingestion
[PASS] Extract Service
[PASS] Match Service

========================================
  RESULT: PASS
========================================
```

---

## 一键命令（如果你想让它在后台运行）

如果你想在后台启动后端应用（不占用窗口），使用：

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\mvnw.cmd spring-boot:run"
```

这会打开一个新窗口运行应用，你可以继续在当前窗口执行其他命令。

---

## 故障排查

### 问题：后端启动失败，提示数据库连接错误

**检查：**
1. 数据库容器是否运行：
   ```powershell
   cd C:\HR-Candidate-Recommendation-System\talent-archive-core
   docker compose ps
   ```

2. 数据库配置是否正确：
   ```powershell
   type C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api\src\main\resources\application.yml
   ```
   应该看到：
   ```yaml
   url: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db
   username: rb_user
   password: rb_password
   ```

3. 手动测试数据库连接：
   ```powershell
   cd C:\HR-Candidate-Recommendation-System\talent-archive-core
   docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;"
   ```

### 问题：端口 18080 被占用

**检查：**
```powershell
netstat -ano | findstr :18080
```

**解决：**
- 找到占用端口的进程 PID（最后一列）
- 结束进程：`taskkill /PID <PID> /F`
- 或者修改 application.yml 中的端口

---

## 总结

**最简单的启动方式（3个窗口）：**

1. **窗口1 - 后端应用（保持运行）：**
   ```powershell
   cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
   .\mvnw.cmd spring-boot:run
   ```

2. **窗口2 - 等待20秒后验证：**
   ```powershell
   Start-Sleep -Seconds 20
   Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
   ```

3. **窗口3 - 运行测试：**
   ```powershell
   cd C:\HR-Candidate-Recommendation-System
   .\requests\e2e_smoke.ps1
   ```
