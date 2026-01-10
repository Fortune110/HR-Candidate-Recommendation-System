# 测试验收标准文档

## 概述

本文档定义了 HR Candidate Recommendation System 的测试验收标准，包括 Smoke Test、API Test 和 E2E Test 的详细要求。

## 测试类型

### 1. Smoke Test（冒烟测试）

**目标：** 验证系统基本功能可用，能够快速发现阻塞性问题。

**验收标准：**
- ✅ 服务能够启动
- ✅ 健康检查端点返回 200 OK
- ✅ 数据库连接正常
- ✅ 至少一个核心 API 能够正常响应

**执行方式：**
```powershell
.\requests\e2e_smoke.ps1
```

**通过条件：**
- Health Check: PASS
- Resume Ingestion: PASS

### 2. API Test（API 测试）

**目标：** 验证所有 API 端点的正确性和响应格式。

#### 2.1 Health Check API

**Endpoint:** `GET /api/extract/health`

**验收标准：**
- HTTP 状态码：200
- 响应体必须包含：
  - `runId` (number, 可以为 0)
  - `message` (string, 非空)

**示例响应：**
```json
{
  "runId": 0,
  "message": "Extraction service is available"
}
```

#### 2.2 Resume Ingestion API

**Endpoint:** `POST /api/resumes`

**请求体要求：**
```json
{
  "candidateId": "string (required, non-blank)",
  "text": "string (required, non-blank)"
}
```

**验收标准：**
- HTTP 状态码：201 Created 或 200 OK
- 响应体必须包含：
  - `documentId` (number, > 0)
- 验证：相同 candidateId 和 text 的重复请求应返回相同的 documentId（基于 content_hash）

**示例响应：**
```json
{
  "documentId": 1
}
```

**失败场景：**
- 400 Bad Request: candidateId 或 text 为空
- 500 Internal Server Error: 数据库连接失败或其他服务器错误

#### 2.3 Extract API

**Endpoint:** `POST /api/extract`

**请求体要求：**
```json
{
  "documentId": "number (required)",
  "text": "string (required, non-blank)",
  "docType": "string (optional, 'RESUME' | 'JD')"
}
```

**验收标准：**
- HTTP 状态码：200 OK
- 响应体必须包含：
  - `runId` (number, > 0)
  - `message` (string, 非空)
- 如果 extract-service (Python) 不可用，应返回合理的错误信息（不一定是 500，取决于实现）

**示例响应：**
```json
{
  "runId": 1,
  "message": "Extraction completed successfully"
}
```

**注意：** 此 API 依赖外部 Python 服务，如果服务不可用，测试标记为 WARN 而非 FAIL。

#### 2.4 Match API

**Endpoint:** `POST /api/match`

**请求体要求：**
```json
{
  "resumeDocumentId": "number (required)",
  "target": "string (optional, 'internal' | 'external' | 'both', default: 'both')",
  "roleFilter": "string (optional)",
  "levelFilter": "string (optional, 'junior' | 'mid' | 'senior')"
}
```

**验收标准：**
- HTTP 状态码：200 OK
- 响应体必须包含：
  - `matchRunId` (number, > 0)
  - `matches` (array)
    - 每个 match 对象必须包含：
      - `source` (string, 'internal_employee' | 'external_success')
      - `score` (number)
      - `overlapScore` (number)
      - `gapPenalty` (number)
      - `bonusScore` (number)
      - `topOverlaps` (array, 可以为空)
      - `topGaps` (array, 可以为空)
      - `topStrengths` (array, 可以为空)

**示例响应：**
```json
{
  "matchRunId": 1,
  "matches": [
    {
      "source": "internal_employee",
      "score": 0.85,
      "overlapScore": 0.90,
      "gapPenalty": 0.05,
      "bonusScore": 0.0,
      "topOverlaps": [
        {
          "canonical": "skill/java",
          "weight": 1.0,
          "reason": "Required skill match"
        }
      ],
      "topGaps": [],
      "topStrengths": []
    }
  ]
}
```

**注意：** 如果没有成功画像数据，matches 数组可以为空，这不算失败。

#### 2.5 Baseline Build API

**Endpoint:** `POST /api/baseline/build?lastN=50&minCount=2`

**验收标准：**
- HTTP 状态码：200 OK
- 响应体必须包含：
  - `baselineSetId` (number, > 0)
  - `createdTerms` (number, >= 0)

#### 2.6 Success Profile Import API

**Endpoint:** `POST /api/success-profiles/import`

**请求体要求：**
```json
{
  "source": "string (required, 'internal_employee' | 'external_success')",
  "role": "string (required)",
  "level": "string (optional)",
  "company": "string (optional)",
  "text": "string (required, non-blank)"
}
```

**验收标准：**
- HTTP 状态码：200 OK 或 201 Created
- 响应体必须包含：
  - `profileId` (number, > 0)
  - `message` (string, 非空)

### 3. E2E Test（端到端测试）

