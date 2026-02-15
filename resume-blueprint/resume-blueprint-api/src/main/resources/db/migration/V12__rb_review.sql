create table if not exists rb_term_review (
  review_id bigserial primary key,
  baseline_set_id bigint references rb_baseline_set(baseline_set_id),
  run_id bigint not null references rb_run(run_id),
  term text not null,
  normalized text not null,
  score numeric(6,4) not null default 0.5000,
  evidence_text text,
  status text not null default 'pending',  -- pending/approved/rejected
  created_at timestamptz not null default now(),
  unique(run_id, normalized)
);

create index if not exists idx_rb_term_review_status on rb_term_review(status);
