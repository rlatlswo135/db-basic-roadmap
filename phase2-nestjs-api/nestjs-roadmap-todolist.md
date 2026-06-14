# NestJS API 로드맵 (FE → 풀스택 · Phase 2)

> **전제:** Phase 1(DB 기초)을 마쳤다고 가정. 같은 도메인(User · Project · Task · Tag · Comment)을 그대로 이어갑니다.
>
> **목표:** SQL 감각을 잃지 않으면서 NestJS의 모듈/DI/계층 분리를 몸에 익히기. 마지막에 ORM으로 한 번 더 짜서 "raw SQL vs ORM"이 뭘 가려주고 뭘 망치는지 직접 비교.
>
> **순서:** 환경 → NestJS 골격 → raw SQL CRUD → 트랜잭션·N+1 → 인증/세션 → 백그라운드 잡 → ORM 재구현(비교)
> 엉성하게 짠 뒤 같은 코드를 ORM으로 다시 갈아엎는 흐름. Phase 1의 "지뢰 → 정규화" 패턴과 같음.
>
> **기본 규칙:** 모든 항목은 *산출물*이 나와야 끝난 겁니다.
> 산출물 = 동작하는 엔드포인트 / 테스트 / 관찰 노트 중 하나.
>
> **스택:** NestJS 10+ / Node 20+ / pnpm / `pg` 드라이버 (ORM 없음, Phase 7에서만 Prisma)

---

## Phase 0 — 환경 셋업 (반나절)

- [ ] Node 20+, pnpm 설치 확인 (`node -v`, `pnpm -v`)
- [ ] NestJS CLI: `pnpm add -g @nestjs/cli` → `nest new todoapp-api`
- [ ] Phase 1의 `docker-compose.yml`을 그대로 가져와 DB 띄우기
- [ ] `.env` + `@nestjs/config`로 DB 접속 정보 분리 (절대 코드에 박지 않기)
- [ ] `pnpm start:dev` → `GET /`가 200 뜨는지 확인

**산출물:** 헬스체크 엔드포인트 하나 (`GET /health` → `{ status: 'ok' }`)

---

## Phase 1 — NestJS 골격 이해 (개념 정리 + 코드로 확인)

> 프레임워크를 "마법"으로 두지 말고 *왜 이렇게 갈라놨나*를 한 문장씩 적어보기.

### 1-1. 개념 (내 말로 한 줄씩)
- [ ] **Module** — 기능 단위의 묶음. 왜 파일 하나에 다 안 두고 모듈로 쪼개나?
- [ ] **Controller vs Service vs Repository** — 각각 책임이 뭔가? (HTTP / 비즈니스 / DB)
- [ ] **DI (의존성 주입)** — `@Injectable()` + 생성자 주입. 왜 `new Service()` 안 하고 컨테이너가 주입하나? (테스트 용이성 한 줄로)
- [ ] **DTO** — `class-validator` + `class-transformer`. 왜 request body를 그대로 안 받고 한 번 거르나?
- [ ] **Pipe / Guard / Interceptor / ExceptionFilter** — 요청 한 번이 거치는 단계들. 각각 어디서 도나?
- [ ] **Exception 처리** — `throw new BadRequestException(...)` vs `try/catch`. Nest가 알아서 응답으로 바꿔주는 흐름

### 1-2. 손으로 깔기
- [ ] `nest g module users` / `nest g controller users` / `nest g service users`로 3종 세트 만들어보기
- [ ] `ValidationPipe`를 글로벌로 등록 (`main.ts`) — DTO 검증이 자동으로 도는 것 확인
- [ ] DTO에 일부러 잘못된 body를 보내서 **400이 자동으로 떨어지는 것** 확인 (직접 검증 코드 안 짜도 됨)
- [ ] 글로벌 `ExceptionFilter` 하나 만들어서 에러 응답 포맷 통일 (`{ statusCode, message, path }`)

**산출물:** 빈 껍데기 `users` 모듈 + DTO 검증 동작 스크린샷

---

