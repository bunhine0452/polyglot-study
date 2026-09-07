CREATE VIEW customer_order_stats AS
SELECT c.name AS name, COUNT(o.id) AS order_count
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name;

SELECT name, order_count
FROM customer_order_stats
WHERE order_count = 0
ORDER BY name;
