-- ============================================================
-- ML Training Dataset View
-- Purpose: Export training examples for model training
-- ============================================================

set search_path to rb, public;

-- ------------------------------------------------------------
-- ML Training Examples View
-- Contains job-related features and labels for training
-- ------------------------------------------------------------
create or replace view ml_training_examples_v1 as
select 
    -- Identifiers
    h.job_id,
    h.candidate_id,
    h.history_id,
    
    -- Label: based on final_stage (to_stage)
    case 
        when h.to_stage = 'hired' then 1
        when h.to_stage = 'rejected' then 0
        else null
    end as label,
    h.to_stage as final_stage,
    
    -- Match features (from latest match result for this candidate)
    coalesce(mr.score, 0.0) as match_score,                    -- Current match score
    coalesce(mr.overlap_score, 0.0) as overlap_score,          -- Overlap score
    coalesce(mr.gap_penalty, 0.0) as gap_penalty,              -- Gap penalty
    coalesce(mr.bonus_score, 0.0) as bonus_score,              -- Bonus score
    
    -- Skill match count (from match result overlap_topk or calculated)
    coalesce(
        (select count(*)::int 
         from jsonb_array_elements(mr.overlap_topk) as elem
         where elem->>'canonical' like 'skill/%'),
        0
    ) as skill_match_count,                                     -- Skill match count
    
    -- Year difference (placeholder - can be extended later)
    null::numeric as year_diff,                                 -- Year difference
    
    -- Risk score (placeholder - can be extended later)
    null::numeric as risk_score,                                -- Risk score
    
    -- Metadata
    h.changed_at as stage_changed_at,
    mr.created_at as match_created_at,
    h.reason_code
    
from rb_candidate_stage_history h
-- Join to candidate to ensure candidate exists
left join rb_candidate c on c.candidate_id = h.candidate_id
-- Join to document (resume) via entity_id
left join rb_document d on d.entity_id = h.candidate_id 
    and d.entity_type = 'candidate_resume'
-- Join to latest match run for this resume document
left join lateral (
    select match_run_id
    from rb_match_run
    where resume_document_id = d.document_id
    order by created_at desc
    limit 1
) mr_run on true
-- Join to match result (using first result from the match run)
left join lateral (
    select 
        score,
        overlap_score,
        gap_penalty,
        bonus_score,
        overlap_topk,
        created_at
    from rb_match_result
    where match_run_id = mr_run.match_run_id
    order by score desc
    limit 1
) mr on true
-- Only include records with job_id (for filtering)
where h.job_id is not null;

-- Add comment
comment on view ml_training_examples_v1 is 
    'ML training examples view with job-related features and labels. Label: 1 for HIRED, 0 for REJECTED, NULL for other stages. Filter by job_id to get training data for a specific job position.';
