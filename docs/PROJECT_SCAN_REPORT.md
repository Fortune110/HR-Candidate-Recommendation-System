# 项目扫描报告

## 项目概况

**项目名称：** HR Candidate Recommendation System  
**主要技术栈：** Spring Boot 4.0.1, Java 21, PostgreSQL 16, Python (Flask)  
**扫描时间：** 2024-01-01

---

## 1. Spring Boot 应用配置

### 启动方式
- **Maven Wrapper:** `mvnw.cmd` (Windows) / `mvnw` (Unix)
- **主类:** `com.fortune.resumeblueprint.ResumeBlueprintApiApplication`
- **启动命令:**
  ```powershell
  cd resume-blueprint\resume-blueprint-api
  .\mvnw.cmd spring-boot:run
  ```
  或
  ```powershell
  .\mvnw.cmd clean package
  java -jar target\resume-blueprint-api-0.0.1-SNAPSHOT.jar
  ```

### 应用端口
- **主端口:** `18080` (配置在 `application.yml`)
- **配置文件:** `resume-blueprint/resume-blueprint-api/src/main/resources/application.yml`

### 数据库配置
- **JDBC URL:** `jdbc:postgresql://127.0.0.1:55433/talent_archive`
- **用户名:** `archive_user`
- **密码:** `archive_pass`
- **数据库名:** `talent_archive`
- **端口:** `55433` ⚠️ **注意：与 docker-compose 不匹配**

### Flyway 迁移
- **启用:** 是
- **迁移脚本位置:** `classpath:db/migration`
- **迁移文件:**
  - `V1__blueprint_core.sql`
  - `V1__rb_core.sql`
  - `V2__baseline.sql`
  - `V2__rb_baseline.sql`
- `V3__rb_review.sql`
  - `V4__success_profile_and_match.sql`

---

## 2. Docker Compose 配置

### 文件位置
- `talent-archive-core/docker-compose.yml`

### PostgreSQL 服务
- **容器名:** `resume_blueprint_postgres`
- **镜像:** `postgres:16`
- **端口映射:** `55434:5432` ⚠️ **注意：应用配置使用 55433**
- **数据库名:** `resume_blueprint_db` ⚠️ **注意：应用配置使用 talent_archive**
- **用户名:** `rb_user` ⚠️ **注意：应用配置使用 archive_user**
- **密码:** `rb_password` ⚠️ **注意：应用配置使用 archive_pass**
- **数据卷:** `rb_pgdata`

### Extract Service (Python)
- **容器名:** `resume_blueprint_extract`
- **端口映射:** `5000:5000`
- **健康检查:** `GET http://localhost:5000/health`
- **构建上下文:** `./extract-service`

### 启动命令
```powershell
cd talent-archive-core
docker-compose up -d postgres
docker-compose up -d extract-service
```

---

## 3. API 端点清单

### 3.1 Resume Controller
**Base Path:** `/api/resumes`

| Method | Path | 用途 | 请求体 | 响应 |
|--------|------|------|--------|------|
| POST | `/api/resumes` | 简历入库 | `ResumeIngestRequest` | `ResumeIngestResponse` (documentId) |
| POST | `/api/resumes/{documentId}/analyze/bootstrap` | Bootstrap 分析 | `AnalyzeRequest` | `AnalyzeResponse` |
| POST | `/api/resumes/{documentId}/analyze/baseline` | Baseline 分析 | `AnalyzeRequest` + `baselineSetId` param | `AnalyzeResponse` |

### 3.2 Extract Controller
**Base Path:** `/api/extract`

| Method | Path | 用途 | 请求体 | 响应 |
|--------|------|------|--------|------|
| POST | `/api/extract` | 实体提取 | `ExtractRequest` | `ExtractResponse` (runId, message) |
| GET | `/api/extract/health` | 健康检查 | - | `ExtractResponse` (runId: 0, message) |

### 3.3 Match Controller
**Base Path:** `/api/match`

| Method | Path | 用途 | 请求体 | 响应 |
|--------|------|------|--------|------|
| POST | `/api/match` | 匹配查询 | `MatchRequest` | `MatchResponse` (matchRunId, matches[]) |

### 3.4 Baseline Controller
**Base Path:** `/api/baseline`

| Method | Path | 用途 | 请求参数 | 响应 |
|--------|------|------|----------|------|
| POST | `/api/baseline/build` | 构建基线 | `lastN=50`, `minCount=2` | `BaselineBuildResponse` |

### 3.5 Success Profile Controller
**Base Path:** `/api/success-profiles`

| Method | Path | 用途 | 请求体 | 响应 |
|--------|------|------|--------|------|
| POST | `/api/success-profiles/import` | 导入成功画像 | `ImportProfileRequest` | `ImportProfileResponse` (profileId, message) |

---

## 4. Swagger/OpenAPI 状态

**状态:** ❌ **未启用**

