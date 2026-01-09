# spaCy + SkillNER 集成总结

## 已完成的工作

### 1. Python 提取服务 (`extract-service/`)

✅ **Flask 微服务** (`extract_service.py`)
- 集成 spaCy NER（英文命名实体识别）
- 集成 SkillNER（技能抽取）
- 提供 REST API (`/extract`, `/health`)
- 输出格式兼容 `rb_baseline_term` 表结构

✅ **Docker 配置**
- Dockerfile 包含 Python 3.11 + spaCy + SkillNER
- 自动下载 spaCy 英文模型
- Health check 配置

✅ **依赖管理**
- `requirements.txt` 定义所有 Python 依赖

### 2. Java Spring Boot 集成

✅ **API 层** (`ExtractController.java`)
- `POST /api/extract` - 提取接口
- `GET /api/extract/health` - 健康检查

✅ **服务层** (`ExtractService.java`)
- 调用 Python 服务
- 持久化到 `rb_run` / `rb_extracted_tag` / `rb_tag_evidence`
- 计算置信度分数

✅ **基础设施层** (`SpacyExtractorClient.java`)
- WebClient HTTP 客户端
- 错误处理和降级

✅ **DTO 层**
- `ExtractRequest.java` - 请求对象
- `ExtractResponse.java` - 响应对象

✅ **配置**
- `application.yml` 添加 `extract.service.url` 配置

### 3. Docker Compose 集成

✅ **更新 `docker-compose.yml`**
- 添加 `extract-service` 服务
- 端口映射：5000:5000
- Health check 配置

### 4. 脚本集成

✅ **`run_demo_spacy.sh`**
- 调用 Python 提取服务
- 生成 SQL 使用提取结果
- 执行完整的 4-box 流程
- 自动降级到 SQL 提取（如果服务不可用）

### 5. 文档

✅ **`extract-service/README.md`** - Python 服务使用说明
✅ **`INTEGRATION.md`** - 完整集成指南
✅ **`SPACY_INTEGRATION_SUMMARY.md`** - 本文档

## 架构设计

### 数据流

```
Resume/JD Text
    ↓
[Python Service: spaCy + SkillNER]
    ↓
Extracted Entities (JSON)
    ↓
[Java Service: ExtractService]
    ↓
Database (rb_run, rb_extracted_tag, rb_tag_evidence)
    ↓
[4-Box Framework: Normalize → Tagging → Match]
    ↓
Final Result (Score + Evidence)
```

### 输出格式

**Canonical 格式：**
- Skills: `skill/{normalized}` (e.g., `skill/python`)
- NER: `ner/{label}/{normalized}` (e.g., `ner/ORG/Google`)

**Evidence 结构：**
```json
{
  "hit": "Python3",
  "canonical": "skill/python",
  "via": "spacy+skillner",
  "evidence": "Skilled in Python3; 3 years experience"
}
```

## 使用方法

### 1. 启动服务

```bash
cd talent-archive-core
docker-compose up -d
```

### 2. 验证服务

```bash
# 检查 Python 服务
curl http://localhost:5000/health

# 检查 Java API（如果已启动）
curl http://localhost:18080/api/extract/health
```

### 3. 运行演示

```bash
cd talent-archive-core
./bin/run_demo_spacy.sh
```

### 4. 通过 API 调用

```bash
# 直接调用 Python 服务
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{"text": "Skilled in Python and Java...", "doc_type": "RESUME"}'

# 通过 Java API（需要先启动 Spring Boot）
curl -X POST http://localhost:18080/api/extract \
  -H "Content-Type: application/json" \
  -d '{
    "documentId": 1,
    "text": "Skilled in Python and Java...",
    "docType": "RESUME"
  }'
```

## 关键特性

### ✅ 可追溯性 (Traceability)

每个提取的实体都包含：
- **hit**: 原始匹配文本
- **canonical**: 标准化标签
- **via**: 提取来源 (`spacy+skillner`)
- **evidence**: 上下文证据

### ✅ 可解释性 (Explainability)

可以回答："为什么提取了这个技能？"
→ "因为简历中显示：'Skilled in Python3...'"

### ✅ 可复现性 (Reproducibility)

- 提取器版本记录在 `rb_run.config` JSON 中
- 模型版本可追踪
- 相同输入 → 相同输出

### ✅ Docker 化

- 所有服务都在 Docker 中运行
- 易于部署和迁移
- 环境一致性

## 下一步优化建议

1. **扩展技能词典**
   - 添加更多技术技能到 SkillNER
   - 支持自定义技能词典

2. **NER 标签映射**
   - 将 spaCy NER 标签映射到 baseline terms
   - 例如：`ner/ORG/Google` → `company/google`

3. **置信度评分优化**
   - 基于实体类型调整分数
   - 考虑上下文相关性

4. **批量处理**
   - 支持批量提取
   - 优化性能

5. **错误处理增强**
   - 更详细的错误信息
   - 重试机制

## 文件清单

### Python 服务
- `extract-service/extract_service.py` - Flask 应用
- `extract-service/requirements.txt` - Python 依赖
- `extract-service/Dockerfile` - Docker 配置
- `extract-service/README.md` - 服务文档

### Java 集成
- `resume-blueprint-api/.../api/ExtractController.java`
- `resume-blueprint-api/.../service/ExtractService.java`
- `resume-blueprint-api/.../infra/SpacyExtractorClient.java`
- `resume-blueprint-api/.../dto/ExtractRequest.java`
- `resume-blueprint-api/.../dto/ExtractResponse.java`

### 脚本和配置
- `talent-archive-core/bin/run_demo_spacy.sh` - 集成脚本
- `talent-archive-core/docker-compose.yml` - Docker Compose 配置
- `talent-archive-core/INTEGRATION.md` - 集成指南

## 测试验证

### 单元测试（待实现）
- Python 服务测试
- Java Service 测试
- 集成测试

### 手动测试
```bash
# 1. 启动服务
docker-compose up -d

# 2. 运行演示
./bin/run_demo_spacy.sh

# 3. 检查结果
psql "postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db" \
  -c "SELECT id, result_json FROM rb.rb_analysis_run ORDER BY id DESC LIMIT 1;"
```

## 注意事项

1. **模型下载**：首次运行需要下载 spaCy 模型（~500MB）
2. **端口冲突**：确保 5000 端口未被占用
3. **数据库连接**：确保 PostgreSQL 已启动
4. **依赖安装**：Python 服务需要安装依赖（Docker 自动处理）

## 总结

✅ 已完成 spaCy + SkillNER 集成到 4-box 框架
✅ 所有组件已 Docker 化
✅ 保持可追溯性和可解释性
✅ 与现有数据库结构兼容
✅ 提供完整的 API 和脚本接口

系统现在可以在 Box 1 (Extract) 阶段使用 NLP 模型进行更准确的实体提取！
