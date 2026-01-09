# 标签比对系统使用指南

## 概述

标签比对系统实现了"简历 vs 成功样本"的相似度对比，输出匹配分数、证据、缺口和建议。

## 架构位置

集成到 4-box 框架的 Box 3/4：
- **Box 1**: Extract（spaCy + SkillNER）✅
- **Box 2**: Normalize（baseline dictionary）✅
- **Box 3**: Compare/Match（简历 vs 成功样本）✅ **新增**
- **Box 4**: Report/Action（输出可解释报告）✅ **新增**

## 核心功能

### 1. 成功样本导入

支持两类成功样本：
- **Internal Success Cohort**: 公司内部已招聘成功/现员工
- **External Success Cohort**: 外部求职成功样本（LinkedIn 等，合规获取）

### 2. 比对算法

**加权 Jaccard 相似度**：
- `overlap_score = intersection / union`（加权）
- `gap_penalty`: 成功样本高权重但简历缺失的标签（最多扣 30%）
- `bonus_score`: 简历有但成功样本较少的差异化强项（最多加 15%）
- `final_score = overlap_score - gap_penalty + bonus_score`

### 3. 输出内容

- **Top Overlaps**: 主要重叠标签 + 证据
- **Top Gaps**: 主要缺口标签（按成功样本权重排序）
- **Top Strengths**: 差异化强项
- **Score Breakdown**: 详细分数分解

## API 使用

### 1. 导入成功样本

```bash
POST /api/success-profiles/import
Content-Type: application/json

{
  "source": "internal_employee",
  "role": "Java Backend Engineer",
  "level": "mid",
  "company": "Acme Corp",
  "text": "5 years experience in Java, Spring Boot, microservices. Led team of 3 developers..."
}
```

**响应：**
```json
{
  "profileId": 1,
  "message": "Profile imported successfully"
}
```

### 2. 执行匹配

```bash
POST /api/match
Content-Type: application/json

{
  "resumeDocumentId": 1,
  "target": "both",  // "internal" | "external" | "both"
  "roleFilter": "Java Backend Engineer",  // optional
  "levelFilter": "mid"  // optional
}
```

**响应：**
```json
{
  "matchRunId": 1,
  "matches": [
    {
      "source": "internal_employee",
      "score": 0.75,
      "overlapScore": 0.82,
      "gapPenalty": 0.15,
      "bonusScore": 0.08,
      "topOverlaps": [
        {
          "canonical": "skill/java",
          "weight": 1.0,
          "reason": "Matched tag"
        }
      ],
      "topGaps": [
        {
          "canonical": "skill/kubernetes",
          "weight": 0.9,
          "reason": "Missing high-weight tag"
        }
      ],
      "topStrengths": [
        {
          "canonical": "skill/python",
          "weight": 0.8,
          "reason": "Stronger than cohort average"
        }
      ]
    },
    {
      "source": "external_success",
      "score": 0.68,
      ...
    }
  ]
}
```

## 数据库表结构

### rb_success_profile
成功样本画像（不一定是具体个人，也可以是一组）

### rb_success_profile_tag
成功样本的标签明细（带权重）

### rb_resume_project
简历项目（从简历中提取的项目经历）

### rb_resume_project_tag
简历项目的标签明细

### rb_match_run
一次比对操作（可追溯）

### rb_match_result
比对结果（分数、重叠、缺口、解释）

## 使用流程

### Step 1: 导入成功样本

**内部样本：**
```bash
# 导入内部员工样本
curl -X POST http://localhost:18080/api/success-profiles/import \
  -H "Content-Type: application/json" \
  -d '{
    "source": "internal_employee",
    "role": "Java Backend Engineer",
    "level": "mid",
    "company": "Your Company",
    "text": "Employee profile text here..."
  }'
```

**外部样本（合规）：**
```bash
# 导入外部成功样本（手动采集，不爬虫）
curl -X POST http://localhost:18080/api/success-profiles/import \
  -H "Content-Type: application/json" \
  -d '{
    "source": "external_success",
    "role": "Java Backend Engineer",
    "level": "mid",
    "company": "Tech Industry",
    "text": "Successfully hired candidate profile..."
  }'
```

### Step 2: 导入简历

```bash
# 先导入简历
POST /api/resumes
{
  "candidateId": "candidate_001",
  "text": "Resume text here..."
}
```

### Step 3: 执行匹配

