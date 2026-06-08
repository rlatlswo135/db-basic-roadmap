# DB 기초 잡기 로드맵 (FE → 풀스택)

> **도메인:** 협업 Todo 앱 (User · Project · Task · Tag · Comment)
> 한 도메인으로 끝까지 갑니다. 개념이 누적돼요.
>
> **순서:** 관계형 모델 → ER → SQL → 트랜잭션 → 정규화
> 엉성한 스키마로 직접 쿼리·트랜잭션을 굴려보다가 불편함을 느낀 뒤, 마지막에 정규화로 고칩니다.
>
> **기본 규칙:** 모든 항목은 *산출물*이 나와야 끝난 겁니다. 눈으로 읽고 체크만 치지 않기.
> 산출물 = `.sql` 파일 / ERD 이미지 / 관찰 노트 중 하나.
>
> **DB:** PostgreSQL 16 (표준을 엄격히 지켜서 나쁜 습관이 안 듦)

---

## Phase 0 — 환경 셋업 (반나절)

- [ ] Docker로 PostgreSQL 띄우기
  ```bash
  docker run --name learn-db -e POSTGRES_PASSWORD=devpass \
    -e POSTGRES_DB=todoapp -p 5432:5432 -d postgres:16
  ```
- [ ] 클라이언트 연결: DBeaver / TablePlus, 또는
  `docker exec -it learn-db psql -U postgres -d todoapp`
- [ ] 연결 확인: `SELECT version();`

**산출물:** 접속되는 DB 하나

---

## Phase 1 — 관계형 모델 (여기서 전체 스키마를 다 만든다)

이 단계가 로드맵의 척추예요. 여기서 만든 모델이 마지막 정규화까지 그대로 살아남습니다.

### 1-1. 개념 정리 (내 말로 한 줄씩)
- [ ] 릴레이션(테이블) / 튜플(행) / 속성(컬럼) / 도메인(값의 범위)
- [ ] 키: 기본키(PK) / 외래키(FK) / 후보키 / **대리키(surrogate, 예: 자동증가 id) vs 자연키(natural)**
- [ ] 카디널리티: 1:1, 1:N, N:M — 우리 도메인에서 각각 어디에 해당하나?
- [ ] 제약: `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, FK의 `REFERENCES`
- [ ] **N:M은 그대로 못 만든다** → 교차 테이블(junction table)로 푼다. (Task ↔ Tag → `task_tags`)

### 1-2. 도메인을 관계로 분해
- [ ] 문장으로 적고 카디널리티 표시:
  - User 1:N Project (한 사람이 여러 프로젝트 소유)
  - Project 1:N Task
  - User 1:N Task (담당자) — 선택적(담당자 없을 수 있음)
  - Task N:M Tag → `task_tags`
  - Task 1:N Comment

### 1-3. 전체 스키마 v1 만들기 (⚠️ 일부러 결함을 심어둠)

> 아래 `⚠️ 지뢰` 표시된 컬럼들은 **일부러 잘못 설계한 것**입니다.
> Phase 5(정규화)에서 이걸 1NF/2NF/3NF 기준으로 직접 고칠 거예요.
> 그 전까지는 이 엉성한 스키마로 쿼리와 트랜잭션을 굴려보며 불편함을 체감합니다.

```sql
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

CREATE TABLE task_tags (             -- N:M 교차 테이블 (올바른 방식)
  task_id   BIGINT NOT NULL REFERENCES tasks(id),
  tag_id    BIGINT NOT NULL REFERENCES tags(id),
  tag_color TEXT,                    -- ⚠️ 지뢰: tag_id에만 종속 (→ 2NF에서 tags로 이동)
  PRIMARY KEY (task_id, tag_id)
);

