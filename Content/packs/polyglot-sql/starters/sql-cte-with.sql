WITH per_customer AS (
  SELECT c.id, c.name, 0 AS total_items
  FROM customer AS c
)
SELECT name, total_items
FROM per_customer
ORDER BY total_items DESC, name;
