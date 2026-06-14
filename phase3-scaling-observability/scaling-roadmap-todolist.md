# 스케일링 · 관찰성 로드맵 (FE → 풀스택 · Phase 3)

> **전제:** Phase 2(NestJS API)를 마쳤다고 가정. 그때 만든 API에 직접 부하를 줘서 깨뜨립니다.
>
> **목표:** "Redis 캐싱 = 좋은 것" 같은 책 지식이 아니라 **"내가 직접 부하 줘서 깨뜨려보고, 측정으로 효과 확인한"** 경험을 쌓기.
>
> **순서:** 부하 도구 → 관찰성(측정 인프라) → DB 병목 → 캐싱 → 커넥션 풀링 → 수평 확장 → Read Replica → 회고
> **핵심 사이클:** *부하 → 깨짐 → 측정 → 고침 → 다시 부하*. 이 사이클을 안 돌리면 인프라 학습은 책 읽기로 끝남.
>
> **기본 규칙:** 모든 항목은 *측정치*가 나와야 끝난 겁니다.
> 산출물 = before/after 그래프 / 부하 리포트 / 관찰 노트 중 하나. "그냥 좋아졌다"는 금지.
>
> **스택:** docker-compose / k6 / Prometheus / Grafana / Redis / pgbouncer / nginx
> **선 긋기:** k8s 없음. 모든 건 docker-compose 한 파일 안에서.

---

## Phase 0 — 환경 셋업 (반나절)

- [ ] Phase 2의 NestJS API를 그대로 docker화 (`Dockerfile` 작성)
- [ ] `docker-compose.yml` 하나에 `app` + `postgres` + `redis` 묶기
- [ ] `docker compose up -d` → 세 컨테이너 다 뜨고 API가 외부에서 호출되는 것 확인
- [ ] 부하 줄 대상 엔드포인트 3개 골라두기 (Phase 2 회고에서 골라둔 것)
  - 추천: `GET /tasks?...` (JOIN 무거움) / `GET /projects/:id` (N+1 가능성) / `POST /auth/login` (해싱 무거움)

**산출물:** `docker compose ps`에 3개 다 뜨는 스크린샷

---

## Phase 1 — 부하 도구 (k6) — **여기를 먼저!**

> 인프라 학습의 첫 단추. 이게 없으면 모든 게 추측이고 책 지식임.

### 1-1. k6 기초
- [ ] k6 설치 (`brew install k6` 또는 docker image)
- [ ] **첫 스크립트:** `GET /tasks?...`에 VU 10명, 30초 부하
- [ ] **읽어야 할 지표 3개만 먼저:** `http_req_duration` (p95) / `http_reqs` (RPS) / `http_req_failed` (에러율)
- [ ] 부하 주는 중 `docker stats`로 app/postgres의 CPU/메모리 동시에 관찰

### 1-2. 부하 시나리오 패턴
- [ ] **Smoke test:** VU 1명, 1분 — 정상 동작 확인용
- [ ] **Load test:** VU 50명, 5분 — 평상시 트래픽 시뮬레이션
- [ ] **Stress test:** VU 0→200 ramping — *어디서부터 깨지는지* 찾기 (이게 핵심)
- [ ] **Spike test:** VU 5명 → 갑자기 100명 → 5명 — 급증 회복력
- [ ] 4개 시나리오를 같은 엔드포인트에 돌려, **깨지는 임계점** 측정

### 1-3. 기준선(baseline) 확정
- [ ] **튜닝 시작 전** 현재 시스템의 한계를 숫자로 박아둠 (RPS, p95, 에러율)
- [ ] 이 숫자가 앞으로 모든 개선의 비교 기준

**산출물:** `baseline-report.md` — 엔드포인트 3개의 기준선 수치 표

---

## Phase 2 — 관찰성 (측정 인프라 먼저 깔기)

> 고치기 전에 *보는 도구*가 먼저 있어야 함. 안 보이는 건 못 고침.

