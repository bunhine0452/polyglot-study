WITH customer (id, name, city, joined_on) AS (
  VALUES
    (1, '김하늘', '서울', '2023-01-15'),
    (2, '이준서', '부산', '2023-03-02'),
    (3, '박서연', '서울', '2023-05-20'),
    (4, '최도윤', NULL, '2023-06-11'),
    (5, '정바람', '대전', '2023-08-05'),
    (6, '한별빛', '인천', '2023-09-30')
)
SELECT 'city' AS city
UNION ALL
SELECT city
FROM (
  SELECT DISTINCT city
  FROM customer
  WHERE city IS NOT NULL
  ORDER BY city ASC
  LIMIT 3
);
