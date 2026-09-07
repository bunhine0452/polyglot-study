@Concept(id: case-expression-basics) {
CASE 식은 조회 결과의 행마다 조건을 검사해 서로 다른 값을 만들어 내는 표현식이다. WHEN ... THEN ... 을 여러 개 나열해 위에서부터 차례로 검사하고, 어디에도 걸리지 않으면 ELSE 값이, ELSE 도 없으면 NULL 이 나온다. NULL 은 = 로 비교할 수 없으므로 shipped_at IS NULL 처럼 IS 를 써서 검사해야 한다. CASE 식은 값이 들어가는 자리라면 어디든 쓸 수 있는데, SUM 이나 COUNT 안에 넣으면 조건에 맞는 행만 골라 세는 조건부 집계를 만들 수 있다.
}

@Example(id: shipping-status-label, language: sql, expected: expected/sql-case-expressions.txt) {
아래 예제는 표본 주문 다섯 건에 대해 shipped_at 이 NULL 인지 검사해 배송 상태 문구를 행마다 붙인다.

```sql
WITH sample_order(id, shipped_at) AS (
  VALUES (1, '2024-05-01'),
         (2, NULL),
         (3, '2024-05-02'),
         (4, '2024-05-03'),
         (5, NULL)
)
SELECT id,
       CASE WHEN shipped_at IS NULL THEN '미배송'
            ELSE '배송완료' END AS status
FROM sample_order
ORDER BY id;
```
}

@Blank(id: price-band-blank, language: sql) {
아래 질의는 가격 구간에 따라 상품에 등급 라벨을 붙인다. 가장 비싼 구간의 라벨을 붙이는 ELSE 자리를 채워라.

```sql
SELECT id, name, price,
       CASE WHEN price < 3000 THEN '저가'
            WHEN price < 8000 THEN '중가'
            ELSE ___1___ END AS band
FROM (
  SELECT 1 AS id, '연필' AS name, 1000 AS price UNION ALL
  SELECT 2, '노트', 5000 UNION ALL
  SELECT 3, '백팩', 58000
)
ORDER BY id;
```

@Answer(slot: 1) {
`'고가'`
}
}

@Task(id: customer-shipping-summary, language: sql, starter: starters/sql-case-expressions.sql, tests: tests/sql-case-expressions.sql, solution: solutions/sql-case-expressions.sql) {
고객별로 총 주문 수와 그중 배송이 완료된 주문 수를 집계하라. customer 표의 모든 고객을 포함하고, 주문이 하나도 없는 고객은 order_cnt 와 done_cnt 가 모두 0 이 되어야 한다. 배송 완료는 shipped_at 이 NULL 이 아닌 주문이다. 출력 열은 name, order_cnt, done_cnt 순서로 하고, 이름순으로 정렬하라.

@Hint {
주문이 없는 고객까지 결과에 포함하려면 LEFT JOIN 을 쓴다.
}

@Hint {
shipped_at 이 NULL 이 아닌지 검사할 때는 = 이 아니라 IS NOT NULL 을 써야 한다.
}

@Hint {
SUM 안에 CASE WHEN ... THEN 1 ELSE 0 END 를 넣으면 조건에 맞는 행 수를 셀 수 있다.
}
}

@Quiz(id: case-else-omitted-quiz, answer: null-and-null-sum) {
@Question {
조건부 집계에서 SUM(CASE WHEN o.shipped_at IS NOT NULL THEN 1 END) 처럼 ELSE 를 생략하면 어떻게 될까?
}

@Choice(id: null-and-null-sum) {
조건에 맞지 않는 행은 NULL 이 되어 SUM 에서 무시되지만, 모든 행이 조건에 맞지 않으면 결과가 0 이 아니라 NULL 이 된다.
}

@Choice(id: auto-zero) {
ELSE 가 없어도 자동으로 0 이 채워지므로 ELSE 0 을 쓴 경우와 항상 같은 결과가 나온다.
}

@Choice(id: syntax-error) {
ELSE 를 쓰지 않으면 CASE 식 문법 오류가 나서 질의가 실행되지 않는다.
}

@Choice(id: empty-string) {
조건에 맞지 않는 행은 빈 문자열이 되어 집계에서 무시된다.
}

@Explanation {
ELSE 를 생략하면 조건에 맞지 않는 행의 CASE 값은 NULL 이 되고, SUM 은 NULL 을 무시하므로 보통은 같은 결과가 나온다. 그러나 그룹 안의 모든 행이 조건에 맞지 않으면 더할 값이 하나도 없어 SUM 이 0 이 아니라 NULL 을 돌려주므로, 0 이 필요한 집계에서는 ELSE 0 을 명시하는 것이 안전하다.
}
}

@Reflection(id: case-reflection) {
@Prompt(id: else-null-impact) {
ELSE 를 생략하면 조건에 맞지 않는 행에 NULL 이 들어간다. 라벨을 붙일 때와 집계할 때 각각 이 NULL 이 어떤 결과 차이를 만드는지 말해 보라.
}

@Prompt(id: where-vs-case-agg) {
배송완료 건수를 WHERE 절로 미리 걸러서 세는 방법과 CASE 를 넣어 세는 방법을 비교하면, 각각 어떤 상황에서 유리할까?
}

@Prompt(id: band-safety) {
가격 구간을 나눌 때 price < 10000 과 price >= 10000 AND price < 50000 처럼 경계를 한쪽만 여는 조건으로 이어 붙이는 것과 BETWEEN 으로 양쪽을 닫는 것 중 어느 쪽이 구간 겹침과 빠짐을 막기 더 안전한지, 이유와 함께 생각해 보라.
}
}