### 2-1. 구조화된 로그 (pino)
- [ ] Phase 2에서 깔아둔 `pino`에 `request-id` 미들웨어 추가
- [ ] **모든 로그에 request-id가 따라붙어** 한 요청의 흐름이 한 줄로 보이게
- [ ] 로그 레벨 정리: ERROR / WARN / INFO / DEBUG — 언제 뭘 쓰나 1줄씩

### 2-2. 메트릭 (Prometheus + Grafana)
- [ ] `prom-client` 붙여서 NestJS에 `/metrics` 엔드포인트 노출
- [ ] **RED 지표 3개**만 먼저: Rate(RPS) / Errors / Duration(p50/p95/p99)
- [ ] docker-compose에 Prometheus + Grafana 추가
- [ ] Grafana 대시보드 1개 — RPS / p95 / 에러율 라인 차트
- [ ] **부하 주는 중에 Grafana 켜놓고 그래프 움직이는 것 보기** (이 순간이 인프라 학습의 분기점)

### 2-3. DB 메트릭
- [ ] `postgres_exporter` 추가 → Grafana에 active connections, slow queries, cache hit ratio
- [ ] **`pg_stat_statements` 확장 켜기** — 어떤 쿼리가 누적 시간을 잡아먹는지 보기
  ```sql
  CREATE EXTENSION pg_stat_statements;
  SELECT query, calls, total_exec_time, mean_exec_time
  FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
  ```

### 2-4. (선택) 트레이싱 맛보기
- [ ] OpenTelemetry로 분산 트레이싱 한 번 구경 (Jaeger UI) — 깊이는 안 들어가도 됨

**산출물:** Grafana 대시보드 스크린샷 + `pg_stat_statements` Top 5 쿼리

---

## Phase 3 — DB 병목 잡기 (가장 흔한 첫 병목)

> 캐싱·스케일링 들어가기 전에 DB부터. 거의 모든 첫 병목은 DB.

### 3-1. 부하 중 EXPLAIN ANALYZE
- [ ] Phase 1 부하 시나리오를 돌리면서 **`pg_stat_statements`로 Top 5 추출**
- [ ] 각 쿼리에 `EXPLAIN (ANALYZE, BUFFERS)` — Seq Scan / 부적절한 JOIN 순서 찾기
- [ ] Phase 1 로드맵의 인덱스 파트 복습 — 이번엔 *부하 상황*에서 적용

### 3-2. 인덱스 적용
- [ ] **자주 WHERE 거는 컬럼**에 인덱스 (예: `tasks.assignee_id`, `tasks.status`)
- [ ] **복합 인덱스**: `(project_id, status)` 같은 — 컬럼 순서가 왜 중요한지 다시
- [ ] **부분 인덱스(partial)**: `WHERE status <> 'done'`처럼 자주 쓰는 필터만
- [ ] 인덱스 추가 전/후 **k6로 같은 시나리오 재돌려 RPS·p95 비교**

### 3-3. 쿼리 재작성
- [ ] N+1 한 군데 더 찾아서 JOIN 또는 batch로 고치기 (Phase 2 Phase 4의 연장)
- [ ] **`LIMIT`** 빠진 곳 점검 — 데이터 늘면 즉시 죽음
- [ ] OFFSET 페이지네이션 → 커서로 (Phase 2에서 한 거 실제 부하에서 효과 측정)

### 3-4. 데이터 부풀리기
- [ ] tasks를 **100만 건**으로 늘려 다시 부하 — 인덱스 효과가 진짜로 보이는 스케일

**산출물:** 인덱스 전/후 k6 리포트 + EXPLAIN before/after 캡처

---

## Phase 4 — 캐싱 (Redis)

> 캐싱은 **틀린 데이터를 보여줄 위험**과의 거래. 그래서 *어디에 쓸까*가 핵심.

### 4-1. 캐싱 패턴
- [ ] **Cache-aside (Lazy loading):** 읽을 때 캐시 miss → DB → 캐시에 저장
- [ ] **Write-through:** 쓸 때 DB와 캐시를 동시에
- [ ] **Write-behind:** 쓸 땐 캐시만, 나중에 DB로 (위험하지만 빠름)
- [ ] 셋 중 우리 도메인에 맞는 건? 한 줄씩 적기

