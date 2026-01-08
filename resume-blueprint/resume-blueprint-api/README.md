# Resume Blueprint API (rb_)

目标：把简历文本 -> 可追溯的分析 run -> tags -> 逐步沉淀 baseline（基本词表），后续简历优先按 baseline 对齐。

## 数据流
1. POST /api/resumes
   - 保存 rb_document（简历原文）
2. POST /api/resumes/{documentId}/analyze/bootstrap
   - LLM 自由抽关键词：用于冷启动积累词表
   - 写入 rb_run + rb_extracted_tag + rb_tag_evidence
3. POST /api/baseline/build?lastN=50&minCount=2
   - 从历史 run 的 tags 聚合生成 baseline_set + baseline_term
4. POST /api/resumes/{documentId}/analyze/baseline?baselineSetId=...
   - LLM 只能从 baseline 中选择 selected_terms
   - new_terms 进入 pending（后续人工确认/映射）

## 表设计（全部 rb_ 前缀，避免与旧项目冲突）
- rb_document: 简历文本
- rb_run: 一次分析（模型/提示词版本/配置可追溯）
- rb_canonical_tag: 规范化标签（INTERNAL/ESCO/...）
- rb_extracted_tag: run 的标签结果（score）
- rb_tag_evidence: 标签证据
- rb_baseline_set / rb_baseline_term / rb_baseline_alias: 基本词表（版本化）与别名映射

## 目录结构
- api/: Controller + DTO
- service/: 业务流程（ingest/analyze/build baseline）
- repo/: SQL 访问（JdbcTemplate）
- infra/: LLM 可替换实现（当前 stub，后续接 OpenAI）
