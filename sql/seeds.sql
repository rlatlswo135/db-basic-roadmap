-- =====================================================================
-- seeds.sql  (Phase 3 - 시드 데이터 / dummy data)
-- "더미데이터를 넣는 행위 = seed(시딩)". schema_v1.sql 실행 후에 돌린다.
--   psql:  \i sql/seeds.sql
--   docker: docker exec -i learn-db psql -U postgres -d todoapp < sql/seeds.sql
--
-- 구성:
--   1) 읽으면 결과가 예측되는 "이름있는" 소량 데이터 (JOIN/필터/집계 연습용)
--   2) generate_series 로 만드는 대량 task (300+, 페이징·인덱스 연습용)
--
-- 학습 포인트가 바로 먹히도록 일부러 배치해둔 것들:
--   · Archive 프로젝트  → 태스크 0개 (anti-join "태스크 없는 프로젝트" 연습)
--   · task 3·7·12       → 담당자 없음(assignee NULL) (미배정 태스크 연습)
--   · task 7·12         → 태그 없음 (LEFT JOIN task_tags + IS NULL 연습)
--   · task 1·2·5·8      → 태그 2개 ("두 태그 모두 가진 태스크" 연습)
--   · 댓글 없는 태스크   → EXISTS / NOT EXISTS 연습
--   · 지뢰 컬럼(project_name·assignee_name·tag_csv·tag_color) 일부러 채움
--
-- 여러 번 돌려도 깨끗하게 재시딩되도록 맨 위에서 TRUNCATE 한다.
-- =====================================================================

TRUNCATE comments, task_tags, tasks, tags, projects, users
  RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- users  (id 1~6)  address는 일부러 한 덩어리 문자열 (정규화 고민거리 / 지뢰)
--   정하늘(id 5)은 address NULL → users에서도 IS NULL 연습 가능
-- ---------------------------------------------------------------------
INSERT INTO users (name, email, address) VALUES
  ('김지원', 'jiwon@example.com',  '서울특별시 06236 강남구 테헤란로 123 4층'),
  ('이서연', 'seoyeon@example.com', '경기도 13494 성남시 분당구 판교로 50'),
  ('박준호', 'junho@example.com',  '부산광역시 48058 해운대구 센텀로 99'),
  ('최민서', 'minseo@example.com', '서울특별시 04524 중구 세종대로 110'),
  ('정하늘', 'haneul@example.com', NULL),
  ('윤도현', 'dohyun@example.com', '인천광역시 21999 연수구 송도과학로 32');

-- ---------------------------------------------------------------------
-- projects  (id 1~5)  Archive(id 5)는 일부러 태스크를 안 단다 (anti-join용)
-- ---------------------------------------------------------------------
INSERT INTO projects (owner_id, name) VALUES
  (1, 'Mobile App'),
  (2, 'Website Redesign'),
  (1, 'Backend API'),
  (3, 'Marketing Site'),
  (4, 'Archive');

-- ---------------------------------------------------------------------
-- tags  (id 1~6)  color는 원래 여기 있어야 할 컬럼 (2NF 정답 자리)
--   v1에서는 task_tags.tag_color(지뢰)에도 같은 값을 중복 저장한다
-- ---------------------------------------------------------------------
INSERT INTO tags (name) VALUES
  ('urgent'),   -- 1  #e53935
  ('home'),     -- 2  #43a047
  ('bug'),      -- 3  #fb8c00
  ('feature'),  -- 4  #1e88e5
  ('design'),   -- 5  #8e24aa
  ('backend');  -- 6  #6d4c41

-- ---------------------------------------------------------------------
-- tasks  (id 1~12, 이름있는 태스크)  지뢰 컬럼 일부러 채움
--   due_date 기준일: 오늘 = 2026-06-11 (지난/임박/미래 섞음)
-- ---------------------------------------------------------------------
INSERT INTO tasks
  (project_id, project_name, assignee_id, assignee_name, title, status, priority, tag_csv, due_date, position) VALUES
  (1, 'Mobile App',       1, '김지원', '로그인 화면 구현',     'doing', 4, 'urgent,feature', DATE '2026-06-20', 1),
  (1, 'Mobile App',       2, '이서연', '푸시 알림 버그 수정',   'todo',  5, 'urgent,bug',     DATE '2026-06-05', 2), -- 기한 지남
  (1, 'Mobile App',    NULL, NULL,     '앱 아이콘 디자인',     'todo',  2, 'design',         NULL,             NULL),-- 미배정
  (1, 'Mobile App',       1, '김지원', '회원가입 플로우',       'done',  3, 'feature',        DATE '2026-05-30', 3),
  (2, 'Website Redesign', 4, '최민서', '랜딩 페이지 리뉴얼',    'doing', 4, 'design,feature', DATE '2026-06-15', 1),
  (2, 'Website Redesign', 2, '이서연', '반응형 레이아웃',       'todo',  3, 'design',         DATE '2026-06-25', 2),
  (2, 'Website Redesign',NULL,NULL,    '접근성 점검',           'todo',  2, NULL,             NULL,             NULL),-- 미배정·태그없음
  (3, 'Backend API',      1, '김지원', '인증 토큰 갱신 API',    'doing', 5, 'backend,urgent', DATE '2026-06-12', 1),
  (3, 'Backend API',      3, '박준호', 'DB 인덱스 최적화',      'todo',  4, 'backend',        DATE '2026-07-01', 2),
  (3, 'Backend API',      3, '박준호', '로그 수집 파이프라인',  'done',  3, 'backend',        DATE '2026-05-20', 3),
  (4, 'Marketing Site',   6, '윤도현', '블로그 CMS 연동',       'todo',  2, 'feature',        DATE '2026-06-30', 1),
  (4, 'Marketing Site', NULL, NULL,    'SEO 메타태그 정리',     'done',  1, NULL,             DATE '2026-05-10', 2);-- 미배정·태그없음