```bash
# 匹配简历与成功样本
POST /api/match
{
  "resumeDocumentId": 1,
  "target": "both"
}
```

### Step 4: 查看结果

结果包含：
- **匹配分数**: 0-1 之间的分数
- **重叠标签**: 简历与成功样本都有的标签
- **缺口标签**: 成功样本有但简历缺失的标签
- **差异化强项**: 简历有但成功样本较少的标签

## 比对算法详解

### 1. 加权 Jaccard 相似度

```
overlap_score = sum(min(resume_weight, cohort_weight)) / sum(max(resume_weight, cohort_weight))
```

### 2. Gap Penalty

对成功样本中高权重（>0.5）但简历缺失的标签进行惩罚：
```
gap_penalty = sum(gap_weight * 0.1)  # 每个缺口扣 10%
gap_penalty = min(gap_penalty, 0.3)  # 最多扣 30%
```

### 3. Bonus Score

对简历中比成功样本平均权重高 20% 以上的标签给予奖励：
```
bonus_score = sum(strength_weight * 0.05)  # 每个强项加 5%
bonus_score = min(bonus_score, 0.15)      # 最多加 15%
```

### 4. Final Score

```
final_score = max(0, min(1, overlap_score - gap_penalty + bonus_score))
```

## 外部样本获取（合规路径）

**重要：不使用爬虫，采用人工采集**

### 方法 1: LinkedIn 公开数据
- 使用 LinkedIn 的公开搜索功能
- 手动复制成功候选人的公开 profile 描述
- 脱敏处理（移除姓名、具体公司名等）
- 只保留技能、项目描述等结构化信息

### 方法 2: 招聘平台公开数据
- 从招聘平台（如 Indeed、Glassdoor）的公开职位描述
- 提取"成功候选人"的典型要求
- 作为外部成功样本的参考

### 方法 3: 行业报告
- 参考行业技能报告（如 Stack Overflow Survey）
- 提取"成功开发者"的技能分布
- 作为外部成功样本的补充

### CSV 导入模板

创建 `external_success_ingest.csv`:
```csv
source,role,level,company,text
external_success,Java Backend Engineer,mid,Tech Industry,"5+ years Java, Spring Boot, microservices..."
external_success,Java Backend Engineer,senior,Tech Industry,"8+ years Java, distributed systems..."
```

然后批量导入（需要实现批量导入接口，当前版本支持单个导入）。

## 下一步优化（P1/P2/P3）

### P1: 项目维度提取
- [ ] 简历解析：把简历拆成 projects
- [ ] 对每个 project 单独抽 tags
- [ ] 报告里展示：哪个项目贡献了哪些标签

### P2: 外部样本上量
- [ ] 批量导入 CSV
- [ ] 做对比：internal vs external 成功画像差异

### P3: 评估与迭代
- [ ] 评测集（20~50 份简历）
- [ ] 记录 algo_version，确保可追溯迭代

## 注意事项

1. **隐私保护**：
   - External 样本永远只输出"画像/分布/对比结果"，不做个人识别
   - Internal 样本建议先做"团队画像（cohort）"，不要直接对某个员工逐个比对

2. **可追溯性**：
   - 每次匹配都记录 `match_run_id`
   - 算法版本记录在 `algo_version` 字段
   - 配置参数记录在 `config` JSON 中

3. **可解释性**：
   - 每个标签都有 `evidence`（原文片段）
   - 每个分数都有 `explain_json`（详细解释）

## 示例场景

### 场景：Java 后端工程师（mid）匹配

**成功样本标签分布：**
- skill/java: 1.0
- skill/spring_boot: 0.9
- skill/microservices: 0.8
- skill/kubernetes: 0.7
- skill/docker: 0.6

**简历标签：**
- skill/java: 1.0
- skill/spring_boot: 0.9
- skill/microservices: 0.7
- skill/python: 0.8  (差异化强项)

**匹配结果：**
- Overlap Score: 0.82 (有 Java, Spring Boot, Microservices)
- Gap Penalty: 0.14 (缺少 Kubernetes, Docker)
- Bonus Score: 0.05 (Python 是强项)
- Final Score: 0.73

**建议：**
- ✅ 重叠：Java, Spring Boot, Microservices（匹配良好）
- ⚠️ 缺口：Kubernetes, Docker（建议补强）
- 💪 强项：Python（差异化优势）
