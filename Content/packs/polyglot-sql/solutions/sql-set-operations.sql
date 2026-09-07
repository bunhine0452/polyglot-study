SELECT name
FROM customer
EXCEPT
SELECT c.name
FROM customer c
JOIN "order" o ON o.customer_id = c.id
ORDER BY name;