**目标：** 验证完整业务流程能够正常运行。

#### Golden Path（黄金路径）

以下流程必须能够完整执行：

1. **简历入库**
   - 输入：`samples/resume_001.txt`
   - 输出：`documentId`
   - 验证：返回有效的 documentId

2. **实体提取**
   - 输入：第一步得到的 `documentId` + 简历文本
   - 输出：`runId`
   - 验证：提取操作完成（即使 extract-service 不可用，也不应导致整个流程失败）

3. **匹配查询**
   - 输入：第一步得到的 `documentId`
   - 输出：匹配结果（可以为空数组）
   - 验证：返回有效的 MatchResponse 结构

**验收标准：**
- 所有步骤的 HTTP 状态码正确
- 响应体格式符合 API 规范
- 数据能够正确流转（documentId 可以被后续步骤使用）

**执行方式：**
```powershell
.\requests\e2e_smoke.ps1
```

**通过条件：**
- Resume Ingestion: PASS（关键）
- Extract: PASS 或 WARN（非关键）
- Match: PASS 或 WARN（非关键，取决于是否有测试数据）

### 4. 集成测试（JUnit）

**目标：** 在隔离的测试环境中验证服务层和 API 层的集成。

**测试覆盖：**

#### 4.1 ResumeServiceTest
- `testIngestResume()` - 验证简历入库
- `testIngestResumeDuplicate()` - 验证重复内容处理

#### 4.2 ExtractServiceTest
- `testExtractWithValidDocumentId()` - 验证提取功能
- `testExtractServiceHealth()` - 验证健康检查

#### 4.3 MatchServiceTest
- `testMatchWithValidResume()` - 验证匹配功能
- `testMatchWithEmptyProfiles()` - 验证空结果处理

**执行方式：**
```powershell
cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd test
```

**验收标准：**
- 所有测试用例通过
- 测试覆盖率 >= 60%（理想情况下）

## 性能验收标准

### 响应时间要求

- Health Check: < 100ms
- Resume Ingestion: < 1s
- Extract: < 5s（取决于文本长度和 extract-service 性能）
- Match: < 3s（取决于成功画像数量）

### 并发要求

- 支持至少 10 个并发请求
- 无内存泄漏（长期运行测试）

## 数据验证

### 必填字段验证

所有 API 的必填字段必须：
- 进行非空验证
- 返回明确的错误信息（400 Bad Request）
- 错误响应体应包含字段名和错误原因

### 数据类型验证

- `documentId`, `runId`, `matchRunId` 等 ID 字段必须是正整数
- `score`, `weight` 等数值字段必须在合理范围内
- `text` 字段应支持 UTF-8 编码

## 错误处理验收标准

### HTTP 状态码规范

- `200 OK`: 成功操作
- `201 Created`: 资源创建成功
- `400 Bad Request`: 请求参数错误
- `404 Not Found`: 资源不存在
- `500 Internal Server Error`: 服务器内部错误
- `503 Service Unavailable`: 依赖服务不可用（如 extract-service）

### 错误响应格式

所有错误响应应包含：
- HTTP 状态码
- 错误消息（可选，但推荐）
- 错误详情（开发环境，可选）

**示例：**
```json
{
  "timestamp": "2024-01-01T10:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "candidateId must not be blank",
  "path": "/api/resumes"
}
```

## 环境要求

### 开发环境

- Java 21+
- Maven 3.6+
- Docker Desktop (Windows)
- PostgreSQL 16 (通过 Docker)
- Python 3.11+ (用于 extract-service)

### 测试数据

- `samples/resume_001.txt` - 标准测试简历
- `samples/jd_001.txt` - 标准测试职位描述

## 持续集成

### CI/CD 验收标准

- 所有 Smoke Tests 通过
- 所有 JUnit 测试通过
- 代码覆盖率报告生成
- 无严重代码质量问题（SonarQube 等）

### 部署前检查清单

- [ ] Smoke Test PASS
- [ ] 所有 API 测试通过
- [ ] 数据库迁移脚本验证通过
- [ ] 环境变量配置正确
- [ ] 依赖服务（extract-service）可用性确认

## 测试报告

### 必须包含的信息

1. 测试执行时间
2. 测试通过/失败数量
3. 失败用例的详细错误信息
4. 性能指标（如适用）
5. 环境信息（Java 版本、数据库版本等）

### 报告格式

- 控制台输出（PASS/FAIL）
- 可选的 JSON/XML 报告（用于 CI/CD 集成）

## 已知限制

1. **Extract Service 依赖：** Extract API 依赖外部 Python 服务，如果服务不可用，测试标记为 WARN
2. **匹配结果为空：** 如果数据库中没有成功画像数据，Match API 返回空数组是正常行为
3. **数据库配置不匹配：** 当前应用配置与 docker-compose 存在端口/数据库名不匹配，需要在 README 中说明解决方案

## 更新日志

- 2024-01-01: 初始版本
