-- ============================================================
-- Success Cohort Seed Data — Phase 1
-- 20 profiles: Java Backend (10), Python ML (5), DevOps (5)
-- Tables: rb_success_profile + rb_success_profile_tag
-- Run after V4__success_profile_and_match.sql migration
-- ============================================================

set search_path to rb, public;

-- ------------------------------------------------------------
-- Insert success profiles
-- ------------------------------------------------------------
insert into rb_success_profile (profile_id, source, role, level, company, raw_text) values
-- Java Backend (10)
(101, 'internal_employee', 'Java Backend Engineer', 'senior',  'Alibaba',    '8 years Java, Spring Boot microservices, MySQL, Kafka, Docker, design patterns expert'),
(102, 'internal_employee', 'Java Backend Engineer', 'mid',     'ByteDance',  '5 years Java, Spring Cloud, Redis, PostgreSQL, RESTful API, unit testing'),
(103, 'internal_employee', 'Java Backend Engineer', 'junior',  'Meituan',    '2 years Java, Spring Boot, MySQL, Git, Agile workflow, code review'),
(104, 'external_success',  'Java Backend Engineer', 'senior',  'FinTech',    '10 years Java, distributed systems, Elasticsearch, Kubernetes, high availability design'),
(105, 'external_success',  'Java Backend Engineer', 'mid',     'E-Commerce', '4 years Java, Spring Boot, RabbitMQ, Docker, CI/CD, JUnit, Mockito'),
(106, 'internal_employee', 'Java Backend Engineer', 'senior',  'Tencent',    '7 years Java, gRPC, Netty, MongoDB, Zookeeper, performance tuning'),
(107, 'internal_employee', 'Java Backend Engineer', 'mid',     'JD.com',     '5 years Java, MyBatis, Spring Security, OAuth2, Redis, Swagger'),
(108, 'external_success',  'Java Backend Engineer', 'junior',  'Startup',    '2 years Java, Spring Boot, PostgreSQL, Git, Docker, Agile'),
(109, 'external_success',  'Java Backend Engineer', 'senior',  'Banking',    '9 years Java, Spring Batch, Oracle, MQ, SOA, security compliance'),
(110, 'internal_employee', 'Java Backend Engineer', 'mid',     'Baidu',      '6 years Java, Dubbo, ZooKeeper, Redis, MySQL, DDD architecture'),

-- Python ML (5)
(201, 'internal_employee', 'Python ML Engineer',   'senior',  'DiDi',       '7 years Python, PyTorch, scikit-learn, feature engineering, model deployment, MLflow'),
(202, 'internal_employee', 'Python ML Engineer',   'mid',     'NetEase',    '4 years Python, TensorFlow, pandas, numpy, data pipeline, REST API'),
(203, 'external_success',  'Python ML Engineer',   'junior',  'AI Startup', '2 years Python, scikit-learn, SQL, Jupyter, statistical analysis, Git'),
(204, 'external_success',  'Python ML Engineer',   'senior',  'Tech Corp',  '8 years Python, deep learning, NLP, Spark, Hive, Airflow, Docker'),
(205, 'internal_employee', 'Python ML Engineer',   'mid',     'XiaoMi',     '5 years Python, recommendation system, A/B testing, Kafka, Redis, Flask'),

-- DevOps (5)
(301, 'internal_employee', 'DevOps Engineer',      'senior',  'Alibaba',    '8 years Linux, Kubernetes, Terraform, Jenkins, Ansible, Prometheus, Grafana, AWS'),
(302, 'internal_employee', 'DevOps Engineer',      'mid',     'ByteDance',  '5 years Docker, Kubernetes, CI/CD, GitLab, Helm, ELK Stack, shell scripting'),
(303, 'external_success',  'DevOps Engineer',      'junior',  'Agency',     '2 years Linux, Docker, Jenkins, Git, Nginx, basic Terraform, monitoring'),
(304, 'external_success',  'DevOps Engineer',      'senior',  'Cloud Co',   '9 years AWS, Azure, GCP, Terraform, Puppet, Chef, incident management, SRE'),
(305, 'internal_employee', 'DevOps Engineer',      'mid',     'Tencent',    '6 years Kubernetes, ArgoCD, Prometheus, Grafana, Python scripting, security hardening')
on conflict (profile_id) do nothing;

-- Keep profile_id sequence ahead of manual inserts
select setval('rb_success_profile_profile_id_seq', 400, false);

-- ------------------------------------------------------------
-- Insert success profile tags
-- ------------------------------------------------------------
insert into rb_success_profile_tag (profile_id, canonical, weight, evidence, via) values

