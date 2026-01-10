# API Testing Guide

## 快速开始

### 一键运行 E2E 测试

在 PowerShell 中执行：

```powershell
.\requests\e2e_smoke.ps1
```

或指定自定义 Base URL：

```powershell
.\requests\e2e_smoke.ps1 -BaseUrl "http://localhost:18080"
```

## 测试流程

E2E 脚本会自动执行以下步骤：

1. **检查/启动 Docker Compose**
   - 检查 PostgreSQL 容器是否运行
   - 如果未运行，尝试启动 `talent-archive-core/docker-compose.yml` 中的 postgres 服务

2. **启动 Spring Boot 应用**
   - 检查应用是否已在运行（通过 health endpoint）
   - 如果未运行，使用 `mvnw spring-boot:run` 启动应用
   - 等待应用就绪（最多 60 秒）

3. **健康检查**
   - GET `/api/extract/health`
   - 验证提取服务可用性

4. **简历入库（Golden Path Step 1）**
   - POST `/api/resumes`
   - 读取 `samples/resume_001.txt`
   - 验证返回 documentId

5. **实体提取（Golden Path Step 2）**
   - POST `/api/extract`
   - 使用上一步得到的 documentId
   - 注意：如果 extract-service (Python) 未运行，此步骤会警告但不失败

6. **匹配查询（Golden Path Step 3）**
   - POST `/api/match`
   - 使用第一步得到的 documentId
   - 注意：如果没有成功画像数据，此步骤会警告但不失败

## 输出说明

### 成功输出示例

```
========================================
  E2E Smoke Test - Resume Blueprint API
========================================
Base URL: http://localhost:18080

[10:30:15] [INFO] Checking Docker Compose...
[10:30:16] [PASS] PostgreSQL container is running
[10:30:16] [INFO] Starting Spring Boot application...
[10:30:17] [PASS] Application appears to be already running
[10:30:17] [INFO] Testing health endpoint...
[10:30:17] [INFO]   Request: GET http://localhost:18080/api/extract/health
[10:30:17] [INFO]   Status: 200
[10:30:17] [PASS] Health check passed
[10:30:17] [INFO] Testing resume ingestion...
[10:30:18] [PASS] Resume ingested successfully. Document ID: 1
[10:30:18] [INFO] Testing extract service...
[10:30:19] [PASS] Extract completed successfully
[10:30:20] [INFO] Testing match service...
[10:30:21] [PASS] Match completed successfully

========================================
  Test Results Summary
========================================
  [PASS] Health Check
  [PASS] Resume Ingestion
  [PASS] Extract Service
  [PASS] Match Service

========================================
  RESULT: PASS
========================================
```

### 失败输出示例

```
[10:30:17] [FAIL] Health check failed
  Error: Unable to connect to remote server

========================================
  RESULT: FAIL
========================================
```

Exit Code:
- `0` = 所有关键测试通过
- `1` = 关键测试失败（健康检查或简历入库失败）

## 常见问题排查

### 1. 端口冲突问题

**问题：** 应用配置使用端口 `55433` 连接数据库，但 docker-compose 映射的是 `55434`

**解决方案：**

#### 方案 A：修改 docker-compose.yml（推荐）

编辑 `talent-archive-core/docker-compose.yml`：

```yaml
services:
  postgres:
    ports:
      - "55433:5432"  # 改为 55433
```

然后重启容器：
```powershell
cd talent-archive-core
docker-compose down
docker-compose up -d postgres
```

#### 方案 B：修改应用配置

编辑 `resume-blueprint/resume-blueprint-api/src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://127.0.0.1:55434/talent_archive  # 改为 55434
```

**注意：** 根据约束，不允许修改生产代码。如果必须修改，请仅修改测试环境的配置。

### 2. 数据库名称/用户不匹配

**问题：** 应用配置使用的数据库名/用户与 docker-compose 不一致

应用配置：
- 数据库：`talent_archive`
- 用户：`archive_user`
- 密码：`archive_pass`

Docker Compose：
- 数据库：`resume_blueprint_db`
- 用户：`rb_user`
- 密码：`rb_password`

**解决方案：** 需要手动创建数据库或修改 docker-compose 环境变量，使其与应用配置匹配。

### 3. 应用启动失败

**检查清单：**
- [ ] Java 21+ 已安装：`java -version`
- [ ] Maven wrapper 存在：`resume-blueprint/resume-blueprint-api/mvnw.cmd`
- [ ] 端口 18080 未被占用：`netstat -ano | findstr :18080`
- [ ] 数据库连接正常：检查数据库是否运行并可连接

**查看日志：**
```powershell
cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

### 4. Extract Service 不可用

**现象：** Extract 测试显示警告 "Extraction service is unavailable"

**原因：** Python extract-service 未启动

**解决方案：**
```powershell
cd talent-archive-core
docker-compose up -d extract-service
```

等待服务启动（约 40 秒），然后验证：
```powershell
Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing
```

### 5. Match 返回空结果

**现象：** Match 测试通过但返回空的 matches 列表

**原因：** 数据库中没有成功画像（Success Profiles）数据

**解决方案：** 这是正常的。可以通过以下 API 导入测试数据：
```powershell
$body = @{
    source = "internal_employee"
    role = "Java Backend Engineer"
    level = "mid"
    company = "Test Corp"
    text = "Backend engineer with Java/Spring experience..."
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:18080/api/success-profiles/import" `
    -Method POST -Body $body -ContentType "application/json"
```

## 使用 HTTP Client 文件

`api.http` 文件适用于 VS Code REST Client 插件或 IntelliJ HTTP Client。

### VS Code
1. 安装 "REST Client" 扩展
2. 打开 `requests/api.http`
3. 设置环境变量 `baseUrl = http://localhost:18080`
4. 点击请求上方的 "Send Request"

### IntelliJ IDEA
1. 打开 `requests/api.http`
2. 点击请求左侧的运行按钮

## 日志查看

### Spring Boot 应用日志
如果应用在前台运行，日志会直接输出到控制台。

如果在后台运行，日志通常位于：
- Windows: 查看启动的 PowerShell 窗口
- 或重定向到文件：`.\mvnw.cmd spring-boot:run > app.log 2>&1`

### Docker 容器日志
```powershell
# PostgreSQL 日志
docker logs resume_blueprint_postgres

# Extract Service 日志
docker logs resume_blueprint_extract
```

## 性能测试

对于性能测试，可以多次调用 API：

```powershell
$resumeText = Get-Content "samples\resume_001.txt" -Raw
$body = @{ candidateId = "perf_test_001"; text = $resumeText } | ConvertTo-Json

Measure-Command {
    1..10 | ForEach-Object {
        Invoke-WebRequest -Uri "http://localhost:18080/api/resumes" `
            -Method POST -Body $body -ContentType "application/json" | Out-Null
    }
}
```

## 下一步

- 查看 `docs/TESTING.md` 了解详细的测试验收标准
- 运行 JUnit 集成测试：`.\resume-blueprint\resume-blueprint-api\mvnw.cmd test`
- 查看 API 文档（如果有 Swagger，通常位于 `/swagger-ui.html` 或 `/v3/api-docs`）
