@Concept(id: exists-concept) {
지금까지는 서브쿼리의 '값'을 비교에 썼다면, EXISTS 는 서브쿼리의 '결과 자체'를 검사한다. 서브쿼리가 한 행이라도 반환하면 참, 한 행도 반환하지 않으면 거짓이다. 그래서 EXISTS 안에서는 보통 SELECT 1 처럼 실제 값은 중요하지 않고, 조건에 맞는 행이 있는가만 따진다.

서브쿼리가 바깥 쿼리의 열을 참조하면 상관 서브쿼리가 된다. 바깥의 각 행마다 서브쿼리가 한 번씩 평가되므로, '이 고객에게 주문이 하나라도 있는가'처럼 행 단위 존재 검사가 가능하다.

NOT EXISTS 는 반대로 대응되는 행이 하나도 없을 때 참이 된다. LEFT JOIN 다음에 IS NULL 로 거르는 방법과 결과가 같은 경우가 많지만, EXISTS 는 존재 여부만 보므로 서브쿼리 안에서 NULL 이 나와도 결과가 흔들리지 않는다는 장점이 있다.
}

@Example(id: exists-example, language: sql, expected: expected/sql-exists-correlated-subqueries.txt) {
주문 기록이 하나도 없는 고객을 NOT EXISTS 상관 서브쿼리로 찾아 본다. 바깥 쿼리의 각 고객마다 그 고객의 주문이 있는지 검사한다.

```sql
SELECT c.id, c.name
FROM customer c
WHERE NOT EXISTS (
    SELECT 1
    FROM "order" o
    WHERE o.customer_id = c.id
)
ORDER BY c.id;
```
}

@Blank(id: exists-blank, language: sql) {
빈칸을 채워서 한 번도 주문에 담기지 않은 상품의 이름을 찾아라.

```sql
SELECT p.name
FROM product p
WHERE ___1___ (
    SELECT 1
    FROM order_item oi
    WHERE ___2___ = p.id
)
ORDER BY p.id;
```

@Answer(slot: 1) {
`NOT EXISTS`
}

@Answer(slot: 2) {
`oi.product_id`
}
}

@Task(id: exists-task, language: sql, starter: starters/sql-exists-correlated-subqueries.sql, tests: tests/sql-exists-correlated-subqueries.sql, solution: solutions/sql-exists-correlated-subqueries.sql) {
펜(category_id = 1) 상품을 한 번이라도 주문한 적이 있는 고객의 id 와 이름을 고객 id 오름차순으로 조회하라. EXISTS 와 상관 서브쿼리를 사용하고, 결과의 열 이름은 id, name 이 되어야 한다. 주문과 주문 항목은 "order" 와 order_item 표에 있고, 상품의 카테고리는 product 표에서 확인한다.

@Hint {
서브쿼리 안에서 바깥 쿼리의 c.id 를 참조해 각 고객별로 조건을 검사하게 만들어야 한다.
}

@Hint {
"order", order_item, product 세 표를 조인하면 한 고객이 펜 상품을 주문했는지 확인할 수 있다.
}

@Hint {
조건에 맞는 행이 있는지 검사하는 것이므로 NOT 이 아니라 EXISTS 를 쓴다.
}
}

@Quiz(id: exists-quiz, answer: no-matching-row) {
@Question {
NOT EXISTS 에 대한 설명으로 옳은 것은?
}

@Choice(id: no-matching-row) {
상관 서브쿼리에 대응되는 행이 하나도 없을 때 참이 되며, 서브쿼리에서 어떤 값이 나오는지는 중요하지 않다.
}

@Choice(id: all-null) {
서브쿼리 결과가 모두 NULL 일 때만 참이 된다.
}

@Choice(id: row-count) {
EXISTS 는 서브쿼리가 반환한 행의 개수를 결과로 돌려준다.
}

@Choice(id: no-outer-ref) {
EXISTS 서브쿼리 안에서는 바깥 쿼리의 열을 참조할 수 없다.
}

@Explanation {
EXISTS 와 NOT EXISTS 는 행이 존재하는가만 검사하므로 서브쿼리가 어떤 값을 반환하는지는 상관없다. 바깥 열을 참조하는 상관 서브쿼리가 핵심이며, EXISTS 는 행 개수가 아니라 참/거짓을 돌려준다.
}
}

@Reflection(id: exists-reflection) {
@Prompt(id: left-join-vs-not-exists) {
주문이 없는 고객 찾기를 LEFT JOIN + IS NULL 로도, NOT EXISTS 로도 쓸 수 있다. 어떤 상황에서 어느 쪽이 더 읽기 쉬울 것 같은가?
}

@Prompt(id: in-vs-exists) {
IN 서브쿼리와 EXISTS 서브쿼리의 차이를 한 문장으로 설명한다면 어떻게 말하겠는가?
}

@Prompt(id: correlated-cost) {
상관 서브쿼리는 바깥 행마다 한 번씩 평가된다. 데이터가 아주 많아지면 어떤 일이 일어날 수 있을까?
}
}
