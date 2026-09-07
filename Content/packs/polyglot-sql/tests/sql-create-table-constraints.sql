SELECT 1 AS id, '아메리카노' AS name, 'coffee' AS kind, 4000 AS price
UNION ALL
SELECT 2, '녹차라떼', 'tea', 4500
UNION ALL
SELECT 5, '초코쿠키', 'snack', 2000
ORDER BY id;
