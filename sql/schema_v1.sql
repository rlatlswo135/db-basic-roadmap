-- =====================================================================
-- schema_v1.sql  (Phase 1)
-- 일부러 결함(⚠️ 지뢰)을 심어둔 첫 스키마. Phase 5에서 정규화로 고친다.
--   psql:  \i sql/schema_v1.sql   또는 파일 내용 붙여넣기
-- =====================================================================

CREATE TABLE users (
  id      BIGSERIAL PRIMARY KEY,
  name    TEXT NOT NULL,
  email   TEXT NOT NULL UNIQUE,
  address TEXT                       -- 도시+우편번호+상세주소가 한 덩어리 (고민거리)
);

CREATE TABLE projects (
  id         BIGSERIAL PRIMARY KEY,
  owner_id   BIGINT NOT NULL REFERENCES users(id),
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tags (
  id   BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

CREATE TABLE tasks (
  id            BIGSERIAL PRIMARY KEY,
  project_id    BIGINT NOT NULL REFERENCES projects(id),
  project_name  TEXT,                -- ⚠️ 지뢰: projects.name 중복 (→ 3NF에서 제거)
  assignee_id   BIGINT REFERENCES users(id),
  assignee_name TEXT,                -- ⚠️ 지뢰: users.name 중복 (→ 3NF에서 제거)
  title         TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'todo',  -- 자유 텍스트, 제약 없음 (→ CHECK로 조일 것)
  priority      INT  NOT NULL DEFAULT 3,
  tag_csv       TEXT,                -- ⚠️ 지뢰: 'urgent,home' 쉼표 목록 (→ 1NF에서 제거)
  due_date      DATE,
  position      INT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- ✊🏻 project_name, assignee_name 컬럼은 project조인시에 가져올수있는부분같은데 또 선언되어있어서 문제되보임
-- ✊🏻 tag_scv 는 뭐가문제인지 모르겠는데,,

CREATE TABLE task_tags (             -- N:M 교차 테이블 (올바른 방식)
  task_id   BIGINT NOT NULL REFERENCES tasks(id),
  tag_id    BIGINT NOT NULL REFERENCES tags(id),
  tag_color TEXT,                    -- ⚠️ 지뢰: tag_id에만 종속 (→ 2NF에서 tags로 이동)
  PRIMARY KEY (task_id, tag_id)
);
-- ✊🏻 tag_color는 tag테이블에서 가져야할 컬럼같음.

CREATE TABLE comments (
  id         BIGSERIAL PRIMARY KEY,
  task_id    BIGINT NOT NULL REFERENCES tasks(id),
  author_id  BIGINT NOT NULL REFERENCES users(id),
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
