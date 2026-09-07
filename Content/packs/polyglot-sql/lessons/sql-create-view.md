@Concept(id: create-view-basics) {
뷰는 이름을 붙여 저장해 둔 SELECT 쿼리다. CREATE VIEW 뷰이름 AS SELECT ... 형태로 만들면, 이후에는 테이블처럼 FROM 뷰이름 으로 조회할 수 있다. 뷰는 데이터를 복사해 두는 게 아니라 조회할 때마다 저장된 쿼리를 다시 실행하므로, 원본 테이블이 바뀌면 뷰의 결과도 함께 바뀐다. 복잡한 조인과 GROUP BY 를 뷰로 한 번 저장해 두면 WHERE 를 덧붙이는 것만으로 원하는 부분만 다시 꺼낼 수 있고, 필요 없어지면 DROP VIEW 뷰이름; 으로 정의만 지우면 된다. 한 가지 주의할 점은 order 라는 표 이름이 예약어라서 쿼리 안에서는 반드시 "order" 처럼 큰따옴표로 감싸야 한다는 것이다.
}

@Example(id: create-reuse-drop-view, language: sql, expected: expected/sql-create-view.txt) {
고객별 주문 건수를 계산하는 쿼리를 customer_order_stats 뷰로 저장한 뒤, 뷰를 조회하고 WHERE 를 덧붙여 재활용하고, 지웠다가 다시 만들어 본다.

```sql
CREATE VIEW customer_order_stats AS
SELECT c.name AS name, COUNT(o.id) AS order_count
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name;

SELECT COUNT(*) AS n_customers, SUM(order_count) AS total_orders
FROM customer_order_stats;

SELECT name, order_count
FROM customer_order_stats
WHERE order_count = 0
ORDER BY name;

DROP VIEW customer_order_stats;

CREATE VIEW customer_order_stats AS
SELECT c.name AS name, COUNT(o.id) AS order_count
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name;

SELECT COUNT(*) AS n_customers
FROM customer_order_stats;
```
}

@Blank(id: fill-view-reuse, language: sql) {
뷰를 만들고 바로 재활용하는 코드다. 빈칸을 채워 주문이 없는 고객 두 명을 조회해 보자.

```sql
CREATE VIEW customer_order_stats AS
SELECT c.name AS name, ___1___ AS order_count
FROM customer c
LEFT JOIN "order" o ON o.customer_id = c.id
GROUP BY c.id, c.name;

SELECT name, order_count
FROM ___2___
WHERE order_count = 0
ORDER BY name;
```

@Answer(slot: 1) {
`COUNT(o.id)`
}

@Answer(slot: 2) {
`customer_order_stats`
}
}

@Task(id: build-and-reuse-view, language: sql, starter: starters/sql-create-view.sql, tests: tests/sql-create-view.sql, solution: solutions/sql-create-view.sql) {
customer_order_stats 뷰를 직접 만들고 재활용해 보세요. 뷰는 고객 이름(name)과 주문 건수(order_count)를 담아야 하고, 주문을 한 번도 하지 않은 고객도 0건으로 포함해야 합니다. 스크립트 마지막에는 뷰에서 order_count 가 0인 고객의 name 과 order_count 를 이름 오름차순으로 조회하는 SELECT 를 두세요. 이 SELECT 의 결과가 채점 기준이 됩니다.

@Hint {
LEFT JOIN 으로 주문이 없는 고객도 결과에 남긴 뒤, GROUP BY 로 고객별로 묶으세요.
}

@Hint {
COUNT(*) 대신 COUNT(o.id) 를 세면 주문이 없는 고객의 건수가 0 이 됩니다.
}

@Hint {
뷰를 만든 뒤에는 FROM 뒤에 테이블 이름 대신 뷰 이름을 쓰고, WHERE 를 덧붙이면 원하는 부분만 꺼낼 수 있습니다.
}
}

@Quiz(id: quiz-view-semantics, answer: stored-query-rerun) {
@Question {
뷰(view)에 대한 설명으로 옳은 것은?
}

@Choice(id: stored-query-rerun) {
뷰는 쿼리에 이름을 붙여 저장한 것으로, 조회할 때마다 저장된 SELECT 가 다시 실행된다.
}

@Choice(id: copies-data) {
뷰를 만들면 원본 테이블의 데이터가 복사되어 뷰 안에 물리적으로 저장된다.
}

@Choice(id: drop-deletes-table) {
DROP VIEW 를 실행하면 뷰뿐 아니라 원본 테이블의 데이터까지 함께 삭제된다.
}

@Choice(id: no-where-on-view) {
뷰 위에서 WHERE 를 쓰면 오류가 나므로 뷰는 반드시 통째로만 조회해야 한다.
}

@Explanation {
뷰는 데이터를 담지 않고 SELECT 쿼리의 정의만 저장한다. 조회할 때마다 저장된 쿼리가 실행되므로 원본 테이블이 바뀌면 뷰의 결과도 따라 바뀌고, DROP VIEW 는 뷰 정의만 지울 뿐 원본 테이블은 그대로 남는다. 뷰 위에서도 WHERE 와 GROUP BY 를 자유롭게 덧붙일 수 있다.
}
}

@Reflection(id: reflect-view-usage) {
@Prompt(id: with-vs-view) {
WITH 절로 만든 임시 결과와 CREATE VIEW 로 저장한 뷰는 쓰임이 어떻게 다를까? 어떤 상황에서는 뷰가 더 유용할까?
}

@Prompt(id: sharing-view) {
여러 사람이 같은 통계 쿼리를 매일 반복해서 실행한다면, 그 쿼리를 뷰로 만들어 두었을 때 얻는 장점과 주의해야 할 점은 무엇일까?
}

@Prompt(id: fixing-view) {
이미 만들어 둔 뷰의 정의를 고쳐야 한다면 어떤 방법들이 있을까? DROP VIEW 후 다시 만드는 것 말고 다른 방법이 있는지 찾아보자.
}
}
