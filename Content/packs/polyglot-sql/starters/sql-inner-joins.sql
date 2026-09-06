-- customer, "order", order_item, product 네 표를 조인해
-- 고객별 총 주문 금액을 구하세요. 주문이 없는 고객은 제외합니다.
SELECT name, total_spent
FROM customer
ORDER BY total_spent DESC, name;
