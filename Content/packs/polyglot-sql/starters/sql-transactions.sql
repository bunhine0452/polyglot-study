-- TODO: 아래 순서대로 완성하세요.
-- 1) BEGIN 으로 트랜잭션을 연다
-- 2) product 의 재고(stock)를 두 배로 만드는 UPDATE 를 쓴다
-- 3) shipped_at 이 NULL 이 아닌 주문을 "order" 에서 삭제한다
-- 4) city 가 NULL 인 고객의 city 를 '알수없음' 으로 바꾼다
-- 5) ROLLBACK 으로 모든 변경을 되돌린다
-- 6) 아래 SELECT 를 완성해 원래 상태를 증명한다
SELECT NULL AS total_orders, NULL AS shipped_orders, NULL AS missing_city;
