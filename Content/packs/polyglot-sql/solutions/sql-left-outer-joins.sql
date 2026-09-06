SELECT c.name AS name, COUNT(o.id) AS order_count
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY order_count DESC, c.name;
