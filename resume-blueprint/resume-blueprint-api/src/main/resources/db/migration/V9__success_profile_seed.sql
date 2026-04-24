-- Seed: Senior Java Backend Engineer success profiles
-- Provides reference data for the recommendation engine so scores are meaningful.

-- Internal employee benchmark
INSERT INTO rb_success_profile(source, role, level, company, raw_text)
VALUES ('internal_employee', 'Java Backend Engineer', 'senior', 'Acme Corp',
        'Senior Java Backend Engineer: 5+ years Java/Spring Boot microservices, PostgreSQL, Docker, Kafka, Redis, CI/CD.');

INSERT INTO rb_success_profile_tag(profile_id, canonical, weight, evidence, via)
SELECT profile_id, canonical, weight, evidence, 'manual'
FROM rb_success_profile,
     (VALUES
        ('java',          1.0000, 'Core language requirement'),
        ('spring-boot',   0.9500, 'Primary framework'),
        ('postgresql',    0.9000, 'Primary database'),
        ('docker',        0.8500, 'Container platform'),
        ('rest-api',      0.8500, 'API design'),
        ('spring',        0.8000, 'Spring ecosystem'),
        ('microservices', 0.8000, 'Architecture pattern'),
        ('maven',         0.7500, 'Build tool'),
        ('kafka',         0.6500, 'Message broker'),
        ('redis',         0.6500, 'Cache layer'),
        ('ci-cd',         0.6000, 'DevOps practice'),
        ('kubernetes',    0.6000, 'Orchestration'),
        ('sql',           0.6000, 'Query language'),
        ('junit',         0.5000, 'Testing framework'),
        ('git',           0.4500, 'Version control'),
        ('gradle',        0.4000, 'Build tool alt')
     ) AS t(canonical, weight, evidence)
WHERE source = 'internal_employee' AND role = 'Java Backend Engineer' AND level = 'senior';

-- External success benchmark
INSERT INTO rb_success_profile(source, role, level, company, raw_text)
VALUES ('external_success', 'Java Backend Engineer', 'senior', NULL,
        'Senior Java Backend Engineer benchmark: strong Java, Spring Boot, PostgreSQL, Docker, microservices experience.');

INSERT INTO rb_success_profile_tag(profile_id, canonical, weight, evidence, via)
SELECT profile_id, canonical, weight, evidence, 'manual'
FROM rb_success_profile,
     (VALUES
        ('java',          1.0000, 'Core language'),
        ('spring-boot',   0.9500, 'Primary framework'),
        ('postgresql',    0.9000, 'Relational DB'),
        ('docker',        0.8500, 'Containerization'),
        ('rest-api',      0.8500, 'API design'),
        ('spring',        0.8000, 'Spring ecosystem'),
        ('microservices', 0.8000, 'Distributed systems'),
        ('maven',         0.7500, 'Build automation'),
        ('kafka',         0.6500, 'Event streaming'),
        ('redis',         0.6500, 'Caching'),
        ('ci-cd',         0.6000, 'Continuous delivery'),
        ('kubernetes',    0.6000, 'Container orchestration'),
        ('sql',           0.6000, 'Data querying'),
        ('junit',         0.5000, 'Unit testing'),
        ('git',           0.4500, 'Source control'),
        ('gradle',        0.4000, 'Build tool')
     ) AS t(canonical, weight, evidence)
WHERE source = 'external_success' AND role = 'Java Backend Engineer' AND level = 'senior';
