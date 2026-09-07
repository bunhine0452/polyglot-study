SELECT cu.name AS customer
FROM customer cu
JOIN "order" o ON o.customer_id = cu.id
GROUP BY cu.id, cu.name
ORDER BY customer;