-- ---------------------------------------------------------------------
-- task_tags  (이름있는 태스크의 태그 연결)  tag_color는 지뢰: tags.color 중복
--   task 7·12 는 일부러 연결 안 함 (태그 없는 태스크)
--   task 1·2·5·8 은 태그 2개 (두 태그 모두 가진 태스크 연습)
-- ---------------------------------------------------------------------
INSERT INTO task_tags (task_id, tag_id, tag_color) VALUES
  (1, 1, '#e53935'), (1, 4, '#1e88e5'),   -- urgent, feature
  (2, 1, '#e53935'), (2, 3, '#fb8c00'),   -- urgent, bug
  (3, 5, '#8e24aa'),                       -- design
  (4, 4, '#1e88e5'),                       -- feature
  (5, 5, '#8e24aa'), (5, 4, '#1e88e5'),   -- design, feature
  (6, 5, '#8e24aa'),                       -- design
  (8, 6, '#6d4c41'), (8, 1, '#e53935'),   -- backend, urgent
  (9, 6, '#6d4c41'),                       -- backend
  (10,6, '#6d4c41'),                       -- backend
  (11,4, '#1e88e5');                       -- feature

-- ---------------------------------------------------------------------
-- comments  (일부 태스크에만 달기 → EXISTS / NOT EXISTS 연습)
--   댓글 있는 태스크: 1, 2, 5, 8 / 나머지는 댓글 없음
-- ---------------------------------------------------------------------
INSERT INTO comments (task_id, author_id, body) VALUES
  (1, 2, '소셜 로그인도 이번 스프린트에 포함하나요?'),
  (1, 3, 'OAuth는 다음 스프린트로 미루는 게 좋겠어요.'),
  (2, 1, '재현 조건 확인했습니다. 백그라운드 진입 시에만 발생.'),
  (5, 2, '히어로 카피 시안 3개 공유드립니다.'),
  (8, 3, '리프레시 토큰 만료 정책부터 정해야 할 듯.'),
  (8, 1, '7일 슬라이딩 만료로 합의했습니다.');

-- =====================================================================
-- 여기까지가 "읽으면 결과가 보이는" 학습용 핵심 데이터.
-- 아래는 페이징·집계·인덱스 연습을 위한 대량 task (generate_series).
-- 지뢰 컬럼(project_name·assignee_name·tag_csv)도 같이 채운다.
-- Archive 프로젝트는 빼서(anti-join 연습 보존) 계속 비워둔다.
-- =====================================================================
INSERT INTO tasks
  (project_id, project_name, assignee_id, assignee_name, title, status, priority, tag_csv, due_date, position)
SELECT p.id, p.name,
       u.id, u.name,
       'task ' || g,
       (ARRAY['todo','doing','done'])[floor(random()*3+1)],
       floor(random()*5+1)::int,
       'urgent,home',
       (DATE '2026-06-11' + (floor(random()*60) - 30)::int),  -- 오늘 기준 ±30일
       g
FROM generate_series(1, 300) g
JOIN LATERAL (SELECT id, name FROM projects WHERE name <> 'Archive' ORDER BY random() LIMIT 1) p ON true
JOIN LATERAL (SELECT id, name FROM users                            ORDER BY random() LIMIT 1) u ON true;

-- 대량 task 에 태그 1~3개 무작위 연결 (N:M 조회 연습용). tag_color는 비워둠.
INSERT INTO task_tags (task_id, tag_id)
SELECT t.id, tg.id
FROM tasks t
JOIN LATERAL (
  SELECT id FROM tags ORDER BY random() LIMIT (floor(random()*3) + 1)::int
) tg ON true
WHERE t.title LIKE 'task %'                  -- 이름있는 태스크(1~12)는 건드리지 않음
ON CONFLICT (task_id, tag_id) DO NOTHING;    -- 복합 PK 중복 방지

-- ---------------------------------------------------------------------
-- 확인용 (실행하면 시딩 결과 요약이 보인다)
-- ---------------------------------------------------------------------
SELECT 'users'     AS table, count(*) FROM users
UNION ALL SELECT 'projects',  count(*) FROM projects
UNION ALL SELECT 'tags',      count(*) FROM tags
UNION ALL SELECT 'tasks',     count(*) FROM tasks
UNION ALL SELECT 'task_tags', count(*) FROM task_tags
UNION ALL SELECT 'comments',  count(*) FROM comments;

-- (인덱스 실험용으로 20만 건이 필요하면 위 generate_series(1, 300)을
--  generate_series(1, 200000) 으로 바꿔서 한 번 더 돌리면 된다 — Phase 3 마지막 단계)
