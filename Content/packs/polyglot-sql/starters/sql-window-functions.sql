SELECT p.name AS product_name,
       oi.order_id,
       oi.quantity
FROM order_item oi
JOIN product p ON p.id = oi.product_id
ORDER BY product_name, order_id;
