SELECT c.name,
       COUNT(o.id) AS order_cnt,
       0 AS done_cnt
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY c.name;
