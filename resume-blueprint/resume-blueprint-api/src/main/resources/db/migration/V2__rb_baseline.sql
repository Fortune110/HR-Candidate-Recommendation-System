create table if not exists rb_baseline_set (
  baseline_set_id bigserial primary key,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists rb_baseline_term (
  term_id bigserial primary key,
  baseline_set_id bigint not null references rb_baseline_set(baseline_set_id),
  tag_type text not null default 'keyword',
  canonical text not null,
  normalized text not null,
  source_note text,
  status text not null default 'active',  -- active/pending/disabled
  created_at timestamptz not null default now(),
  unique(baseline_set_id, normalized)
);

create table if not exists rb_baseline_alias (
  alias_id bigserial primary key,
  term_id bigint not null references rb_baseline_term(term_id),
  alias text not null,
  alias_normalized text not null,
  unique(term_id, alias_normalized)
);
