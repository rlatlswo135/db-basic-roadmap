-- 3-2 SELECT
-- AS
SELECT priority AS task_priority, status AS task_status FROM tasks LIMIT 30;
-- DISTINCT (중복제거)
SELECT DISTINCT status,position FROM tasks;
-- 계산식
SELECT priority, priority * 3 AS triple_priority FROM tasks LIMIT 30;
-- CASE WHEN
SELECT priority, CASE priority WHEN 1 THEN 'High' WHEN 2 THEN 'Medium' WHEN 3 THEN 'Low' ELSE 'Unknown' END AS priority_name
FROM tasks LIMIT 30;
-- COALESCE (NULL일때 대체값 => 데이터타입 맞추어야함)
SELECT name, COALESCE(position,1) AS position FROM tasks LIMIT 30;

-- 3-3 WHERE
-- BASIC
SELECT title,priority,status FROM tasks WHERE priority >= 4 AND status <> 'done' LIMIT 30;
-- AND OR NOT (괄호로 우선순위 조절)
SELECT title,priority,status FROM tasks WHERE NOT priority >= 4
SELECT project_name,title,priority,status FROM tasks WHERE (priority >= 4 OR status <> 'done') AND project_name = 'Mobile App' LIMIT 30;
-- IN (여러값 비교)
SELECT project_name,status FROM tasks WHERE status IN ('todo','doing') LIMIT 50;
SELECT project_name,status FROM tasks WHERE status NOT IN ('done') LIMIT 15;
-- BETWEEN
SELECT id,title FROM tasks WHERE id BETWEEN 600 AND 700 LIMIT 50;
-- LIKE (% _ 와일드카드 구분)
SELECT project_name,title FROM tasks WHERE project_name LIKE 'Mobile%' LIMIT 30;
SELECT project_name,title FROM tasks WHERE project_name LIKE 'Mobile Ap_' LIMIT 30;
-- ILIKE (대소문자 구분없이 LIKE)
SELECT project_name FROM tasks WHERE project_name ILIKE 'mobile%';
-- IS NULL / IS NOT NULL
SELECT id,title FROM tasks WHERE position IS NULL LIMIT 20;
SELECT id,title FROM tasks WHERE position IS NOT NULL;

-- 3-4 정렬/페이징
-- ORDER BY
SELECT id,title,priority FROM tasks ORDER BY priority DESC LIMIT 20;
SELECT id,title,project_name,priority FROM tasks ORDER BY priority DESC, project_name DESC LIMIT 30;
-- NULLS FIRST / NULLS LAST (ORDER BY와 함께사용 반드시)
SELECT title,project_name,position FROM tasks ORDER BY position NULLS LAST LIMIT 30;
-- LIMIT(몇개까지) / OFFSET(건너뛸 row)
SELECT id,title FROM tasks LIMIT 15 OFFSET 15;
-- 3-5 집계 (GROUP BY)
-- COUNT
SELECT project_name,COUNT(*) AS count FROM tasks GROUP BY project_name;
-- SUM
SELECT priority,SUM(priority) FROM tasks GROUP BY priority;
-- AVG
SELECT priority,AVG(id) AS avg_id FROM tasks GROUP BY priority;
-- MIN
SELECT priority,MIN(id) AS min_id FROM tasks GROUP BY priority;
-- MAX
SELECT priority,MAX(id) AS max_id FROM tasks GROUP BY priority;
-- GROUP BY — "프로젝트별 태스크 수"
SELECT project_name,COUNT(*) AS count FROM tasks GROUP BY project_name;
-- HAVING
SELECT project_name,COUNT(*) FROM tasks GROUP BY project_name HAVING COUNT(*) > 5;
-- 조건부 집계 (FILTER 등)
SELECT project_name, COUNT(*) FILTER (WHERE status='done') AS done_status FROM tasks GROUP BY project_name;
SELECT project_name, AVG((status='done')::int) FROM tasks GROUP BY project_name;
-- COUNT(*) vs COUNT(column)
SELECT project_name,COUNT(*) FROM tasks GROUP BY project_name;
SELECT project_name,COUNT(position) FROM tasks GROUP BY project_name;
-- 3-6 서브쿼리
-- WHERE 절 서브쿼리 - 전체 평균 priority보다 높은 태스크
SELECT title,priority FROM tasks WHERE priority > (SELECT AVG(priority) FROM tasks) ORDER BY priority DESC;
-- FROM 절 서브쿼리 - 프로젝트별 집계를 다시 필터
SELECT t.title,t.priority 
FROM tasks t, (SELECT AVG(priority) AS priority FROM tasks) AS a 
WHERE t.priority > a.priority;
-- 상관 서브쿼리(correlated) — 바깥 행마다 도는 것 체감
SELECT project_name,COUNT(*) FILTER(WHERE priority > avg_priority) 
FROM tasks,(SELECT AVG(priority) AS avg_priority FROM tasks) AS avg 
GROUP BY project_name;
-- EXISTS / NOT EXISTS 중요) EXISTS는 서브쿼리의 결과 row가 하나라도 있냐 없냐를 판단하는거다 NOT EXISTS는 반대로 하나도 없냐를 판단하는거다
SELECT project_name,title FROM tasks t WHERE EXISTS(SELECT 1 FROM comments c WHERE c.task_id = t.id);
-- IN 절 서브쿼리 (*단일컬럼* 이 포함되어있냐 판단. EXISTS와 혼동 주의)
SELECT project_name,title FROM tasks t WHERE t.id IN(SELECT task_id FROM comments);
-- JOIN절 =>  왜 IN, EXISTS랑 결과가 다른지 묻기!!
SELECT DISTINCT project_name,title FROM tasks t JOIN comments c ON t.id = c.task_id;
-- CTE => 예시에는 CTD 효과가 별로 없지만 GROUP BY, HAVING등 복잡한 조건있을때 유용 => 서브쿼리 테이블을 상단에서 선언해서 가독을 챙기는 느낌
WITH comment_task AS (SELECT task_id FROM comments) SELECT project_name,title FROM tasks t WHERE t.id IN (SELECT task_id FROM comment_task);
-- 3-7 집합연산
-- UNION / UNION ALL // UNION은 중복제거, UNION ALL은 중복허용 // 컬럼 개수 및 데이터 타입이 동일하면 OK
-- IMPORTANT: 생각보다 중복제거 비용이 있다 DISTINCT도 마찬가지. 최대한 쿼리를 파악한 다음 안되면 써야한다
SELECT id AS task_id FROM tasks UNION ALL SELECT task_id FROM comments;
-- INTERSECT: 테이블이 같다면 AND 조건을 생각해보자
SELECT owner_id FROM projects INTERSECT SELECT author_id FROM comments;
-- EXCEPT: 차집합
SELECT owner_id FROM projects EXCEPT SELECT author_id FROM comments;
-- JOIN 집중 // 기본 개념은 CROSS를 제외하곤 곱집합테이블 
-- => ON으로 필터링인데 실제 옵티마이저가 곱집합을 만들때 최적화 및 인덱스제공등으로 실제로 곱집합이 만들어지는 경우보다는 성능이 괜찮다.

