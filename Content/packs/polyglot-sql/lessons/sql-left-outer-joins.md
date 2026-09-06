@Concept(id: left-join-null-fill) {
지난 레슨에서 쓴 INNER JOIN 은 양쪽 테이블에 모두 매칭되는 행만 남긴다. 그래서 왼쪽 테이블에는 있는데 오른쪽에 짝이 없는 행은 결과에서 조용히 사라진다.

**LEFT JOIN** 은 왼쪽 테이블의 모든 행을 결과에 유지하고, 매칭되는 오른쪽 행이 없으면 오른쪽 열 전부를 NULL 로 채워 넣는다. 이렇게 한쪽을 기준으로 삼아 행을 남기는 조인을 외부 조인(OUTER JOIN) 이라 부른다.

매칭되지 않은 행이 결과에 남아 있으면 두 가지를 활용할 수 있다. 첫째, `COUNT(오른쪽열)` 은 NULL 이 아닌 값만 세므로 매칭 없는 행은 자연스럽게 0 이 된다. 반면 `COUNT(*)` 는 NULL 이 채워진 행도 세므로 두 값이 달라진다. 둘째, `WHERE 오른쪽열 IS NULL` 조건을 붙이면 매칭되지 않은 왼쪽 행만 골라낼 수 있다. 이 패턴을 안티 조인(anti join) 이라 부른다.
}

@Example(id: left-join-count-diff, language: sql, expected: expected/sql-left-outer-joins.txt) {
고객은 6명이고 주문은 7건이며, 그중 두 고객(정바람, 한별빛)은 주문이 하나도 없다. LEFT JOIN 결과에서 세 가지 세기를 비교하면 매칭되지 않은 행이 결과에 남는 것을 숫자로 확인할 수 있다.

```sql
SELECT COUNT(*) AS joined_rows,
       COUNT(o.id) AS matched_rows,
       COUNT(*) - COUNT(o.id) AS unmatched_rows
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id;
```
}

@Blank(id: blank-left-join-is-null, language: sql) {
주문 기록이 하나도 없는 고객의 이름만 골라 조회하는 질의다. 조인 방식과 NULL 검사 조건을 채워 왼쪽 테이블의 모든 행을 유지한 뒤, 그중 매칭되지 않은 행만 남겨라.

```sql
SELECT c.name
FROM customer c
___1___ JOIN "order" o ON o.customer_id = c.id
WHERE o.id ___2___ NULL
ORDER BY c.name;
```

@Answer(slot: 1) {
`LEFT`
}

@Answer(slot: 2) {
`IS`
}
}

@Task(id: task-order-count-per-customer, language: sql, starter: starters/sql-left-outer-joins.sql, tests: tests/sql-left-outer-joins.sql, solution: solutions/sql-left-outer-joins.sql) {
고객별로 주문 건수를 집계하라. 주문이 없는 고객도 결과에 포함되어 order_count 가 0 이 되어야 한다. 출력 열은 name, order_count 순서로 하고, order_count 기준 내림차순으로 정렬하되 값이 같으면 name 기준 오름차순으로 정렬하라.

@Hint {
INNER JOIN 은 매칭되지 않은 왼쪽 행을 버린다. LEFT JOIN 으로 바꾸면 주문 없는 고객 행이 결과에 남는다.
}

@Hint {
COUNT(o.id) 는 o.id 가 NULL 이 아닌 행만 세므로, 매칭되지 않은 고객은 자연스럽게 0 이 된다.
}

@Hint {
열 별칭(name, order_count)과 정렬 조건을 지시문과 똑같이 맞춰야 채점 결과셋이 일치한다.
}
}

@Quiz(id: quiz-left-join-row-count, answer: rows-9) {
@Question {
customer 테이블은 6행, "order" 테이블은 7행이다. 모든 주문의 customer_id 는 유효한 고객을 가리키고, 주문이 없는 고객은 2명이다. SELECT COUNT(*) FROM customer c LEFT JOIN "order" o ON o.customer_id = c.id 의 결과는 몇인가?
}

@Choice(id: rows-7) {
7 — INNER JOIN 과 결과 행 수가 같다.
}

@Choice(id: rows-9) {
9 — 주문이 있는 고객의 7행에 주문 없는 고객 2행이 더해진다.
}

@Choice(id: rows-6) {
6 — LEFT JOIN 결과의 행 수는 항상 왼쪽 테이블 행 수와 같다.
}

@Choice(id: rows-13) {
13 — 두 테이블 행 수를 모두 더한 값이다.
}

@Explanation {
주문이 있는 고객 4명은 자기 주문 수만큼(합계 7) 행을 만들고, 주문이 없는 고객 2명은 오른쪽이 NULL 로 채워진 채 각각 1행씩 남는다. 따라서 7 + 2 = 9행이다. 7 은 INNER JOIN 의 결과이고, 6 은 LEFT JOIN 행 수가 항상 왼쪽 테이블과 같다는 오해에서, 13 은 두 테이블을 단순히 더한 값에서 온 그릇된 답이다.
}
}

@Reflection(id: reflect-left-join) {
@Prompt(id: prompt-row-diff) {
INNER JOIN 을 LEFT JOIN 으로 바꾸면 결과 행 수가 늘어나는 이유를, 매칭되지 않은 행이 어떤 값으로 채워지는지와 함께 우리 데이터의 예를 들어 설명해 보라.
}

@Prompt(id: prompt-anti-join) {
LEFT JOIN 뒤에 WHERE o.id IS NULL 을 붙이면 왜 '매칭되지 않은 왼쪽 행'만 골라내는 필터로 동작하는가? 매칭된 행에서 o.id 의 값은 어떤지 생각해 보라.
}

@Prompt(id: prompt-count-diff) {
LEFT JOIN 결과에서 COUNT(*) 와 COUNT(o.id) 의 값이 달라질 수 있는 이유는 무엇인가? 이 레슨의 예제에서 나온 숫자를 인용해 답해 보라.
}
}
