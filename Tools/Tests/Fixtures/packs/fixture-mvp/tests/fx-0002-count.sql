-- 기대 결과셋. 채점기가 학습자 질의의 결과와 이 질의의 결과를 비교한다.
SELECT 'a' AS kind, 300 AS price
UNION ALL
SELECT 'b', 200
ORDER BY kind;
