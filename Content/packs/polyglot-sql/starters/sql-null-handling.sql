SELECT c.name
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
-- 여기에 주문이 없는 고객만 남기는 조건을 작성하라
ORDER BY c.name;
