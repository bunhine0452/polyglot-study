SELECT name
FROM customer
WHERE id NOT IN (
  SELECT customer_id
  FROM "order"
)
ORDER BY name;
