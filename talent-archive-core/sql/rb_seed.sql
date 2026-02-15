-- ============================================================
-- Resume Blueprint (rb) minimal seed data
-- Purpose:
--   Provide a tiny baseline dictionary + alias mappings so the
--   framework can run end-to-end without real models.
--
-- Notes:
--   - baseline_set_id = 1 is the "tech demo" set for now.
--   - This file is idempotent (ON CONFLICT DO NOTHING).
-- ============================================================

set search_path to rb, public;

-- ------------------------------------------------------------
-- Baseline dictionary (baseline_set_id = 1)
-- ------------------------------------------------------------
insert into rb_baseline_term (baseline_set_id, canonical, normalized, source_note)
values
  (1, 'skill/python', 'skill/python', 'seed'),
  (1, 'skill/java', 'skill/java', 'seed'),
  (1, 'skill/sql', 'skill/sql', 'seed'),
  (1, 'skill/docker', 'skill/docker', 'seed'),
  (1, 'skill/linux', 'skill/linux', 'seed'),
  (1, 'skill/git', 'skill/git', 'seed'),

  (1, 'degree/bachelor', 'degree/bachelor', 'seed'),
  (1, 'degree/master', 'degree/master', 'seed'),

  (1, 'exp/1-3', 'exp/1-3', 'seed'),
  (1, 'exp/3-5', 'exp/3-5', 'seed'),
  (1, 'exp/5-10', 'exp/5-10', 'seed')
on conflict do nothing;

-- ------------------------------------------------------------
-- Alias mappings (baseline_set_id = 1)
-- Keep it small; expand later.
-- ------------------------------------------------------------
insert into rb_alias_map (baseline_set_id, alias, alias_normalized, canonical, source_note)
values
  -- Python variants
  (1, 'py', 'py', 'skill/python', 'seed'),
  (1, 'Python', 'python', 'skill/python', 'seed'),
  (1, 'Python3', 'python3', 'skill/python', 'seed'),
  (1, 'python-language', 'python-language', 'skill/python', 'seed'),

  -- Degree variants (EN)
  (1, 'bachelor', 'bachelor', 'degree/bachelor', 'seed-en'),
  (1, 'bachelor''s', 'bachelor''s', 'degree/bachelor', 'seed-en'),

  -- Experience variants (EN)
  (1, '3 years', '3 years', 'exp/3-5', 'seed-en'),
  (1, '3 year', '3 year', 'exp/3-5', 'seed-en'),
  (1, '3-5 years', '3-5 years', 'exp/3-5', 'seed-en')
on conflict do nothing;
