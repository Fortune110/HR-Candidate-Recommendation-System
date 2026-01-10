# Tag Matching System Usage Guide

## Overview

The tag matching system implements similarity comparison between "resume vs success profile", outputting match scores, evidence, gaps, and recommendations.

## Architecture Position

Integrated into Box 3/4 of the 4-box framework:
- **Box 1**: Extract（spaCy + SkillNER）✅
- **Box 2**: Normalize（baseline dictionary）✅
- **Box 3**: Compare/Match（resume vs success profile）✅ **NEW**
- **Box 4**: Report/Action（output interpretable reports）✅ **NEW**

## Core Features

### 1. Success Profile Import

Supports two types of success profiles:
- **Internal Success Cohort**: Successfully hired employees / current employees within the company
- **External Success Cohort**: External successful candidate samples (LinkedIn, etc., obtained compliantly)

### 2. Matching Algorithm

**Weighted Jaccard Similarity**:
- `overlap_score = intersection / union` (weighted)
- `gap_penalty`: High-weight tags in success profile but missing in resume (max deduction 30%)
- `bonus_score`: Differentiating strengths in resume but fewer in success profile (max addition 15%)
- `final_score = overlap_score - gap_penalty + bonus_score`

### 3. Output Content

- **Top Overlaps**: Main overlapping tags + evidence
- **Top Gaps**: Main gap tags (sorted by success profile weight)
- **Top Strengths**: Differentiating strengths
- **Score Breakdown**: Detailed score decomposition

## API Usage

### 1. Import Success Profile

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

**Response:**
```json
{
  "profileId": 1,
  "message": "Profile imported successfully"
}
```

### 2. Execute Matching

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

**Response:**
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

## Database Table Structure

### rb_success_profile
Success profile (not necessarily a specific person, can also be a group)

### rb_success_profile_tag
Success profile tag details (with weights)

### rb_resume_project
Resume project (project experience extracted from resume)

### rb_resume_project_tag
Resume project tag details

### rb_match_run
A matching operation (traceable)

### rb_match_result
Matching results (score, overlaps, gaps, explanations)

## Usage Flow

### Step 1: Import Success Profile

**Internal Samples:**
```bash
# Import internal employee samples
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

**External Samples (Compliant):**
```bash
# Import external success samples (manual collection, no scraping)
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

### Step 2: Import Resume

```bash
# First import resume
POST /api/resumes
{
  "candidateId": "candidate_001",
  "text": "Resume text here..."
}
```

### Step 3: Execute Matching

```bash
# Match resume with success profile
POST /api/match
{
  "resumeDocumentId": 1,
  "target": "both"
}
```

### Step 4: View Results

Results include:
- **Match Score**: Score between 0-1
- **Overlapping Tags**: Tags present in both resume and success profile
- **Gap Tags**: Tags in success profile but missing in resume
- **Differentiating Strengths**: Tags in resume but fewer in success profile

## Matching Algorithm Details

### 1. Weighted Jaccard Similarity

```
overlap_score = sum(min(resume_weight, cohort_weight)) / sum(max(resume_weight, cohort_weight))
```

### 2. Gap Penalty

Penalize high-weight tags (>0.5) in success profile that are missing in resume:
```
gap_penalty = sum(gap_weight * 0.1)  # Deduct 10% per gap
gap_penalty = min(gap_penalty, 0.3)  # Max deduction 30%
```

### 3. Bonus Score

Reward tags in resume that are 20% higher than success profile average weight:
```
bonus_score = sum(strength_weight * 0.05)  # Add 5% per strength
bonus_score = min(bonus_score, 0.15)      # Max addition 15%
```

### 4. Final Score

```
final_score = max(0, min(1, overlap_score - gap_penalty + bonus_score))
```

## External Sample Acquisition (Compliant Path)

**Important: Do not use scrapers, use manual collection**

### Method 1: LinkedIn Public Data
- Use LinkedIn's public search function
- Manually copy public profile descriptions of successful candidates
- De-identify (remove names, specific company names, etc.)
- Only keep structured information like skills, project descriptions

### Method 2: Job Board Public Data
- Extract from job board public job descriptions (e.g., Indeed, Glassdoor)
- Extract typical requirements for "successful candidates"
- Use as reference for external success profiles

### Method 3: Industry Reports
- Reference industry skill reports (e.g., Stack Overflow Survey)
- Extract skill distribution of "successful developers"
- Use as supplement for external success profiles

### CSV Import Template

Create `external_success_ingest.csv`:
```csv
source,role,level,company,text
external_success,Java Backend Engineer,mid,Tech Industry,"5+ years Java, Spring Boot, microservices..."
external_success,Java Backend Engineer,senior,Tech Industry,"8+ years Java, distributed systems..."
```

Then batch import (requires implementing batch import interface, current version supports single import).

## Next Steps Optimization (P1/P2/P3)

### P1: Project Dimension Extraction
- [ ] Resume parsing: Split resume into projects
- [ ] Extract tags for each project separately
- [ ] Display in report: Which project contributed which tags

### P2: Scale External Samples
- [ ] Batch CSV import
- [ ] Compare: internal vs external success profile differences

### P3: Evaluation and Iteration
- [ ] Evaluation set (20~50 resumes)
- [ ] Record algo_version to ensure traceable iteration

## Notes

1. **Privacy Protection**:
   - External samples always output only "profile/distribution/comparison results", no personal identification
   - Internal samples should first create "team profile (cohort)", do not directly match individual employees one by one

2. **Traceability**:
   - Each match records `match_run_id`
   - Algorithm version recorded in `algo_version` field
   - Configuration parameters recorded in `config` JSON

3. **Interpretability**:
   - Each tag has `evidence` (original text snippet)
   - Each score has `explain_json` (detailed explanation)

## Example Scenario

### Scenario: Java Backend Engineer (mid) Matching

**Success Profile Tag Distribution:**
- skill/java: 1.0
- skill/spring_boot: 0.9
- skill/microservices: 0.8
- skill/kubernetes: 0.7
- skill/docker: 0.6

**Resume Tags:**
- skill/java: 1.0
- skill/spring_boot: 0.9
- skill/microservices: 0.7
- skill/python: 0.8  (differentiating strength)

**Matching Results:**
- Overlap Score: 0.82 (has Java, Spring Boot, Microservices)
- Gap Penalty: 0.14 (missing Kubernetes, Docker)
- Bonus Score: 0.05 (Python is a strength)
- Final Score: 0.73

**Recommendations:**
- ✅ Overlap: Java, Spring Boot, Microservices (good match)
- ⚠️ Gaps: Kubernetes, Docker (recommend strengthening)
- 💪 Strength: Python (differentiating advantage)
