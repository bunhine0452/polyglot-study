-- 기대 결과셋. 채점기는 학습자 질의의 결과와 이 질의의 결과를 행 단위로 비교한다.
SELECT 'paper' AS category, 'sketchbook' AS name, 9800 AS price
UNION ALL
SELECT 'pen', 'fountain', 42000
ORDER BY category;
