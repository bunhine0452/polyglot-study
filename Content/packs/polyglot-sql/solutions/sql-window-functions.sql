SELECT p.name AS product_name,
       oi.order_id,
       oi.quantity,
       oi.quantity - LAG(oi.quantity) OVER (PARTITION BY oi.product_id ORDER BY oi.order_id) AS qty_diff
FROM order_item oi
JOIN product p ON p.id = oi.product_id
ORDER BY product_name, order_id;
