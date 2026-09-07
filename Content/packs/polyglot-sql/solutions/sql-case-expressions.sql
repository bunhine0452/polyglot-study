SELECT c.name,
       COUNT(o.id) AS order_cnt,
       SUM(CASE WHEN o.shipped_at IS NOT NULL THEN 1 ELSE 0 END) AS done_cnt
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY c.name;
