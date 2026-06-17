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

## Phase 1 — 관계형 모델 (여기서 전체 스키마를 다 만든다) -- ✅

이 단계가 로드맵의 척추예요. 여기서 만든 모델이 마지막 정규화까지 그대로 살아남습니다.

### 1-1. 개념 정리 (내 말로 한 줄씩)
- [ ] 릴레이션(테이블) / 튜플(행) / 속성(컬럼) / 도메인(값의 범위)
- [ ] 키: 기본키(PK) / 외래키(FK) / 후보키 / **대리키(surrogate, 예: 자동증가 id) vs 자연키(natural)**
- [ ] 카디널리티: 1:1, 1:N, N:M — 우리 도메인에서 각각 어디에 해당하나?
- [ ] 제약: `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, FK의 `REFERENCES`
- [ ] **데이터 타입 감각:** 왜 이 컬럼이 이 타입인가 — `BIGINT`(id) / `TEXT`(문자) / `DATE` vs `TIMESTAMPTZ`(**타임존 포함**, 그래서 `created_at`은 TIMESTAMPTZ) / `BOOLEAN` / `NUMERIC` vs `FLOAT`(**돈·정확값엔 FLOAT 금지**). 캐스팅 `::` (예: `'3'::int`)
- [ ] **FK 참조 동작:** 부모를 지우면 자식은? — `ON DELETE RESTRICT`(기본, 막음) / `CASCADE`(같이 삭제) / `SET NULL`. "프로젝트 삭제 시 그 태스크는 어떻게 돼야 하나" 한 줄 정해보기
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
- [ ] FK 참조 동작 확인: 태스크가 달린 `project`를 DELETE 시도 → 기본(RESTRICT)이라 막히는 것 보기 (CASCADE였다면 어떻게 달라질지 한 줄 메모)
- [ ] 심어둔 지뢰 4개가 각각 왜 문제일지 *미리* 한 줄씩 메모만 해두기 (정답은 Phase 5에서 맞춰봄)

**산출물:** `schema_v1.sql` + 지뢰 4개에 대한 추측 메모

---

## Phase 2 — ER 다이어그램

- [ ] 엔티티 5개와 관계를 그림으로: User · Project · Task · Tag · Comment
- [ ] N:M(Task–Tag)이 `task_tags`로 풀린 모습이 그림에 드러나게
- [ ] 관계선에 **PK/FK 표시 + 카디널리티(까마귀발 표기: 1, N)**까지 드러나게 — "어느 쪽이 1이고 어느 쪽이 N인지" 한눈에
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
  JOIN LATERAL (SELECT id, name FROM projects WHERE g > 0 ORDER BY random() LIMIT 1) p ON true
  JOIN LATERAL (SELECT id, name FROM users    WHERE g > 0 ORDER BY random() LIMIT 1) u ON true;
  ```
  (지뢰 컬럼들도 일부러 같이 채웁니다 — 정규화 때 고칠 대상이니까)
- [ ] **`task_tags`도 채우기** (J-4 N:M 조회 연습용). 태스크마다 태그 1~3개를 무작위로 연결:
  ```sql
  INSERT INTO task_tags (task_id, tag_id)
  SELECT t.id, tg.id
  FROM tasks t
  JOIN LATERAL (
    SELECT id FROM tags ORDER BY random() LIMIT (floor(random()*3)+1)::int
  ) tg ON true
  ON CONFLICT (task_id, tag_id) DO NOTHING;   -- 복합 PK 중복 방지
  ```
  > ⚠️ 이러면 태그가 `tag_csv`(지뢰)와 `task_tags`(정답) **두 군데**에 살게 됩니다.
  > 일부러 그렇게 둡니다 — "같은 데이터가 두 곳에 있는 불편함"이 바로 Phase 5(1NF)에서 고칠 대상이거든요.

### 쿼리 전부 해보기

> 각 항목 = "우리 Todo 도메인에 맞는 쿼리 1개 작성"이 산출물. 눈으로 읽고 체크만 치지 않기.