- 未发现 `springdoc-openapi` 或 `springfox` 依赖
- 未发现 Swagger 配置类
- 未发现 `/swagger-ui.html` 或 `/v3/api-docs` 端点

---

## 5. Actuator 状态

**状态:** ❌ **未启用**

- 未发现 `spring-boot-starter-actuator` 依赖
- 未发现 `/actuator/health` 端点
- **替代方案:** 使用 `/api/extract/health` 作为健康检查端点

---

## 6. 查询接口状态

**状态:** ⚠️ **缺少 GET 查询接口**

### 发现的问题
- 所有 Controller 只提供 POST 方法
- 没有 `GET /api/resumes/{documentId}` 查询接口
- 没有 `GET /api/resumes` 列表接口
- 没有 `GET /api/match/{matchRunId}` 查询匹配结果接口

### 影响
- 无法通过 GET 接口验证写入的数据
- 闭环测试需要通过后续操作（extract/match）来间接验证写入成功

### 建议的测试策略
1. **写入验证：** 通过后续 API（extract/match）使用 documentId 来验证写入成功
2. **数据验证：** 通过数据库直接查询（在集成测试中）
3. **Golden Path：** ingest -> extract -> match 形成完整流程验证

---

## 7. Golden Path（黄金路径）推荐

基于现有 API，推荐以下测试流程：

### 路径 1: 简历处理流程
1. **POST /api/resumes** → 获得 `documentId`
2. **POST /api/extract** → 使用 `documentId` 提取实体 → 获得 `runId`
3. **POST /api/match** → 使用 `documentId` 进行匹配 → 获得 `matchRunId` 和 `matches[]`

### 路径 2: 成功画像匹配流程（需要预先导入数据）
1. **POST /api/success-profiles/import** → 导入成功画像 → 获得 `profileId`
2. **POST /api/resumes** → 导入简历 → 获得 `documentId`
3. **POST /api/match** → 匹配 → 验证 matches 数组非空

### 路径 3: Baseline 构建流程
1. **POST /api/baseline/build** → 构建基线 → 获得 `baselineSetId`
2. **POST /api/resumes/{documentId}/analyze/baseline?baselineSetId={baselineSetId}** → 使用基线分析

---

## 8. 测试数据文件

### 已创建的测试数据
- `samples/resume_001.txt` - 标准测试简历（Alex Chen）
- `samples/jd_001.txt` - 标准测试职位描述

---

## 9. 已知配置问题

### 问题 1: 数据库端口不匹配
- **应用配置:** `55433`
- **Docker Compose:** `55434`
- **解决方案:** 见 `requests/README.md` 第 1 节

### 问题 2: 数据库名/用户不匹配
- **应用配置:** `talent_archive` / `archive_user` / `archive_pass`
- **Docker Compose:** `resume_blueprint_db` / `rb_user` / `rb_password`
- **影响:** 应用无法连接到 Docker 数据库
- **解决方案:** 需要手动创建数据库或修改 docker-compose

### 问题 3: 缺少查询接口
- **影响:** 无法直接验证写入的数据
- **解决方案:** 通过后续 API 间接验证

---

## 10. 依赖服务

### Extract Service (Python)
- **状态:** 可选（extract API 会检查可用性）
- **健康检查:** `GET http://localhost:5000/health`
- **如果不可用:** Extract API 返回警告，但不影响其他功能

### OpenAI API
- **配置:** 通过环境变量 `OPENAI_API_KEY`
- **模型:** `gpt-4o-mini` (默认，可通过 `OPENAI_MODEL` 覆盖)
- **用途:** Analyze API (bootstrap/baseline)

---

## 11. 测试框架状态

### JUnit 5
- **状态:** ✅ 已配置
- **测试依赖:**
  - `spring-boot-starter-webmvc-test`
  - `spring-boot-starter-validation-test`
  - `spring-boot-starter-flyway-test`

### Testcontainers
- **状态:** ❌ 未配置
- **原因:** 未发现相关依赖，且未强制引入

### MockMvc
- **状态:** ✅ 可用（通过 `@AutoConfigureMockMvc`）

---

## 12. 总结

### 优势
- ✅ API 结构清晰，职责分明
- ✅ 使用了 Flyway 进行数据库版本管理
- ✅ 有健康检查端点（/api/extract/health）
- ✅ 测试框架已配置

### 待改进
- ⚠️ 缺少 GET 查询接口
- ⚠️ 数据库配置与 docker-compose 不匹配
- ⚠️ 未启用 Swagger/OpenAPI 文档
- ⚠️ 未启用 Actuator 监控

### 测试建议
1. 优先使用 Golden Path 1 进行 E2E 测试
2. 对于集成测试，需要确保数据库可访问
3. Extract Service 不可用时，相关测试标记为 WARN 而非 FAIL

---

**报告生成时间:** 2024-01-01  
**扫描工具:** 手动代码审查 + 自动化扫描