### 4-2. 실제 캐싱 붙이기
- [ ] `GET /projects/:id` 같은 읽기 무거운 엔드포인트에 cache-aside
- [ ] **TTL 설정** — 너무 길면 stale, 너무 짧으면 무의미
- [ ] **부하 재측정** — Redis hit율 / DB QPS 감소 / p95 변화

### 4-3. 캐시 무효화 (Cache invalidation, 진짜 어려운 부분)
- [ ] `PATCH /projects/:id` 시 해당 키 삭제 (write-around 방식)
- [ ] **함정 직접 재현:** 캐시 삭제 후 DB 업데이트 사이의 race condition → 잘못된 값이 다시 캐시에 박힘
  - 해결: "DB 먼저, 캐시 나중에" 순서 / 또는 짧은 TTL과 병행
- [ ] **캐시 스탬피드(thundering herd):** TTL 만료 순간 동시에 DB 때리는 현상 — k6로 재현 → SWR(stale-while-revalidate) 또는 mutex로 방어

### 4-4. 쓰면 안 되는 곳
- [ ] **돈/잔액/카운터 같은 정확한 값** — 캐싱 금지 또는 정합성 보장 패턴 필요
- [ ] **유저별 개인화 데이터** — 키 분리 필수 (캐시 키에 user_id 안 넣으면 다른 사람 데이터 나옴)

**산출물:** "캐싱 도입 전/후 RPS·p95·DB QPS" 비교표 + 무효화 race 재현 로그

---

## Phase 5 — 커넥션 풀링 (pgbouncer)

> 앱 인스턴스 늘리기 시작하면 곧장 만나는 문제. 미리 준비.

- [ ] 현재 Pool 설정 점검 — `max`가 몇이고, 인스턴스 N개로 늘리면 총 몇 커넥션이 되나?
- [ ] Postgres의 `max_connections` 기본값 확인 → **앱 인스턴스 × Pool size > max_connections** 시 어떻게 깨지는지 직접 재현
- [ ] **pgbouncer**를 docker-compose에 추가 (transaction pooling 모드)
- [ ] 앱은 pgbouncer로만 연결 → 실제 Postgres 커넥션은 적게 유지
- [ ] **함정:** pgbouncer transaction mode에선 prepared statement / `SET LOCAL` 같은 게 깨짐 — `pg` 클라이언트 옵션 조정 필요
- [ ] 부하 재측정 — 동시 요청 수 늘렸을 때 더 잘 버티는지

**산출물:** pgbouncer 도입 전/후 동시 처리 한계 비교

---

## Phase 6 — 수평 확장 (앱 인스턴스 N개 + nginx)

> Phase 2의 "JWT vs 세션" 결정이 여기서 진짜 결과로 드러남.

### 6-1. nginx 로드밸런서
- [ ] docker-compose에 nginx 추가 → app 컨테이너로 upstream
- [ ] **app 인스턴스를 2개로 띄우기** (`docker compose up --scale app=2`)
- [ ] nginx로 round-robin → 두 인스턴스에 트래픽 분산되는 것 확인 (로그로)

### 6-2. Stateless의 위력 체감
- [ ] **세션 방식**(Phase 2 5-2)으로 로그인 시도 → 로그인은 인스턴스A, 다음 요청은 인스턴스B → **로그아웃 상태로 보이는 버그 재현**
- [ ] **JWT 방식**(Phase 2 5-1)으로 같은 시나리오 → 정상 동작
- [ ] **Redis 세션 스토어**로 바꾸면 세션 방식도 동작하는 것 확인 → 트레이드오프 한 단락 정리

### 6-3. Sticky session vs Stateless
- [ ] nginx에서 `ip_hash`로 sticky session 설정 → 동작하지만 한 인스턴스 죽으면 그 유저들 다 로그아웃 → **stateless가 왜 기본인지** 깨달음

### 6-4. 무중단 배포 맛보기
- [ ] `docker compose up -d --no-deps --build app` 시 nginx가 healthcheck 통과한 인스턴스로만 보내는지 확인
- [ ] **graceful shutdown** — Nest의 `enableShutdownHooks()` + SIGTERM 처리

