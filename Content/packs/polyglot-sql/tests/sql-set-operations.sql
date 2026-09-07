SELECT name
FROM customer c
WHERE NOT EXISTS (SELECT 1 FROM "order" o WHERE o.customer_id = c.id)
ORDER BY name;
