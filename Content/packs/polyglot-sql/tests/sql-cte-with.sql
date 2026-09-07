SELECT name, total_items FROM (
  SELECT c.name AS name, SUM(oi.quantity) AS total_items
  FROM customer AS c
  JOIN "order" AS o ON o.customer_id = c.id
  JOIN order_item AS oi ON oi.order_id = o.id
  GROUP BY c.id, c.name
)
WHERE total_items >= (
  SELECT AVG(total_items) FROM (
    SELECT SUM(oi.quantity) AS total_items
    FROM customer AS c
    JOIN "order" AS o ON o.customer_id = c.id
    JOIN order_item AS oi ON oi.order_id = o.id
    GROUP BY c.id
  )
)
ORDER BY total_items DESC, name;
