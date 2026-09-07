WITH per_customer AS (
  SELECT c.id, c.name, SUM(oi.quantity) AS total_items
  FROM customer AS c
  JOIN "order" AS o ON o.customer_id = c.id
  JOIN order_item AS oi ON oi.order_id = o.id
  GROUP BY c.id, c.name
),
avg_stats AS (
  SELECT AVG(total_items) AS avg_items
  FROM per_customer
)
SELECT p.name AS name, p.total_items AS total_items
FROM per_customer AS p
CROSS JOIN avg_stats AS a
WHERE p.total_items >= a.avg_items
ORDER BY p.total_items DESC, p.name;