-- J-1. 종류별 1번씩
-- INNER JOIN = 왼쪽테이블 기준으로 JOIN후 매칭이 안되는 row는 버리는 형태
SELECT project_id,title FROM tasks t INNER JOIN projects p ON t.project_id = p.id;
-- LEFT JOIN => 왼쪽테이블 기준으로 JOIN후 매칭이 안되는 row는 NULL로 채우는 형태 (항상 기준테이블 row는 보존)
SELECT c.id AS comment_id,body,name,email FROM comments c LEFT JOIN users u ON c.author_id = u.id;
-- RIGHT JOIN => 오른쪽테이블 기준으로 JOIN후 매칭이 안되는 row는 NULL로 채우는 형태 (항상 기준테이블 row는 보존
-- 읽는 순서상 왼쪽 -> 오른쪽순일건데 RIGHT JOIN은 JOIN 기준점이 오른쪽에 붙어서 읽는 사람이 헷갈릴 수 있어 결과조차 이상해질수있다. 그래서 LEFT JOIN을 더 선호하는 편이다.
SELECT c.id AS comment_id,body,name,email FROM comments c RIGHT JOIN users u ON c.author_id = u.id;
-- SELF JOIN -> 테이블 내 데이터가 재귀적인 관계를 가질 때 자기 자신과 JOIN하는 형태
SELECT id AS task_id,t2.id AS sub_task_id FROM tasks t1 JOIN tasks t2 ON t1.id = t2.sub_task_id;
-- CROSS JOIN (TODO: 해당 쿼리 뜯어달라고 하기) -> ON 조건 없이 n*m 테이블 만들어줌 -> 주로 보고서등 작성시 모든 경우에수에대한 COUNT 데이터 등이 필요할때 사용
SELECT p.name AS project_name, s.status, COUNT(t.id) AS count
  FROM projects p                                                                                       
  CROSS JOIN (VALUES ('todo'),('doing'),('done')) AS s(status)
  LEFT JOIN tasks t ON t.project_id = p.id AND t.status = s.status
  GROUP BY p.name, s.status
  ORDER BY p.name DESC, s.status;

-- J-2. 상황별 응용
-- 부모 + 자식 한줄에
SELECT t.id AS task_id,project_id,p.name,t.title FROM tasks t LEFT JOIN projects p ON t.project_id = p.id LIMIT 25;
-- 3개 이상 JOIN
SELECT t.assignee_id, u.name AS assigenn_name, p.name AS project_name,t.title AS task_title
FROM tasks t
LEFT JOIN projects p ON p.id = t.project_id
LEFT JOIN users u ON t.assignee_id = u.id;
-- 자식 없는 부모 찾기
SELECT p.name FROM projects p LEFT JOIN tasks t ON p.id = t.project_id WHERE t.id IS NULL;
-- 담당자 없는 task
-- JOIN + 집계
-- JOIN + 필터