## Phase 2 — DB 연결 (ORM 없이 직접)

> 여기가 이 로드맵의 핵심. ORM이 가려주던 걸 직접 만져봅니다.

- [ ] `pnpm add pg` + `@types/pg` (드라이버만)
- [ ] **DatabaseModule** 하나 만들어서 `pg.Pool`을 싱글톤으로 제공 (`Global` 모듈로)
  - 왜 Pool인가? — 매 요청마다 `new Client()` 하면 안 되는 이유 한 줄
- [ ] 간단한 헬퍼: `query<T>(sql, params): Promise<T[]>` 한 함수만
- [ ] **파라미터 바인딩 강제** — SQL 안에 `${variable}` 박지 않기. `$1, $2`만 사용 (SQL injection 한 번 직접 재현해보기)
- [ ] `GET /db-check` → `SELECT now()` 결과 반환되는지 확인

### 2-1. Repository 계층 직접 짜기
- [ ] `UsersRepository` 클래스 — `findById`, `findByEmail`, `create`, `update`, `delete` 정도만
- [ ] **`Service`는 `Repository`만 호출, `Controller`는 `Service`만 호출** — 이 규칙 깨지면 왜 골치 아픈지 한 줄
- [ ] Repository는 DB row(snake_case) ↔ 도메인 객체(camelCase) 변환 책임도 가짐

**산출물:** `UsersRepository`가 동작하는 `GET /users/:id` 엔드포인트

---

## Phase 3 — CRUD 엔드포인트 (5개 도메인 전부)

> Phase 1에서 만든 6개 테이블에 대응하는 엔드포인트를 처음부터 끝까지.
> **속도보다 일관성** — 한 도메인이라도 끝까지 제대로 짜면 나머지는 복붙.

### 3-1. Users (가장 단순한 것부터)
- [ ] `POST /users` — DTO 검증, email 중복 시 409
- [ ] `GET /users/:id` — 없으면 404 (`NotFoundException`)
- [ ] `GET /users` — 페이지네이션 (`?page=1&size=20`)
- [ ] `PATCH /users/:id` — 부분 업데이트 (`PartialType(CreateUserDto)`)
- [ ] `DELETE /users/:id` — soft delete vs hard delete 고민 한 줄

### 3-2. Projects
- [ ] CRUD 5종 + `GET /users/:id/projects` (사용자별 프로젝트 목록)
- [ ] 권한 체크: 본인 프로젝트만 수정/삭제 가능 (Guard로 빼볼 것)

### 3-3. Tasks (가장 무거움)
- [ ] CRUD + 필터: `?status=todo&assigneeId=1&projectId=2`
- [ ] **목록 조회 시 JOIN** — task + project.name + assignee.name 한 번에 (Phase 1의 J-2 패턴)
- [ ] **정렬**: `?sort=priority,-dueDate` 같은 문법을 SQL로 안전하게 변환 (whitelist 강제 — injection 막기)

### 3-4. Tags & Comments
- [ ] Tag CRUD + N:M 연결 엔드포인트: `POST /tasks/:id/tags` / `DELETE /tasks/:id/tags/:tagId`
- [ ] Comment CRUD — 항상 `task_id` 컨텍스트 (`POST /tasks/:id/comments`)

**산출물:** Postman/Bruno 컬렉션 1개 (모든 엔드포인트 통과)

---

## Phase 4 — 트랜잭션 · N+1 (raw SQL의 진짜 고통)

> ORM이 숨겨주던 걸 직접 만져봐야 ORM의 의미를 안다.

### 4-1. 트랜잭션 수동 관리
- [ ] **시나리오:** "프로젝트 삭제 시 그 안의 태스크/댓글까지 정리" — 한 트랜잭션으로 묶기
- [ ] `pg.Pool`에서 `connect()` → `BEGIN` → 여러 쿼리 → `COMMIT` / 에러 시 `ROLLBACK` → `release()` 직접 짜기
- [ ] **함정 직접 재현:** 트랜잭션 안에서 다른 메서드 호출하면서 그 메서드가 *다른 커넥션*을 잡아버리는 버그 (커넥션이 인자로 흐르지 않을 때) — `AsyncLocalStorage`로 푸는 패턴 검토만
- [ ] **Service 안에서 트랜잭션 시작이 옳은가, Controller인가?** — 한 줄 정리

