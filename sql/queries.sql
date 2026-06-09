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