-- ── Java Backend profile 101 (senior, Alibaba) ──────────────
(101, 'skill/java',        1.0000, '8 years Java',             'manual'),
(101, 'skill/spring boot', 0.9000, 'Spring Boot microservices', 'manual'),
(101, 'skill/mysql',       0.8000, 'MySQL',                    'manual'),
(101, 'skill/kafka',       0.8000, 'Kafka',                    'manual'),
(101, 'skill/docker',      0.7000, 'Docker',                   'manual'),
(101, 'exp/5-10',          1.0000, '8 years',                  'manual'),

-- ── Java Backend profile 102 (mid, ByteDance) ────────────────
(102, 'skill/java',        1.0000, '5 years Java',             'manual'),
(102, 'skill/spring boot', 0.9000, 'Spring Cloud',             'manual'),
(102, 'skill/redis',       0.8000, 'Redis',                    'manual'),
(102, 'skill/postgresql',  0.7500, 'PostgreSQL',               'manual'),
(102, 'skill/git',         0.6000, 'RESTful API',              'manual'),
(102, 'exp/3-5',           1.0000, '5 years',                  'manual'),

-- ── Java Backend profile 103 (junior, Meituan) ───────────────
(103, 'skill/java',        1.0000, '2 years Java',             'manual'),
(103, 'skill/spring boot', 0.8500, 'Spring Boot',              'manual'),
(103, 'skill/mysql',       0.7000, 'MySQL',                    'manual'),
(103, 'skill/git',         0.6500, 'Git',                      'manual'),
(103, 'exp/1-3',           1.0000, '2 years',                  'manual'),

-- ── Java Backend profile 104 (senior, FinTech) ───────────────
(104, 'skill/java',        1.0000, '10 years Java',            'manual'),
(104, 'skill/elasticsearch', 0.8500, 'Elasticsearch',          'manual'),
(104, 'skill/kubernetes',  0.8000, 'Kubernetes',               'manual'),
(104, 'exp/5-10',          1.0000, '10 years',                 'manual'),

-- ── Java Backend profile 105 (mid, E-Commerce) ───────────────
(105, 'skill/java',        1.0000, '4 years Java',             'manual'),
(105, 'skill/spring boot', 0.9000, 'Spring Boot',              'manual'),
(105, 'skill/docker',      0.7500, 'Docker',                   'manual'),
(105, 'skill/rabbitmq',    0.7500, 'RabbitMQ',                 'manual'),
(105, 'exp/3-5',           1.0000, '4 years',                  'manual'),

-- ── Java Backend profile 106 (senior, Tencent) ───────────────
(106, 'skill/java',        1.0000, '7 years Java',             'manual'),
(106, 'skill/mongodb',     0.7500, 'MongoDB',                  'manual'),
(106, 'exp/5-10',          1.0000, '7 years',                  'manual'),

-- ── Java Backend profile 107 (mid, JD.com) ───────────────────
(107, 'skill/java',        1.0000, '5 years Java',             'manual'),
(107, 'skill/spring boot', 0.9000, 'Spring Security',          'manual'),
(107, 'skill/redis',       0.8000, 'Redis',                    'manual'),
(107, 'skill/sql',         0.7000, 'MyBatis',                  'manual'),
(107, 'exp/3-5',           1.0000, '5 years',                  'manual'),

-- ── Java Backend profile 108 (junior, Startup) ───────────────
(108, 'skill/java',        1.0000, '2 years Java',             'manual'),
(108, 'skill/spring boot', 0.8500, 'Spring Boot',              'manual'),
(108, 'skill/postgresql',  0.7000, 'PostgreSQL',               'manual'),
(108, 'skill/docker',      0.6500, 'Docker',                   'manual'),
(108, 'exp/1-3',           1.0000, '2 years',                  'manual'),

-- ── Java Backend profile 109 (senior, Banking) ───────────────
(109, 'skill/java',        1.0000, '9 years Java',             'manual'),
(109, 'skill/sql',         0.8000, 'Oracle',                   'manual'),
(109, 'exp/5-10',          1.0000, '9 years',                  'manual'),

-- ── Java Backend profile 110 (mid, Baidu) ────────────────────
(110, 'skill/java',        1.0000, '6 years Java',             'manual'),
(110, 'skill/redis',       0.8000, 'Redis',                    'manual'),
(110, 'skill/mysql',       0.7500, 'MySQL',                    'manual'),
(110, 'exp/5-10',          1.0000, '6 years',                  'manual'),