### 4-2. N+1 직접 만들고 직접 고치기
- [ ] `GET /projects/:id` 응답에 `tasks` 배열을 넣는다고 가정 → 프로젝트 1번 + 태스크 N번 쿼리로 짜기
- [ ] 로그에 SQL 다 찍어서 **N+1이 실제로 도는 것** 눈으로 보기
- [ ] **해결 1:** `IN ($1, $2, ...)`로 한 번에 조회 후 앱에서 그룹핑
- [ ] **해결 2:** JOIN 한 방 + 앱에서 nested object로 재조립 (`task[]`를 `project` 안에 끼우기)
- [ ] 둘의 트레이드오프 한 줄: JOIN은 행 뻥튀기 / IN은 쿼리 2번 + 메모리 그룹핑

### 4-3. 페이지네이션의 함정
- [ ] OFFSET 페이지네이션의 한계 (큰 OFFSET일수록 느림) 직접 측정
- [ ] **커서 페이지네이션** (`WHERE id < lastId ORDER BY id DESC LIMIT 20`) 적용해보기

**산출물:** N+1 before/after 쿼리 로그 + 트랜잭션 동작 테스트

---

## Phase 5 — 인증 · 세션 (Phase 6 스케일링과 직결)

> 여기서 짠 세션 전략이 Phase 3(인프라)의 "stateless가 왜 필요한가" 문제로 그대로 이어집니다.

- [ ] `pnpm add bcrypt` — 비밀번호 해싱 (절대 평문 저장 금지)
- [ ] `POST /auth/signup` / `POST /auth/login` 두 엔드포인트
- [ ] **2가지 방식 다 짜보기** (이 비교가 Phase 3 인프라의 핵심 자극):

### 5-1. JWT 방식 (stateless)
- [ ] `@nestjs/jwt` + `@nestjs/passport`로 JWT 발급/검증
- [ ] `JwtAuthGuard` — `Authorization: Bearer ...` 헤더 파싱
- [ ] **장점:** 서버가 세션 저장 안 함 → 인스턴스 늘려도 됨
- [ ] **단점:** 로그아웃이 어려움 (블랙리스트 만들면 결국 stateful), 토큰 유출 시 만료까지 못 막음

### 5-2. 서버 세션 방식 (stateful)
- [ ] `express-session` + 메모리 스토어로 먼저 짜기
- [ ] **문제 직접 재현:** 앱 인스턴스 2개 띄우면 로그인이 한쪽에서만 유지됨 → "이래서 Redis 세션 스토어가 필요하구나" 깨달음
- [ ] `connect-redis`로 세션 스토어 교체 (Redis는 Phase 6에서 본격 다룸 — 여기선 띄워만)
- [ ] **장점:** 즉시 로그아웃 가능 / **단점:** 외부 의존성 + Redis 장애 = 전체 로그아웃

### 5-3. 권한 (Authorization)
- [ ] `RolesGuard` — `@Roles('admin')` 데코레이터로 라우트 보호
- [ ] **리소스 소유권 검사** — "이 프로젝트 정말 네 거 맞아?" (단순 role보다 흔한 패턴)

**산출물:** 두 방식 다 동작하는 코드 + "왜 JWT는 stateless라고 부르나" 한 단락 메모

---

## Phase 6 — 백그라운드 잡 (BullMQ)

> "응답은 빨리, 무거운 작업은 비동기로"가 실무 기본기.

