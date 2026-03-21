-- ============================================================
-- V7: Bridge views for rb-schema tables
-- Purpose: Java repos query without schema qualification (default = public).
--          Tables created by V4 landed in the 'rb' schema due to
--          "set search_path to rb, public" in that migration.
--          These updatable views expose them under public so no
--          Java code or search_path setting needs to change.
-- ============================================================

create or replace view public.rb_match_run         as select * from rb.rb_match_run;
create or replace view public.rb_match_result      as select * from rb.rb_match_result;
create or replace view public.rb_resume_project    as select * from rb.rb_resume_project;
create or replace view public.rb_resume_project_tag as select * from rb.rb_resume_project_tag;
create or replace view public.rb_success_profile   as select * from rb.rb_success_profile;
create or replace view public.rb_success_profile_tag as select * from rb.rb_success_profile_tag;
