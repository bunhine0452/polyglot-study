@Concept(id: multi-join-chain-concept) {
## 조인 체인과 연결 표

세 개 이상의 표를 연결하는 것은 두 표를 연결하는 일을 여러 번 반복하는 것과 같다. 각 `JOIN` 은 앞에서 만들어진 중간 결과에 다음 표를 한 단계씩 붙이므로, 이 흐름을 **조인 체인**이라고 부른다.

여기서 핵심은 **연결 표(bridge table)** 인 `order_item` 이다. 한 주문에는 여러 상품이 담기고, 한 상품은 여러 주문에 담길 수 있으므로 주문과 상품은 다대다 관계다. 이 다대다를 주문 품목 하나당 한 행으로 풀어 둔 것이 `order_item` 이고, 따라서 `customer` 에서 `product` 로 가려면 반드시 이 표를 거쳐야 한다.

INNER JOIN 으로 네 표를 모두 연결하면 최종 행 수는 `order_item` 의 행 수와 같아진다. 주문 품목 하나가 조인 체인을 통과한 결과 한 행이 되기 때문이다. 그래서 `GROUP BY` 와 함께 쓰면 주문별·고객별 구매 내역을 자연스럽게 집계할 수 있다.
}

@Example(id: multi-join-chain-example, language: sql, expected: expected/sql-multi-table-joins.txt) {
아래 질의는 customer 에서 출발해 order, order_item, product 를 차례로 연결한 뒤, 체인을 통과한 행이 몇 행인지 센다.

```sql
SELECT COUNT(*) AS item_rows
FROM customer c
JOIN "order" o ON o.customer_id = c.id
JOIN order_item oi ON oi.order_id = o.id
JOIN product p ON p.id = oi.product_id;
```
}

@Blank(id: multi-join-chain-blank, language: sql) {
customer 에서 출발해 order, order_item, product 까지 이어지는 조인 체인의 조인 조건을 완성해라.

```sql
SELECT cu.name AS customer, p.name AS product, oi.quantity
FROM customer cu
JOIN "order" o ON o.customer_id = ___1___
JOIN order_item oi ON ___2___ = o.id
JOIN product p ON p.id = ___3___
ORDER BY o.id, p.name;
```

@Answer(slot: 1) {
`cu.id`
}

@Answer(slot: 2) {
`oi.order_id`
}

@Answer(slot: 3) {
`oi.product_id`
}
}

@Task(id: customer-total-spent-task, language: sql, starter: starters/sql-multi-table-joins.sql, tests: tests/sql-multi-table-joins.sql, solution: solutions/sql-multi-table-joins.sql) {
고객별 총 구매 금액을 계산하라. customer 에서 출발해 order, order_item, product 를 INNER JOIN 으로 연결하고, 품목마다 quantity * price 를 곱한 값을 고객별로 합산하라. 주문이 하나도 없는 고객은 결과에서 자연스럽게 제외된다. 출력 열은 고객 이름의 별칭이 customer, 합계의 별칭이 total_spent 여야 하고, total_spent 기준 내림차순으로 정렬하되 총액이 같으면 customer 이름 오름차순으로 정렬하라.

@Hint {
order 와 product 사이에는 order_item 이라는 다리 표가 있으므로 두 번의 조인을 추가로 거쳐야 한다.
}

@Hint {
집계할 값은 quantity 와 price 를 곱한 품목 금액이고, 이를 고객별로 SUM 한다.
}

@Hint {
여러 조인을 거치면 INNER JOIN 은 한 번이라고 연결되지 않은 고객의 행을 모두 버린다는 점을 이용하라.
}
}

@Quiz(id: bridge-table-quiz, answer: many-to-many-bridge) {
@Question {
고객이 구매한 상품을 조회할 때 order_item 표를 반드시 거쳐야 하는 이유로 가장 적절한 것은?
}

@Choice(id: many-to-many-bridge) {
customer 와 product 는 다대다로 연결되어 있어서, 주문 품목 단위로 행을 풀어 둔 order_item 이라는 연결 표를 거쳐야 하기 때문이다.
}

@Choice(id: order-has-product-id) {
"order" 표에도 product_id 열이 있으므로 order_item 을 거치지 않아도 order 를 통해 product 에 바로 조인할 수 있기 때문이다.
}

@Choice(id: auto-cross-product) {
조인 대상 표가 세 개를 넘으면 데이터베이스가 자동으로 교차 조합을 만들어 주므로 order_item 이 필요 없기 때문이다.
}

@Choice(id: aggregate-only-table) {
order_item 은 집계 결과를 보관하는 전용 표라서 조인 체인 중간에는 사용할 수 없기 때문이다.
}

@Explanation {
한 주문에 여러 상품이 담기고 한 상품이 여러 주문에 담기는 다대다 관계는 두 표 어느 쪽에도 외래 키 하나로 담을 수 없어서, 품목 하나당 한 행인 order_item 이 그 연결을 대신 저장한다. "order" 표에는 product_id 열이 없고, 데이터베이스가 임의의 조합을 만들어 주지도 않으며, order_item 은 실제 품목 데이터가 담긴 일반 표라서 얼마든지 조인에 쓸 수 있다.
}
}

@Reflection(id: multi-join-chain-reflection) {
@Prompt(id: row-count-prompt) {
customer 에서 출발해 order, order_item, product 까지 INNER JOIN 으로 연결하면 최종 행 수가 order_item 의 행 수와 같아지는 이유를 품목 한 행의 관점에서 설명해 보라.
}

@Prompt(id: left-join-prompt) {
주문이 없는 고객도 총 구매액 0 으로 함께 보고 싶다면 INNER JOIN 대신 무엇을 어떻게 바꿔야 할까? 이때 SUM 값이 NULL 로 나오는 행은 어떻게 다루면 좋을지 생각해 보라.
}

@Prompt(id: chain-order-prompt) {
조인 체인에서 표를 연결하는 순서를 order 를 먼저 시작하는 것과 customer 를 먼저 시작하는 것 중 바꾸면 결과 집합이 달라질까? INNER JOIN 에서 조인 순서가 결과에 주는 영향을 정리해 보라.
}
}
