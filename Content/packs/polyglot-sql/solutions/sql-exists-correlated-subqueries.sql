SELECT c.id, c.name
FROM customer c
WHERE EXISTS (
    SELECT 1
    FROM "order" o
    JOIN order_item oi ON oi.order_id = o.id
    JOIN product p ON p.id = oi.product_id
    WHERE o.customer_id = c.id
      AND p.category_id = 1
)
ORDER BY c.id;
