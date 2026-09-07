SELECT c.name
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
WHERE o.id IS NULL
ORDER BY c.name;
