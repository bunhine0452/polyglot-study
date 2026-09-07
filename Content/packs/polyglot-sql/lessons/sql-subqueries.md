@Concept(id: subquery-basics) {
서브쿼리는 쿼리 안에 괄호로 감싸 넣은 또 다른 SELECT 입니다. WHERE 절에서 결과가 한 행 한 열인 **스칼라 서브쿼리**는 `=`, `>`, `<` 같은 비교 연산자의 오른쪽에 놓여, "평균보다 비싼"처럼 실행 시점에 계산되는 기준으로 행을 걸러 냅니다. `IN` 뒤에 서브쿼리를 두면 서브쿼리가 만든 값 목록에 속한 행만 남고, `NOT IN` 은 그 목록에 **속하지 않는** 행을 고릅니다. 다만 서브쿼리 결과에 NULL 이 섞이면 NOT IN 은 아무 행도 반환하지 않으므로, 목록의 열이 NULL 이 될 수 없는지 먼저 확인하는 습관이 필요합니다.
}

@Example(id: avg-scalar-subquery, language: sql, expected: expected/sql-subqueries.txt) {
평균보다 비싼 상품을 질의 한 번으로 찾습니다. WITH 절로 작은 데모 테이블을 만들어 두었으니, 안쪽 서브쿼리가 평균 가격 1680.0 을 계산하고 바깥 질의가 그 값을 기준으로 행을 걸러 내는 흐름을 따라가 보세요.

```sql
WITH demo_product(id, name, price) AS (
  VALUES (1, '노트', 1200),
         (2, '펜', 800),
         (3, '자', 1500),
         (4, '가위', 4000),
         (5, '풀', 900)
)
SELECT name, price
FROM demo_product
WHERE price > (SELECT AVG(price) FROM demo_product);
```
}

@Blank(id: blank-in-and-max, language: sql) {
최고가 상품과, 900 이하인 싼 물건 목록에 속한 상품을 한 번에 골라 내는 질의입니다. 빈칸 두 곳을 채워 완성하세요.

```sql
WITH demo_product(id, name, price) AS (
  VALUES (1, '노트', 1200),
         (2, '펜', 800),
         (3, '자', 1500),
         (4, '가위', 4000),
         (5, '풀', 900)
)
SELECT name, price
FROM demo_product
WHERE price = (SELECT ___1___(price) FROM demo_product)
   OR id ___2___ (SELECT id FROM demo_product WHERE price <= 900);
```

@Answer(slot: 1) {
`MAX`
}

@Answer(slot: 2) {
`IN`
}
}

@Task(id: task-never-ordered, language: sql, starter: starters/sql-subqueries.sql, tests: tests/sql-subqueries.sql, solution: solutions/sql-subqueries.sql) {
한 번도 주문한 적이 없는 고객을 찾습니다. customer 표에서 id 가 "order" 표의 customer_id 목록에 속하지 **않는** 고객의 name 을 조회하고, ORDER BY name 으로 이름 순으로 정렬하세요. 안쪽 서브쿼리는 SELECT customer_id FROM "order" 형태여야 하고, 바깥 질의에서 NOT IN 을 사용해야 합니다. 결과 열은 name 하나뿐입니다.

@Hint {
안쪽 서브쿼리로 주문 이력이 있는 고객의 customer_id 목록부터 만듭니다.
}

@Hint {
바깥 질의에서 NOT IN 을 써 그 목록에 없는 고객만 남깁니다.
}

@Hint {
정렬은 바깥 질의 마지막에 ORDER BY name 을 붙여 처리합니다.
}
}

@Quiz(id: quiz-not-in-null, answer: no-rows) {
@Question {
NOT IN 뒤의 서브쿼리 결과 목록에 NULL 이 하나라도 포함되어 있으면 어떻게 될까요?
}

@Choice(id: no-rows) {
조건이 참이 될 수 없어서 아무 행도 반환되지 않는다
}

@Choice(id: ignore-null) {
NULL 을 무시하고 나머지 값들만 비교해 정상적인 결과를 반환한다
}

@Choice(id: syntax-error) {
NULL 때문에 구문 오류가 발생해 쿼리 자체가 실행되지 않는다
}

@Explanation {
x NOT IN (목록) 은 목록의 모든 값과 같지 않다는 뜻인데, NULL 과의 비교는 UNKNOWN 이 되어 전체 조건이 참으로 확정되지 않습니다. 그래서 결과가 빈 집합이 됩니다. NOT IN 을 쓸 때는 서브쿼리가 NULL 을 만들지 않는지 확인해야 합니다.
}
}

@Reflection(id: reflect-subquery) {
@Prompt(id: two-step) {
서브쿼리를 쓰지 않으면 같은 질문을 두 단계 질의로 나눠 풀어야 합니다. 첫 단계에서 무엇을 얻고, 그 결과를 두 번째 질의에 어떻게 옮겨야 할지 손으로 적어 보세요.
}

@Prompt(id: null-check) {
IN 과 NOT IN 을 쓰기 전에 서브쿼리 결과에 NULL 이 섞였는지 확인하는 이유를 자기 말로 설명해 보세요.
}

@Prompt(id: vs-join) {
이번 과제는 LEFT JOIN 으로도 풀 수 있습니다. 서브쿼리 풀이와 조인 풀이 중 어느 쪽이 더 읽기 쉬웠고, 왜 그렇게 느꼈는지 적어 보세요.
}
}