CREATE TABLE comments (
  id         BIGSERIAL PRIMARY KEY,
  task_id    BIGINT NOT NULL REFERENCES tasks(id),
  author_id  BIGINT NOT NULL REFERENCES users(id),
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- [ ] 위 6개 테이블 전부 생성
- [ ] FK가 실제로 동작하는지 확인: 없는 `project_id`로 `tasks` INSERT 시도 → 에러 나는 것 보기
- [ ] 심어둔 지뢰 4개가 각각 왜 문제일지 *미리* 한 줄씩 메모만 해두기 (정답은 Phase 5에서 맞춰봄)

**산출물:** `schema_v1.sql` + 지뢰 4개에 대한 추측 메모

---

## Phase 2 — ER 다이어그램

- [ ] 엔티티 5개와 관계를 그림으로: User · Project · Task · Tag · Comment
- [ ] N:M(Task–Tag)이 `task_tags`로 풀린 모습이 그림에 드러나게
- [ ] 도구: [dbdiagram.io](https://dbdiagram.io) — 코드로 그려서 무료, 빠름. v1 스키마를 그대로 옮겨 그리기

**산출물:** 전체 ERD 이미지 1장

---

## Phase 3 — SQL (볼륨 가장 큰 파트, 막 짜본다)

### 시드 데이터부터
- [ ] 사용자/프로젝트/태그 소량 + 태스크 대량(300+). 대량은 `generate_series`로:
  ```sql
  INSERT INTO tasks (project_id, project_name, assignee_id, assignee_name,
                     title, status, priority, tag_csv)
  SELECT p.id, p.name,
         u.id, u.name,
         'task ' || g,
         (ARRAY['todo','doing','done'])[floor(random()*3+1)],
         floor(random()*5+1),
         'urgent,home'
  FROM generate_series(1, 300) g
  JOIN LATERAL (SELECT id, name FROM projects ORDER BY random() LIMIT 1) p ON true
  JOIN LATERAL (SELECT id, name FROM users    ORDER BY random() LIMIT 1) u ON true;
  ```
  (지뢰 컬럼들도 일부러 같이 채웁니다 — 정규화 때 고칠 대상이니까)

### 쿼리 전부 해보기
- [ ] **기본 CRUD:** INSERT / SELECT / UPDATE / DELETE
- [ ] **필터·정렬:** WHERE, ORDER BY, LIMIT, LIKE, IN, BETWEEN
- [ ] **JOIN 전부:** INNER / LEFT / SELF JOIN
  - "각 프로젝트의 미완료 태스크 목록" (projects ⨝ tasks)
  - "담당자가 없는 태스크" (LEFT JOIN + IS NULL)
- [ ] **집계:** GROUP BY, HAVING, COUNT/SUM/AVG
  - "사용자별 완료율", "프로젝트별 태스크 수 (5개 초과만)"
- [ ] **서브쿼리:** WHERE 절 / FROM 절(파생 테이블) / 상관 서브쿼리 / EXISTS
  - "전체 평균보다 태스크가 많은 프로젝트"
- [ ] **N:M 조회:** `task_tags` 경유
  - "특정 태그가 달린 태스크"
  - "두 태그를 *모두* 가진 태스크" (의외로 헷갈림 — 좋은 연습)
- [ ] **(보너스) 윈도우 함수:** ROW_NUMBER, RANK
  - "프로젝트별 최신 태스크 3개씩"
- [ ] **인덱스 맛보기:** 태스크를 20만 건으로 늘린 뒤, 자주 거는 WHERE 컬럼에 인덱스 전/후 `EXPLAIN ANALYZE` 비교 (Seq Scan → Index Scan 바뀌는 것 관찰)

**산출물:** `queries.sql` (주제별 모음) + 인덱스 전/후 EXPLAIN 캡처

---

## Phase 4 — 트랜잭션 (동시성 직접 깨뜨려보기)

psql 창을 **2개** 띄워놓고 진행하면 제일 잘 와닿아요.

- [ ] ACID 한 줄씩 정리
- [ ] BEGIN / COMMIT / ROLLBACK 직접 써보기
- [ ] **Lost Update 재현:** 두 세션이 같은 `task`의 `status`를 동시에 UPDATE → 한쪽 변경이 사라지는 것 관찰
- [ ] **격리 수준** 바꿔가며 현상 재현·관찰
  - `SET TRANSACTION ISOLATION LEVEL READ COMMITTED | REPEATABLE READ | SERIALIZABLE;`
  - Non-repeatable Read / Phantom Read 가 각 레벨에서 보이는지 / 막히는지
  - (참고: Postgres 기본은 READ COMMITTED)
- [ ] **락 관찰:** 한 세션이 UPDATE 후 미커밋일 때, 다른 세션의 같은 행 UPDATE가 멈추는 것 보기
- [ ] **데드락 만들기:** 세션A는 행1→행2, 세션B는 행2→행1 순서로 잠가 데드락 유발 → DB가 한쪽을 죽이는 것 관찰

**산출물:** "이 격리수준에선 이게 보이고 저건 막힌다" 관찰 노트

---

## Phase 5 — 정규화 (이제 Phase 1의 지뢰를 제거한다)

엉성한 v1으로 실컷 굴려봤으니, 불편했던 지점을 정규형 기준으로 고칩니다.

- [ ] **1NF (다중값 제거):** `tasks.tag_csv` ('urgent,home') → 이미 있는 `task_tags`로 데이터 이관 후 `tag_csv` 컬럼 DROP
  - 왜? 쉼표 목록은 검색·수정·정합성이 다 깨짐 ("urgent 태그 달린 태스크"를 LIKE로 긁어야 했던 고통 회상)
- [ ] **2NF (부분 종속 제거):** `task_tags.tag_color`는 복합키 `(task_id, tag_id)` 중 `tag_id`에만 종속 → `tags.color`로 이동 후 DROP
- [ ] **3NF (이행 종속 제거):** `tasks.project_name`(→project_id→projects), `tasks.assignee_name`(→assignee_id→users) → 둘 다 DROP, 필요하면 JOIN으로 가져오기
- [ ] **추가 정리:** `tasks.status` 자유 텍스트 → `CHECK (status IN ('todo','doing','done'))` 로 조이기 (또는 상태 lookup 테이블)
- [ ] **users.address** 분해 고민: 검색·집계가 필요하면 city/zipcode 분리, 아니면 그대로 둬도 됨 (정규화는 무조건 쪼개는 게 아니라 *판단*이라는 걸 체감)
- [ ] 정규화된 `schema_v2.sql` 완성
- [ ] **검증:** Phase 3에서 짠 쿼리 1~2개를 v2에서 다시 돌려, 쿼리가 단순해지거나 정합성 문제가 사라지는지 확인

**산출물:** `schema_v2.sql` + v1 vs v2 비교 노트 (지뢰 4개가 각각 어떤 정규형 위반이었는지 정답 맞춰보기)

---

## Phase 6 — 종합 & 회고 (FE → BE 연결)

- [ ] 느린 쿼리 1개 골라 인덱스/재작성으로 개선, before/after 측정
- [ ] **평소 회사에서 받아 쓰던 API 응답 1개**를 골라, 그 뒤에 어떤 테이블·JOIN·쿼리가 있을지 역설계 ← 받아 쓰던 데이터의 "뒤"가 보이기 시작하는 포인트

**산출물:** 회고 노트 + API 1개 역설계 스케치

---

## 막히면 참고
- PostgreSQL 공식 튜토리얼 (영문, 짧고 정확)
- `EXPLAIN ANALYZE`는 처음엔 "Seq Scan vs Index Scan"만 구분하면 충분
- 트랜잭션 격리수준은 글보다 두 세션 직접 돌려보는 게 10배 빠름

---

## 이 로드맵 다 끝낸 다음 읽을 책 (순서대로)
1. **SQL 안티패턴** — 설계 판단 기준. 직접 짠 v1/v2 스키마를 "이게 맞았나" 검증하듯 읽힘.
2. **Real MySQL 8.0 (1권 중심)** — 인덱스·트랜잭션·실행계획이 *왜* 그렇게 도는지. MySQL 기반이지만 핵심 개념은 Postgres에 그대로 전이됨 (+ Postgres 공식 문서 곁들이기).
3. **친절한 SQL 튜닝** — "왜 느린가"에 대한 직관. 오라클 예제지만 원리는 전이됨.
4. **데이터 중심 애플리케이션 설계 (DDIA)** — 이미 보유 중. 위 3권 거치고 나면 완전히 다르게 읽히는 캡스톤.
