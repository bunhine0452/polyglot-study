SELECT cu.name AS name, SUM(oi.quantity * p.price) AS total_spent
FROM customer cu
JOIN "order" o ON o.customer_id = cu.id
JOIN order_item oi ON oi.order_id = o.id
JOIN product p ON p.id = oi.product_id
GROUP BY cu.name
ORDER BY total_spent DESC, name ASC;
