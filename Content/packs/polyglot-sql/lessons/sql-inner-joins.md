@Concept(id: inner-join-on-alias) {
지금까지는 한 표 안에서만 데이터를 조회했다. 실제 데이터는 흩어져 있다 — 상품은 product 에, 카테고리 이름은 category 에, 주문 항목은 order_item 에 각각 담겨 있다. **INNER JOIN** 은 두 표를 나란히 놓고 ON 조건(보통 한쪽의 외래 키가 다른 쪽의 기본 키와 같은지)이 참인 행끼리 한 줄로 붙인다. 짝을 찾지 못한 행은 결과에서 사라지므로, 존재가 보장된 연결만 다룰 때 적합하다. 표가 세 개 이상 섞이면 customer, "order", order_item 처럼 이름이 길어지고 겹치는 열도 많아지는데, FROM 뒤에 **별칭**(`FROM customer cu`)을 붙이면 어디서든 짧은 별칭으로 표를 가리킬 수 있다. 조인된 결과는 지금까지 배운 WHERE, GROUP BY, 집계 함수와 그대로 함께 쓸 수 있어서, "카테고리별 판매 수량" 같은 질문을 하나의 질의로 해결할 수 있다.
}

@Example(id: join-product-category, language: sql, expected: expected/sql-inner-joins.txt) {
WITH 절로 작은 상품·카테고리 표를 만들고, category_id 를 키로 INNER JOIN 해서 두 표의 정보를 한 결과로 합친다.

```sql
WITH cat(id, name) AS (VALUES (1, 'paper'), (2, 'pen')),
     prod(id, name, category_id, price) AS (VALUES (1, '노트', 1, 1200), (2, '볼펜', 2, 800), (3, '연필', 1, 600))
SELECT cat.name AS category, prod.name AS product, prod.price AS price
FROM prod
INNER JOIN cat ON prod.category_id = cat.id
ORDER BY prod.price;
```
}

@Blank(id: join-order-items, language: sql) {
주문 항목을 상품과 카테고리 표에 연결해 paper 카테고리 상품만 골라, 주문 번호 순으로 정렬하는 질의다. 빈칸을 채워 완성하라.

```sql
SELECT p.name AS product, c.name AS category
FROM order_item oi
INNER JOIN product p ON oi.product_id = p.id
INNER JOIN category c ON p.category_id = c.id
WHERE ___1___ = 'paper'
ORDER BY ___2___, p.name;
```

@Answer(slot: 1) {
`c.name`
}

@Answer(slot: 2) {
`oi.order_id`
}
}

@Task(id: customer-total-spent, language: sql, starter: starters/sql-inner-joins.sql, tests: tests/sql-inner-joins.sql, solution: solutions/sql-inner-joins.sql) {
고객별로 지금까지 주문한 총 금액을 구하라. 주문이 하나도 없는 고객은 결과에서 제외한다. 출력 열은 고객 이름(name)과 총 금액(total_spent)이며, 총 금액은 각 주문 항목의 quantity × price 의 합이다. 결과는 총 금액 기준 내림차순, 금액이 같으면 이름 오름차순으로 정렬하라.

@Hint {
네 표를 키로 연결해야 한다: customer → "order" → order_item → product.
}

@Hint {
INNER JOIN 은 주문이 없는 고객 행을 자동으로 걸러 준다. WHERE 로 따로 제외할 필요가 없다.
}

@Hint {
총 금액은 SUM(oi.quantity * p.price) 이고, GROUP BY cu.name 으로 묶어라.
}
}

@Quiz(id: quiz-inner-join-unmatched, answer: rows-dropped) {
@Question {
INNER JOIN 으로 두 표를 연결할 때, ON 조건에 맞는 짝이 없는 행은 어떻게 되는가?
}

@Choice(id: rows-dropped) {
양쪽 중 한쪽이라도 짝을 찾지 못한 행은 결과에서 사라진다.
}

@Choice(id: kept-null) {
짝이 없는 행도 남은 열이 NULL 로 채워진 채 결과에 포함된다.
}

@Choice(id: query-error) {
짝이 없는 행이 하나라도 있으면 질의 전체가 오류로 실패한다.
}

@Choice(id: kept-first-only) {
짝이 없는 행은 먼저 쓴 표의 값만으로 결과에 한 번 나온다.
}

@Explanation {
INNER JOIN 은 ON 조건이 참인 짝끼리만 결과에 남긴다. 짝 없는 행을 NULL 로 남기려면 LEFT JOIN 을 써야 하고, 짝이 없다고 해서 오류가 나거나 한쪽 값만 남는 일은 없다.
}
}

@Reflection(id: reflect-join-thinking) {
@Prompt(id: left-join-what-for) {
이 커머스 데이터에서 INNER JOIN 대신 LEFT JOIN 을 쓴다면 어떤 질문에 새로 답할 수 있게 될까? 주문이 없는 고객 두 명을 예로 들어 설명해 보라.
}

@Prompt(id: alias-value) {
별칭을 쓰지 않고 표 이름 전체를 매번 쓴다면 네 표 조인 질의가 얼마나 길어질지 상상해 보라. 별칭이 특히 빛을 발하는 상황은 언제인가?
}

@Prompt(id: missing-on-condition) {
세 개 이상의 표를 조인할 때 ON 조건을 하나 빠뜨리면 결과에 어떤 일이 벌어질까? 행 수가 어떻게 변하는지 생각해 보라.
}
}
