SELECT c.name,
       (SELECT COUNT(*) FROM "order" o WHERE o.customer_id = c.id) AS order_cnt,
       (SELECT COUNT(*) FROM "order" o WHERE o.customer_id = c.id AND o.shipped_at IS NOT NULL) AS done_cnt
FROM customer c
ORDER BY c.name;
