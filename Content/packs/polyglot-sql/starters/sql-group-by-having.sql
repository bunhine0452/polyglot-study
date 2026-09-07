WITH item(category, price) AS (
  VALUES
    ('book', 12000),
    ('book', 8000),
    ('book', 8000),
    ('toy', 3500),
    ('toy', 9900),
    ('pen', 1200)
)
-- 1) category 별로 묶고
-- 2) 건수는 n, 평균 가격은 avg_price 라는 이름으로 구하고
-- 3) 건수가 2 이상인 그룹만 남기고
-- 4) category 오름차순으로 정렬하라
SELECT category, price
FROM item;
