SELECT c.id, c.name
FROM customer c
WHERE 1 = 0  -- 여기에 EXISTS 상관 서브쿼리를 작성하세요
ORDER BY c.id;
