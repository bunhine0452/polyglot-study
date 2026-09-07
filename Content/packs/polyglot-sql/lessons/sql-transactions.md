@Concept(id: transaction-basics) {
트랜잭션은 여러 변경 문을 하나의 묶음으로 다루는 장치다. `BEGIN` 으로 묶음을 열고 그 안에서 실행한 `UPDATE` 와 `DELETE` 는 `COMMIT` 전까지 확정되지 않는다. 묶음 안에서 문제가 생겼다면 `ROLLBACK` 을 호출해 지금까지의 모든 변경을 한 번에 되돌릴 수 있다. 이처럼 묶음 전체가 통과하거나 전부 취소되는 성질을 **원자성**이라고 부른다.
}

@Example(id: rollback-demo, language: sql, expected: expected/sql-transactions.txt) {
커밋한 변경은 남고 롤백한 변경은 사라진다. 카테고리 이름 변경은 커밋했고, 주문 항목 전체 삭제와 재고 초기화는 롤백했다. 마지막 SELECT 는 이 두 트랜잭션이 끝난 뒤의 최종 상태를 보여 준다.

```sql
BEGIN;
UPDATE category SET name = name || '-renamed' WHERE name = 'paper';
COMMIT;
BEGIN;
DELETE FROM order_item;
UPDATE product SET stock = 0;
ROLLBACK;
SELECT (SELECT COUNT(*) FROM category WHERE name = 'paper') AS paper_count,
       (SELECT COUNT(*) FROM order_item) AS item_count;
```
}

@Blank(id: blank-commit-rollback, language: sql) {
첫 번째 트랜잭션의 가격 인상은 확정하고, 두 번째 트랜잭션의 삭제는 되돌리려고 한다. 두 트랜잭션이 각각 무엇을 남기는지 빈칸을 채워 확인해 보자.

```sql
BEGIN;
UPDATE product SET price = price + 500 WHERE category_id = 1;
___1___;
BEGIN;
DELETE FROM order_item WHERE quantity > 3;
___2___;
SELECT (SELECT COUNT(*) FROM order_item) AS item_count;
```

@Answer(slot: 1) {
`COMMIT`
}

@Answer(slot: 2) {
`ROLLBACK`
}
}

@Task(id: task-rollback-proof, language: sql, starter: starters/sql-transactions.sql, tests: tests/sql-transactions.sql, solution: solutions/sql-transactions.sql) {
배치 작업을 시험 삼아 돌려 보는 상황이다. 트랜잭션을 열고 다음 세 가지 변경을 시도한다: product 의 재고를 두 배로 만들기, shipped_at 이 NULL 이 아닌 주문 삭제, city 가 NULL 인 고객의 city 를 '알수없음' 으로 바꾸기. 이어서 ROLLBACK 으로 전부 되돌리고, 마지막 SELECT 하나로 원래 상태로 돌아왔음을 증명하라. 최종 SELECT 는 total_orders(전체 주문 수), shipped_orders(shipped_at 이 NULL 이 아닌 주문 수), missing_city(city 가 NULL 인 고객 수) 세 열을 이 순서대로 한 행으로 내놓아야 한다.

@Hint {
ROLLBACK 은 BEGIN 이후의 모든 DML 을 문장 단위가 아니라 트랜잭션 단위로 되돌린다.
}

@Hint {
증명 SELECT 는 롤백이 끝난 뒤에 실행되므로, 모든 값이 변경 전의 원래 값이어야 한다.
}

@Hint {
shipped_at 이 NULL 이 아닌 주문은 조건 WHERE shipped_at IS NOT NULL 로 고른다.
}
}

@Quiz(id: quiz-atomicity, answer: both-undone) {
@Question {
BEGIN 을 열고 UPDATE 두 문장을 실행한 뒤 ROLLBACK 을 실행했다. 이 시점의 테이블 상태는 어떠한가?
}

@Choice(id: both-undone) {
두 UPDATE 모두 적용되지 않은, BEGIN 직전의 원래 상태다
}

@Choice(id: first-applied) {
먼저 실행한 첫 UPDATE 만 적용되어 있다
}

@Choice(id: both-applied) {
ROLLBACK 은 SELECT 결과만 되돌리므로 두 UPDATE 모두 적용되어 있다
}

@Choice(id: needs-commit) {
COMMIT 없이 ROLLBACK 은 무시되므로 두 UPDATE 모두 적용되어 있다
}

@Explanation {
ROLLBACK 은 BEGIN 이후 실행된 모든 DML 을 한꺼번에 취소한다. 취소 단위가 개별 문장이 아니라 트랜잭션 전체이므로 부분 적용은 일어나지 않으며, COMMIT 여부와 무관하게 언제든 되돌릴 수 있다.
}
}

@Reflection(id: reflect-transactions) {
@Prompt(id: real-moment) {
ROLLBACK 이 필요했을 법한 실제 서비스의 순간을 하나 상상하고, 어떤 변경 묶음을 통째로 취소했을지 적어 보자.
}

@Prompt(id: half-applied) {
여러 표에 걸친 연쇄 변경에서 절반만 적용되고 끊긴다면 데이터가 어떻게 어긋날지, 이 팩의 표를 예로 들어 구체적으로 적어 보자.
}

@Prompt(id: left-open) {
COMMIT 도 ROLLBACK 도 하지 않은 채 트랜잭션을 열어 두기만 하면 어떤 문제가 생길 수 있을지 생각해 보자.
}
}
