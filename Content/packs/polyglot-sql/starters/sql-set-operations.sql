-- 주문 기록이 하나도 없는 고객의 이름을 구하세요.
-- EXCEPT 를 사용해 전체 고객 이름 집합에서
-- 주문이 있는 고객 이름 집합을 빼야 합니다.
SELECT name
FROM customer
ORDER BY name;