**산출물:** 1인스턴스 vs 2인스턴스 부하 RPS 비교 + 세션/JWT 버그 재현 로그

---

## Phase 7 — Read Replica (읽기/쓰기 분리)

> 인덱스/캐싱 다 했는데도 DB가 한계면 그 다음.

- [ ] Postgres replica를 docker-compose에 추가 (streaming replication)
- [ ] **앱에서 read/write 풀 두 개 관리** — `pg.Pool` 두 개 만들고 Repository에서 분기
- [ ] **읽기 쿼리만 replica로** 라우팅
- [ ] **함정 직접 재현 (replication lag):** primary에 쓰고 즉시 replica에서 읽으면 **방금 쓴 데이터가 안 보임**
  - 해결 1: 쓰기 직후엔 primary에서 읽기 (write-then-read 트래킹)
  - 해결 2: 사용자에게 "잠시 후 반영됩니다" 보여주기 (UX로 풀기)
- [ ] 부하 재측정 — primary CPU 부담이 갈라지는지

**산출물:** replication lag 재현 로그 + read replica 도입 효과 측정

---

## Phase 8 — Rate Limiting · 보호 계층

> 트래픽 다 받아주는 게 능사가 아님. 막을 건 막아야 위 노력들이 의미가 있음.

- [ ] **Rate limiting** — `@nestjs/throttler` 또는 Redis 기반 직접 구현 (sliding window)
- [ ] **IP별 / 사용자별** 두 가지 다 — 로그인 안 한 트래픽도 막아야 함
- [ ] **Circuit breaker** 개념만 — 다운스트림이 죽으면 빠르게 실패시키기
- [ ] nginx 단에서 막을 것 / 앱 단에서 막을 것 분리 (DDoS는 nginx, 비즈니스 룰은 앱)

**산출물:** 1초에 100번 때려도 429로 막히는 것 + 정상 트래픽엔 영향 없는지 측정

---

## Phase 9 — 종합 & 회고

- [ ] **최종 부하 시나리오:** Phase 1의 stress test를 다시 돌려 *전체 개선폭* 측정
  - baseline 대비 RPS / p95 / 에러율 변화
- [ ] 가장 큰 효과가 났던 개선 1위~3위 (보통은 인덱스 > 캐싱 > 수평확장 순)
- [ ] **돈 관점:** 인프라 단계마다 얼마짜리 트레이드오프였나 한 줄씩 (Redis 운영 / replica 운영 / nginx 운영)
- [ ] **남은 한계:** 이 시스템이 다음 단계로 가려면 (k8s? 샤딩? 메시지 큐?) 무엇이 필요한지 한 단락
- [ ] **회사 시스템 역설계 v2:** 이제 Phase 1 끝났을 때보다 더 깊게, "이 API는 캐싱 들어갔겠다 / 이건 read replica 갔겠다"가 보이는지

**산출물:** `final-report.md` — baseline → 최종까지 단계별 개선 그래프 1장 + 회고

---

## 막히면 참고
- **k6 공식 docs** — 짧고 잘 돼있음. 처음엔 `scenarios` 부분만
- **Postgres `pg_stat_statements`** 공식 문서 — 다른 거 다 무시하고 이거만
- **"Designing Data-Intensive Applications" (DDIA)** — 이 단계 하면서 동시에 읽으면 책 페이지마다 "아 이거 내가 겪은 거네" 함
- **Grafana 공식 튜토리얼** — 대시보드 한 번 만들어보면 끝
- **High Performance Browser Networking (Ilya Grigorik)** — 네트워크 레이어 직관 보강

---

## 이 단계 끝낸 다음
- **DDIA 정독** (이미 보유 중) — Phase 1~3 다 겪고 읽으면 완전히 다른 책
- **SRE Book / SRE Workbook** (Google) — 무료. 관찰성/SLO 챕터만 먼저
- **Site Reliability Engineering: Measuring and Managing** — SLI/SLO/SLA 한 번 정리
- 그 다음에야 k8s / 메시지 큐 / 샤딩 — 지금 단계에서 그쪽 가면 *왜 필요한지* 모른 채 쓰게 됨
