@Concept(id: group-by-having) {
GROUP BY 는 지정한 열의 값이 같은 행들을 하나의 그룹으로 묶어 준다. 묶인 그룹마다 COUNT, SUM, AVG 같은 집계 함수가 한 번씩 계산되므로, SELECT 절에는 GROUP BY 에 쓴 열과 집계 함수만 나올 수 있다.

여러 열을 GROUP BY 에 나열하면 열 값의 조합이 모두 같은 행끼리 묶인다. 예를 들어 GROUP BY customer_id, product_id 라면 '고객×상품' 조합별로 그룹이 만들어진다.

HAVING 은 그룹이 만들어지고 집계가 계산된 뒤에 그룹을 걸러낸다. WHERE 가 집계 전의 개별 행에 조건을 거는 것과 달리, HAVING 에서는 COUNT(*) 나 AVG(price) 같은 집계 결과에 조건을 쓸 수 있다. WHERE 로 행을 먼저 줄이고, GROUP BY 로 묶고, HAVING 으로 그룹을 골라내는 순서로 쿼리가 읽힌다.
}

@Example(id: group-having-example, language: sql, expected: expected/sql-group-by-having.txt) {
카테고리별로 행을 묶어 건수와 평균 가격을 구하고, HAVING 으로 평균 가격이 5000 이상인 그룹만 남긴다. pen 그룹은 평균이 2400.0 이라 걸러져서 결과에 나오지 않는다.

```sql
WITH sales(category, price) AS (
  VALUES
    ('paper', 5200),
    ('paper', 8100),
    ('pen', 1500),
    ('pen', 2400),
    ('pen', 3300),
    ('bag', 45000)
)
SELECT category,
       COUNT(*) AS n,
       AVG(price) AS avg_price
FROM sales
GROUP BY category
HAVING AVG(price) >= 5000
ORDER BY category;
```
}

@Blank(id: group-having-blank, language: sql) {
WITH 절로 주어진 주문 항목을 고객과 상품 두 열을 기준으로 묶어 수량 합계를 구하고, 수량 합계가 1을 넘는 그룹만 남기려 한다. 빈칸을 채워 쿼리를 완성하라.

```sql
WITH order_item(customer_id, product_id, quantity) AS (
  VALUES
    (1, 10, 1),
    (1, 10, 2),
    (1, 20, 1),
    (2, 10, 3),
    (2, 20, 1),
    (3, 30, 1)
)
SELECT customer_id,
       product_id,
       SUM(quantity) AS total_qty
FROM order_item
GROUP BY ___1___
HAVING ___2___ > 1
ORDER BY customer_id, product_id, total_qty;
```

@Answer(slot: 1) {
`customer_id, product_id`
}

@Answer(slot: 2) {
`SUM(quantity)`
}
}

@Task(id: group-having-task, language: sql, starter: starters/sql-group-by-having.sql, tests: tests/sql-group-by-having.sql, solution: solutions/sql-group-by-having.sql) {
아래 WITH 절로 제공되는 item 표(카테고리와 가격)를 카테고리별로 묶어 주문 건수(n)와 평균 가격(avg_price)을 구하라. 단, 주문 건수가 2 이상인 그룹만 남기고, category 오름차순으로 정렬하라. SELECT 아래의 주석을 지우고 GROUP BY 와 HAVING 을 직접 작성하라.

@Hint {
그룹을 묶는 열은 SELECT 절에 있는 category 하나다.
}

@Hint {
평균 가격은 AVG(price) 로 구하고, 열 이름 뒤에 AS avg_price 를 붙여 별명을 지정한다.
}

@Hint {
집계 결과에 조건을 걸 때는 WHERE 가 아니라 HAVING 을 쓴다.
}
}

@Quiz(id: where-vs-having-quiz, answer: where-rows-having-groups) {
@Question {
WHERE 와 HAVING 의 차이로 옳은 것은?
}

@Choice(id: where-rows-having-groups) {
WHERE 는 그룹화 전에 개별 행을 걸러내고, HAVING 은 그룹화 후 집계 결과에 조건을 적용한다.
}

@Choice(id: having-before-group) {
HAVING 은 GROUP BY 보다 먼저 평가되므로 원본 행에 조건을 걸 때 쓴다.
}

@Choice(id: interchangeable) {
둘은 완전히 같은 역할이므로 집계 조건도 WHERE 로 대신 쓸 수 있다.
}

@Choice(id: where-supports-aggregates) {
WHERE 에도 COUNT(*) 같은 집계 함수를 쓸 수 있으므로 HAVING 은 필요 없다.
}

@Explanation {
쿼리는 WHERE 로 행을 먼저 줄이고, GROUP BY 로 묶은 뒤 HAVING 으로 그룹을 걸러낸다. 집계 함수 결과는 그룹이 만들어져야 계산되므로 WHERE 절에서는 쓸 수 없고, 그룹 조건은 반드시 HAVING 에 써야 한다.
}
}

@Reflection(id: group-having-reflection) {
@Prompt(id: order-of-filtering) {
WHERE 와 HAVING 을 한 쿼리에 함께 쓸 때 각각 어느 시점에 행을 걸러내는지, 실행 순서를 따라가며 자기 말로 설명해 보라.
}

@Prompt(id: multi-column-use-case) {
GROUP BY 에 열을 두 개 이상 나열하면 결과가 어떻게 달라지는가? 실제 서비스에서 이런 복합 그룹화가 유용할 만한 보고서 예를 하나 생각해 보라.
}
}
