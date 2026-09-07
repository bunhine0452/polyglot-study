-- 가격이 10000원 이상이고, 카테고리가 1번이거나 3번인 상품만 조회하도록
-- 아래 질의에 WHERE 절을 추가하라.
SELECT id, name, category_id, price, stock
FROM product
ORDER BY id;
