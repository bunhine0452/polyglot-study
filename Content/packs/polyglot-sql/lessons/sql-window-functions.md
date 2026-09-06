@Concept(id: window-functions-over-partition) {
## 창 함수: 행을 접지 않는 집계

GROUP BY 로 묶으면 그룹마다 한 행으로 접혀서, 원래 행들이 어떤 값을 가졌는지는 사라진다. 창 함수는 SUM, AVG 같은 집계 함수 뒤에 OVER 를 붙여 **행을 접지 않은 채** "이 행이 속한 창(그룹) 위에서 계산한 값"을 각 행에 붙인다. 그래서 상품명과 가격 같은 원래 열과 그룹 합계를 같은 행에서 함께 볼 수 있다.

- `OVER (PARTITION BY 열)` — 창을 나눌 기준을 정한다. 같은 값을 가진 행들이 같은 창에 속한다.
- `OVER (PARTITION BY 열 ORDER BY 열)` — 창 안에서 행의 순서까지 정한다. 순위 함수는 이 순서를 기준으로 번호를 매긴다.
- `ROW_NUMBER()` — 창 안에서 1, 2, 3 처럼 **중복 없는** 번호를 붙인다.
- `RANK()` — 동률에게 같은 순위를 주고 다음 순위를 건너뛴다. 예: 1, 1, 3.
- `LAG(열)` — 창 안에서 **바로 앞 행**의 값을 가져온다. 첫 번째 행 앞에는 값이 없으므로 NULL 이 나온다.

예를 들어 `SUM(quantity) OVER (PARTITION BY product_id)` 는 상품별 총 판매 수량을, 상품별 모든 행에 반복해서 붙인다. 이전 행과의 변화량을 보고 싶다면 `quantity - LAG(quantity) OVER (PARTITION BY product_id ORDER BY order_id)` 처럼 LAG 를 활용한다.
}

@Example(id: partition-rownumber-example, language: sql, expected: expected/sql-window-functions.txt) {
상품별 창을 나눠 창 안 합계를 각 행에 붙이고, ROW_NUMBER 로 창 안 수량 순위를 매겨본다.

```sql
WITH sales AS (
  SELECT 1 AS product_id, '볼펜' AS name, 3 AS qty UNION ALL
  SELECT 1, '볼펜', 2 UNION ALL
  SELECT 2, '노트', 5 UNION ALL
  SELECT 2, '노트', 1 UNION ALL
  SELECT 3, '지우개', 4
)
SELECT name,
       qty,
       SUM(qty) OVER (PARTITION BY product_id) AS part_total,
       ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY qty DESC) AS rn
FROM sales
ORDER BY product_id, rn;
```
}

@Blank(id: top1-per-category-blank, language: sql) {
product 표에서 카테고리가 지정된 상품만 대상으로, 카테고리별로 가격이 가장 비싼 상품 한 개씩만 골라내는 쿼리다. 빈칸을 채워 완성하라.

```sql
SELECT name, price
FROM (
  SELECT name,
         price,
         ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price ___1___) AS ___2___
  FROM product
  WHERE category_id IS NOT NULL
)
WHERE ___3___ = 1
ORDER BY name;
```

@Answer(slot: 1) {
`DESC`
}

@Answer(slot: 2) {
`rn`
}

@Answer(slot: 3) {
`rn`
}
}

@Task(id: lag-qty-diff, language: sql, starter: starters/sql-window-functions.sql, tests: tests/sql-window-functions.sql, solution: solutions/sql-window-functions.sql) {
order_item 표에는 주문마다 어떤 상품을 몇 개 샀는지 기록되어 있다. LAG 창 함수를 써서, 상품별로 주문 번호(order_id) 순서대로 수량이 이전 주문에 비해 얼마나 변했는지 qty_diff 열로 계산하라. 상품의 첫 주문에는 이전이 없으므로 qty_diff 가 NULL 이 된다. 출력 열은 product_name, order_id, quantity, qty_diff 순서여야 하고, product_name 오름차순, order_id 오름차순으로 정렬한다.

@Hint {
LAG(oi.quantity) OVER (PARTITION BY oi.product_id ORDER BY oi.order_id) 이 현재 행 바로 앞 주문의 수량을 가져온다.
}

@Hint {
현재 수량에서 LAG 결과를 빼면 변화량이다. 창 함수는 SELECT 목록의 다른 식처럼 바로 쓸 수 있다.
}

@Hint {
product 표를 JOIN 해서 상품 이름을 붙이고, product_name 오름차순, order_id 오름차순으로 정렬한다.
}
}

@Quiz(id: over-vs-groupby, answer: groupby-collapses) {
@Question {
GROUP BY 로 묶어 집계하는 것과 SUM(x) OVER (PARTITION BY g) 를 쓰는 것의 차이로 가장 알맞은 것은?
}

@Choice(id: groupby-collapses) {
GROUP BY 는 그룹마다 한 행으로 접지만, OVER (PARTITION BY) 는 원래 행 수를 유지한 채 집계 값을 각 행에 붙인다.
}

@Choice(id: over-collapses-too) {
OVER (PARTITION BY) 도 그룹마다 한 행으로 접히므로 결과가 GROUP BY 와 완전히 같다.
}

@Choice(id: over-no-aggregates) {
OVER 안에는 집계 함수를 쓸 수 없고 ROW_NUMBER 같은 순위 함수만 쓸 수 있다.
}

@Choice(id: partition-needs-groupby) {
PARTITION BY 는 반드시 GROUP BY 와 함께 써야만 동작한다.
}

@Explanation {
창 함수의 핵심은 행을 접지 않는 것이다. SUM 을 포함한 집계 함수도 OVER 를 붙이면 각 행마다 창 위의 집계 값을 붙여 주며, GROUP BY 없이 단독으로 쓸 수 있다.
}
}

@Reflection(id: window-reflection) {
@Prompt(id: partition-vs-groupby-own-words) {
PARTITION BY 로 나눈 창과 GROUP BY 로 묶은 그룹의 차이를 자기만의 비유로 설명해 보라.
}

@Prompt(id: lag-null-handling) {
LAG 의 결과가 NULL 이 되는 행은 언제인가? 변화량 계산에서 그 NULL 을 어떻게 다루면 좋겠는가?
}

@Prompt(id: rank-vs-rownumber) {
RANK 와 ROW_NUMBER 의 결과가 달라지는 상황을 구체적인 데이터 예시를 들어 설명해 보라.
}
}