- [ ] **시나리오 만들기:** "태스크에 댓글이 달리면 담당자에게 이메일 알림" (실제 이메일 전송은 콘솔 출력으로 mock)
- [ ] `pnpm add bullmq @nestjs/bullmq` + Redis 연결
- [ ] **Producer:** Comment 생성 시 큐에 잡 푸시
- [ ] **Consumer (Worker):** 잡을 받아 처리 (`@Processor()`)
- [ ] **실패 처리:** retry 3회 + exponential backoff
- [ ] **관찰:** Bull Board (`@bull-board/express`) 붙여서 큐 상태 UI로 보기
- [ ] **트랜잭션 함정:** "DB 커밋 전에 큐에 잡을 푸시하면?" — 롤백돼도 잡은 살아남는 버그 직접 재현 → outbox 패턴 개념만 메모

**산출물:** 댓글 달면 워커 로그에 "이메일 발송" 찍히는 것

---

## Phase 7 — ORM으로 다시 짜기 (비교 학습)

> 같은 기능을 Prisma로 갈아엎고 raw SQL 버전과 *나란히* 비교.

- [ ] `pnpm add prisma @prisma/client` + `npx prisma init`
- [ ] **기존 DB에서 schema 역공학:** `npx prisma db pull` (Phase 1의 v2 스키마가 그대로 들어옴)
- [ ] **CRUD 한 도메인만 옮겨보기** (Tasks 추천 — 가장 복잡했으니까)
- [ ] **직접 비교 노트 작성:**
  - 코드 라인 수 (raw vs Prisma)
  - JOIN 코드 (raw SQL vs `include` / `select`)
  - 트랜잭션 (`pg` 수동 vs `prisma.$transaction`)
  - N+1 — Prisma도 `include` 잘못 쓰면 똑같이 터지는지 확인
  - **타입 안전성** — TS 타입이 자동 생성되는 차이 체감
- [ ] **결론 한 단락:** "내 프로젝트에선 어느 쪽 쓸까, 그 이유는?"

**산출물:** `comparison-notes.md` (raw vs Prisma 항목별 비교표)

---

## Phase 8 — 테스트 · 문서화 (마무리)

- [ ] **단위 테스트:** Service 한 개 (Repository는 mock) — Jest
- [ ] **통합 테스트:** 실제 DB를 띄운 채 Controller → Service → Repository 한 줄로 테스트 (testcontainers 또는 docker-compose의 별도 DB)
  - 왜 mock DB 안 쓰나? — Phase 1 로드맵의 정신: "mock은 가짜 안심을 준다"
- [ ] **Swagger 자동 문서화:** `@nestjs/swagger` — DTO + 데코레이터로 OpenAPI 생성
- [ ] **로깅:** `pino` (Phase 3 인프라에서 그대로 이어 씀) + request-id로 한 요청의 모든 로그 묶기

**산출물:** Swagger UI 캡처 + 통합 테스트 1개 통과

---

## Phase 9 — 회고

- [ ] 가장 헷갈렸던 개념 3개와 깨진 시점 기록
- [ ] 다음 단계(Phase 3 인프라)에서 *부하 줄 대상 엔드포인트* 후보 3개 골라두기 — `GET /tasks?...` 같은 무거운 조회가 1순위
- [ ] "회사에서 받아 쓰던 API 1개"를 이제 NestJS로 직접 짜본다면 모듈 구조를 어떻게 잡을지 스케치

**산출물:** 회고 노트 + Phase 3에서 부하 줄 엔드포인트 후보 리스트

---

## 막히면 참고
- NestJS 공식 docs (특히 Fundamentals / Techniques 섹션)
- `node-postgres` (pg) 공식 docs — Pool / Client 차이 정도만 정확히
- BullMQ 공식 — 그림이 잘 돼있음
- Prisma는 공식 quickstart로 충분 (Phase 7에서만 짧게)

---

## 이 단계 끝낸 다음 읽을 책 / 자료
1. **NestJS in Action** (또는 공식 docs 정독) — 데코레이터·DI 컨테이너의 "왜"를 한 번 더
2. **Refactoring (Fowler)** — Service/Repository 경계가 흐려질 때 다시 펴는 책
3. **Building Microservices (Newman)** — 이걸로 자연스럽게 Phase 3 인프라로 넘어감