#### 3-0. 먼저 머리에 넣을 개념 (쿼리 짜기 전에 — 아래 절들 하면서 체감됨)
- [v] **선언적·집합 기반 사고:** "어떻게 루프 돌까"가 아니라 "무슨 집합을 원하나"를 기술 → 실행 방법은 옵티마이저가 정함. (FE의 `for`문 감각 버리기)
- [v] **논리적 실행 순서:** `FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT`
  - 이게 "왜 WHERE에선 SELECT 별칭을 못 쓰나(아직 SELECT 전)", "WHERE vs HAVING 차이(집계 전/후)", "ORDER BY에선 왜 별칭이 되나(SELECT 후)"를 전부 설명함. **아래 모든 절의 뼈대.**
- [v] **NULL = 3값 논리:** 참/거짓이 아니라 참/거짓/**UNKNOWN**. `x = NULL`은 항상 안 맞음 → 반드시 `IS NULL`. `NOT IN (..., NULL)`이 통째로 빈 결과가 되는 함정 직접 재현
- [v] **GROUP BY 규칙:** SELECT의 비(非)집계 컬럼은 전부 GROUP BY에 있어야 함 (어기면 에러 — 가장 흔한 첫 실수)

#### 3-1. 기본 CRUD
- [v] INSERT — 단일 행 / 여러 행 한 번에 (`VALUES (...), (...), ...`)
- [v] INSERT ... RETURNING id — 방금 만든 행의 PK 돌려받기
- [v] SELECT — 전체(`*`) vs 필요한 컬럼만 (실무선 `*` 지양하는 이유 체감)
- [v] UPDATE — 특정 태스크 `status` 변경 (WHERE 꼭 붙이기)
- [v] DELETE — 특정 comment 삭제 (WHERE 없는 DELETE/UPDATE가 왜 무서운지 한 줄 메모)

#### 3-2. SELECT 다듬기 (컬럼 가공)
- [v] 별칭 `AS` — `title AS task_title`
- [v] DISTINCT — "태스크가 하나라도 있는 `project_id` 목록"
- [v] 계산·표현식 컬럼 — `priority * 10`, 문자열 연결 `project_name || ' / ' || title`
- [v] CASE WHEN — `status`('todo'/'doing'/'done')를 한글 라벨로 매핑
- [v] COALESCE — `assignee_name`이 NULL이면 '미배정'으로 치환

#### 3-3. WHERE (필터)
- [v] 비교 연산자 — `priority >= 4`, `status <> 'done'`
- [v] AND / OR / NOT + 괄호로 우선순위 — "priority 높고(>=4) 아직 안 끝난 것"
- [v] IN / NOT IN — `status IN ('todo','doing')`
- [v] BETWEEN — `due_date BETWEEN '...' AND '...'`
- [v] LIKE / ILIKE + 와일드카드(`%`, `_`) — title 검색 (ILIKE = 대소문자 무시)
- [v] IS NULL / IS NOT NULL — "담당자 없는 태스크" (`assignee_id IS NULL`)
- [v] 날짜 비교 — `due_date < now()` (기한 지난 태스크)

#### 3-4. 정렬·페이징
- [v] ORDER BY 단일/복수 컬럼, ASC/DESC — `priority DESC, due_date ASC`
- [v] NULLS FIRST / NULLS LAST — 마감일 없는 태스크를 뒤로
- [v] LIMIT / OFFSET — 페이지네이션 (10개씩 2페이지째)

#### 3-5. 집계 (GROUP BY)
- [v] COUNT / SUM / AVG / MIN / MAX — 한 번씩
- [v] GROUP BY — "프로젝트별 태스크 수"
- [v] HAVING — "태스크 5개 초과 프로젝트만" (WHERE와 위치/시점 차이 체감)
- [v] 조건부 집계 — "사용자별 완료율" (`COUNT(*) FILTER (WHERE status='done')` 또는 `AVG((status='done')::int)`)
- [v] COUNT(*) vs COUNT(컬럼) 차이 — NULL이 빠지는 것 직접 확인

#### 3-6. 서브쿼리 · CTE
- [v] WHERE 절 서브쿼리 — "전체 평균 priority보다 높은 태스크"
- [v] FROM 절 파생 테이블 — 프로젝트별 집계를 다시 필터
- [v] 상관 서브쿼리(correlated) — 바깥 행마다 도는 것 체감
- [v] EXISTS / NOT EXISTS — "댓글이 하나라도 달린 태스크" / "안 달린 태스크"
- [v] IN-서브쿼리 vs JOIN — 같은 결과를 둘 다로 짜보고 비교
- [v] **CTE (`WITH` 절):** 위 FROM 파생테이블을 `WITH 이름 AS (...)`로 빼서 가독성 비교 — 길고 중첩된 쿼리를 단계로 쪼개는 현대식 기본기

#### 3-7. 집합 연산
- [v] UNION vs UNION ALL — 결과 행 수 비교로 **중복 제거 비용** 체감 (중복 신경 안 쓰면 ALL이 빠름)
- [v] INTERSECT — "두 조건을 동시에 만족하는 태스크"
- [v] EXCEPT — "A엔 있고 B엔 없는" 차집합

---

### JOIN 집중 (실무에서 제일 많이 쓰는 부분 — 따로 뺌)

> 화면 하나 그리려면 거의 항상 2~4개 테이블을 합쳐야 함. **종류**보다 **상황별 패턴**이 본론.

#### J-1. 종류별 한 번씩
- [v] INNER JOIN — "프로젝트 + 그 프로젝트의 태스크" (양쪽 다 있는 것만)
- [v] LEFT JOIN — "모든 프로젝트 + 태스크" (태스크 0개 프로젝트도 나오게)
- [v] RIGHT JOIN — LEFT를 뒤집으면 같다는 것만 확인 (실무선 LEFT로 통일하는 이유)
- [v] SELF JOIN — "같은 프로젝트에 속한 다른 태스크 짝" (`tasks t1 ⨝ tasks t2 ON t1.project_id=t2.project_id AND t1.id<>t2.id`)
- [v] CROSS JOIN — 카티전 곱이 뭔지 작은 데이터로 한 번

#### J-2. 자주 쓰는 상황 (이게 본론)

> *원하는 그림* = "무슨 화면/목적이냐"를 한 줄로. *힌트* = 방향만. 시드(이름있는 task 12 + 대량 300).

- [v] **부모+자식 한 줄에** — "프로젝트명 + 태스크 제목"
  - *원하는 그림:* 태스크 목록인데 각 태스크가 **어느 프로젝트 소속인지**까지 같이 보이기. (지금 tasks엔 `project_id` 숫자뿐이라 사람은 못 알아봄 → 이름으로 바꿔 보여주기)
  - *힌트:* tasks의 그 숫자를 projects 쪽이랑 이어주면 이름이 딸려 온다
- [v] **3개 이상 JOIN** — `tasks + projects + users` (태스크 / 프로젝트명 / 담당자명 한 번에)
  - *원하는 그림:* 태스크 보드 한 줄처럼 — **"이 태스크 / 이 프로젝트 / 이 담당자"**가 한눈에. 테이블을 두 번 이어붙이는 연습
  - *힌트:* 담당자가 없는 태스크(3·7·12)는 이때 어떻게 될지 먼저 생각하고 돌려보기 (안 보이면 왜?)
- [v] **자식 없는 부모 찾기 (anti-join)** — "태스크가 하나도 없는 프로젝트" (LEFT JOIN + IS NULL)
  - *원하는 그림:* **텅 빈 프로젝트만** 골라내기 (정리·아카이브 대상 찾는 느낌). 정답은 `Archive` 하나
  - *힌트:* 일단 다 이어붙인 다음, **짝이 안 맞은 쪽**만 남기면 된다
- [ ] **담당자 없는 태스크** — LEFT JOIN users + IS NULL (그냥 `assignee_id IS NULL`과 결과 비교)
  - *원하는 그림:* **아직 아무도 안 맡은 태스크**만 추리기 (배정 회의용 목록). 정답은 3건
  - *힌트:* 두 갈래로 풀 수 있다 — ① 그 컬럼이 비었는지 직접 보기 ② 사람이랑 이어붙였는데 짝이 없는 경우. 둘 결과가 같은지 비교해보기
- [ ] **JOIN + 집계** — "프로젝트별 태스크 수" (INNER면 0개가 사라짐 → LEFT JOIN이라야 0도 포함)
  - *원하는 그림:* 프로젝트별 태스크 개수 대시보드. 단 **0개짜리 프로젝트도 "0"으로** 보여야 함 (`Archive`가 빠지면 안 됨)
  - *힌트:* 그냥 이어붙여 세면 0개짜리가 사라진다 → 어떤 JOIN이라야 살아남나. 그리고 *무엇을* 세느냐도 결과를 바꾼다
- [ ] **JOIN + 필터** — "특정 사용자가 담당인 미완료 태스크 + 프로젝트명"
  - *원하는 그림:* **"한 사람의 할 일 목록"** — 특정 담당자가 맡았고 아직 진행 중인 태스크만, 프로젝트명까지. (예: 김지원의 안 끝난 일)
  - *힌트:* 이어붙이기 + 거르기를 같이. 거르는 조건은 *사람*과 *상태* 두 개

#### J-3. 자주 틀리는 포인트
- [ ] **ON vs WHERE** — LEFT JOIN에서 오른쪽 테이블 조건을 WHERE에 두면 사실상 INNER로 변하는 함정 직접 재현
- [ ] **행 뻥튀기(곱집합)** — N:M JOIN 후 COUNT가 부풀려지는 것 관찰 → `DISTINCT` 또는 먼저 집계 후 JOIN
- [ ] **USING vs ON** — 컬럼명이 같을 때 USING 축약 (참고만)

#### J-4. N:M 조회 (`task_tags` 경유)
- [ ] "특정 태그가 달린 태스크" — `tasks ⨝ task_tags ⨝ tags`
- [ ] "한 태스크에 달린 태그 전부" — 반대 방향
- [ ] "두 태그를 *모두* 가진 태스크" — `GROUP BY task_id HAVING COUNT(*)=2` / self-join / INTERSECT 중 한 가지 (의외로 헷갈림 — 좋은 연습)
- [ ] "태그가 하나도 없는 태스크" — LEFT JOIN task_tags + IS NULL

---

### 그 외
- [ ] **(보너스) 윈도우 함수:** ROW_NUMBER / RANK / DENSE_RANK
  - "프로젝트별 최신 태스크 3개씩", "프로젝트 내 priority 순위"
- [ ] **인덱스 개념:** B-tree 한 장 그림으로 이해 — PK엔 자동 생성됨 / 읽기↑ 대신 **쓰기·용량↓**(공짜 아님) / 복합 인덱스는 **컬럼 순서**가 중요 / `WHERE`에 함수·연산 씌우면 인덱스 안 탐
- [ ] **인덱스 맛보기(실험):** 태스크를 20만 건으로 늘린 뒤, 자주 거는 WHERE 컬럼에 인덱스 전/후 `EXPLAIN ANALYZE` 비교 (Seq Scan → Index Scan 바뀌는 것 관찰)

**산출물:** `queries.sql` (주제별 모음) + 인덱스 전/후 EXPLAIN 캡처

---

## Phase 4 — 트랜잭션 (동시성 직접 깨뜨려보기)

psql 창을 **2개** 띄워놓고 진행하면 제일 잘 와닿아요.

- [ ] ACID 한 줄씩 정리
- [ ] BEGIN / COMMIT / ROLLBACK 직접 써보기
- [ ] **Lost Update 재현 (read-modify-write):** 두 세션이 같은 `task`의 `position`을 **읽고 → +1 해서 쓰기**
  - 세션A `SELECT position` (예: 10) → 세션B `SELECT position` (똑같이 10) → A가 `UPDATE ... SET position=11` → B도 `UPDATE ... SET position=11`
  - 결과는 12가 아니라 **11** — A가 더한 +1이 통째로 증발. (`SET position=position+1` 블라인드 쓰기로 바꾸면 왜 안 사라지는지도 비교)
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
