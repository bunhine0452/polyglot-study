SELECT p.name AS product_name,
       oi.order_id,
       oi.quantity,
       oi.quantity - (
         SELECT oi2.quantity
         FROM order_item oi2
         WHERE oi2.product_id = oi.product_id
           AND oi2.order_id < oi.order_id
         ORDER BY oi2.order_id DESC
         LIMIT 1
       ) AS qty_diff
FROM order_item oi
JOIN product p ON p.id = oi.product_id
ORDER BY product_name, order_id;
