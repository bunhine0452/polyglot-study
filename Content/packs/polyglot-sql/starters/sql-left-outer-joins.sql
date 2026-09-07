-- 고객별 주문 수를 집계한다 (아직 INNER JOIN 이다)
SELECT c.name AS name, COUNT(o.id) AS order_count
FROM customer c
INNER JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY order_count DESC, c.name;