-- ── Python ML profile 201 (senior, DiDi) ─────────────────────
(201, 'skill/python',      1.0000, '7 years Python',           'manual'),
(201, 'skill/pytorch',     0.9000, 'PyTorch',                  'manual'),
(201, 'skill/scikit-learn',0.8500, 'scikit-learn',             'manual'),
(201, 'skill/docker',      0.7000, 'model deployment',         'manual'),
(201, 'exp/5-10',          1.0000, '7 years',                  'manual'),

-- ── Python ML profile 202 (mid, NetEase) ─────────────────────
(202, 'skill/python',      1.0000, '4 years Python',           'manual'),
(202, 'skill/tensorflow',  0.9000, 'TensorFlow',               'manual'),
(202, 'skill/sql',         0.7000, 'data pipeline',            'manual'),
(202, 'exp/3-5',           1.0000, '4 years',                  'manual'),

-- ── Python ML profile 203 (junior, AI Startup) ───────────────
(203, 'skill/python',      1.0000, '2 years Python',           'manual'),
(203, 'skill/scikit-learn',0.8000, 'scikit-learn',             'manual'),
(203, 'skill/sql',         0.7000, 'SQL',                      'manual'),
(203, 'skill/git',         0.6500, 'Git',                      'manual'),
(203, 'exp/1-3',           1.0000, '2 years',                  'manual'),

-- ── Python ML profile 204 (senior, Tech Corp) ────────────────
(204, 'skill/python',      1.0000, '8 years Python',           'manual'),
(204, 'skill/pytorch',     0.9000, 'deep learning, NLP',       'manual'),
(204, 'skill/docker',      0.8000, 'Docker',                   'manual'),
(204, 'skill/kafka',       0.7000, 'Kafka',                    'manual'),
(204, 'exp/5-10',          1.0000, '8 years',                  'manual'),

-- ── Python ML profile 205 (mid, XiaoMi) ─────────────────────
(205, 'skill/python',      1.0000, '5 years Python',           'manual'),
(205, 'skill/redis',       0.7500, 'Redis',                    'manual'),
(205, 'skill/kafka',       0.7000, 'Kafka',                    'manual'),
(205, 'exp/3-5',           1.0000, '5 years',                  'manual'),

-- ── DevOps profile 301 (senior, Alibaba) ─────────────────────
(301, 'skill/linux',       1.0000, 'Linux',                    'manual'),
(301, 'skill/kubernetes',  0.9500, 'Kubernetes',               'manual'),
(301, 'skill/terraform',   0.9000, 'Terraform',                'manual'),
(301, 'skill/jenkins',     0.8500, 'Jenkins',                  'manual'),
(301, 'skill/ansible',     0.8000, 'Ansible',                  'manual'),
(301, 'skill/aws',         0.8000, 'AWS',                      'manual'),
(301, 'skill/docker',      0.8500, 'Docker',                   'manual'),
(301, 'exp/5-10',          1.0000, '8 years',                  'manual'),

-- ── DevOps profile 302 (mid, ByteDance) ──────────────────────
(302, 'skill/docker',      1.0000, 'Docker',                   'manual'),
(302, 'skill/kubernetes',  0.9500, 'Kubernetes',               'manual'),
(302, 'skill/linux',       0.8000, 'GitLab CI/CD',             'manual'),
(302, 'skill/git',         0.7500, 'Git',                      'manual'),
(302, 'exp/3-5',           1.0000, '5 years',                  'manual'),

-- ── DevOps profile 303 (junior, Agency) ──────────────────────
(303, 'skill/linux',       1.0000, 'Linux',                    'manual'),
(303, 'skill/docker',      0.8500, 'Docker',                   'manual'),
(303, 'skill/jenkins',     0.7500, 'Jenkins',                  'manual'),
(303, 'skill/git',         0.7000, 'Git',                      'manual'),
(303, 'exp/1-3',           1.0000, '2 years',                  'manual'),

-- ── DevOps profile 304 (senior, Cloud Co) ────────────────────
(304, 'skill/aws',         1.0000, 'AWS',                      'manual'),
(304, 'skill/terraform',   0.9000, 'Terraform',                'manual'),
(304, 'skill/kubernetes',  0.8500, 'Kubernetes',               'manual'),
(304, 'skill/linux',       0.8000, 'Linux',                    'manual'),
(304, 'exp/5-10',          1.0000, '9 years',                  'manual'),

-- ── DevOps profile 305 (mid, Tencent) ────────────────────────
(305, 'skill/kubernetes',  0.9500, 'Kubernetes',               'manual'),
(305, 'skill/docker',      0.8500, 'Docker',                   'manual'),
(305, 'skill/linux',       0.8000, 'security hardening',       'manual'),
(305, 'skill/python',      0.7000, 'Python scripting',         'manual'),
(305, 'exp/3-5',           1.0000, '6 years',                  'manual')

on conflict do nothing;
