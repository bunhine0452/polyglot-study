@Concept(id: dml-basics) {
INSERT INTO 표이름 (열 목록) VALUES (값 목록) 은 표에 새 행을 추가하고, UPDATE 표이름 SET 열 = 값 WHERE 조건 은 조건에 맞는 기존 행의 값을 바꾸며, DELETE FROM 표이름 WHERE 조건 은 조건에 맞는 행을 지운다. WHERE 는 어느 행에 적용할지 좁히는 절일 뿐 필수가 아니어서, 빠뜨리면 표의 모든 행이 수정·삭제 대상이 되므로 특히 주의해야 한다. 이번 팩의 데이터를 다룰 때는 표 이름 order 가 예약어이므로 DELETE FROM "order" 처럼 반드시 큰따옴표로 감싸야 한다. 문장 끝에 RETURNING 열목록 을 붙이면 방금 추가·수정·삭제된 행을 곧바로 결과셋으로 돌려받아, 별도의 SELECT 로 검증하는 수고를 덜 수 있다.
}

@Example(id: insert-returning-example, language: sql, expected: expected/sql-insert-update-delete.txt) {
새 상품 한 행을 product 표에 추가하면서, RETURNING 으로 추가된 행의 일부 열을 즉시 돌려받는 예제다.

```sql
INSERT INTO product (id, name, category_id, price, stock)
VALUES (11, '노트북 파우치', 3, 19000, 40)
RETURNING id, name, price;
```
}

@Blank(id: update-delete-blank, language: sql) {
카테고리가 아직 정해지지 않은 상품의 재고를 보충하는 UPDATE 와, 아직 배송되지 않은 주문을 정리하는 DELETE 가 이어진 스크립트다. 빈칸에 알맞은 것을 채워 완성하라.

```sql
UPDATE product
SET stock = stock + 5
WHERE ___1___ IS NULL;

DELETE FROM "order"
WHERE shipped_at IS ___2___;
```

@Answer(slot: 1) {
`category_id`
}

@Answer(slot: 2) {
`NULL`
}
}

@Task(id: insert-customer-task, language: sql, starter: starters/sql-insert-update-delete.sql, tests: tests/sql-insert-update-delete.sql, solution: solutions/sql-insert-update-delete.sql) {
customer 표에 신규 고객 한 행을 추가하라. id 는 7, name 은 '차돌박', city 는 '대구', joined_on 은 '2024-07-01' 이다. INSERT 문 끝에 RETURNING 을 붙여 추가된 행의 id 와 name 두 열을 결과로 돌려받아라.

@Hint {
INSERT INTO 표이름 (열1, 열2, ...) VALUES (값1, 값2, ...) 형태로 쓴다.
}

@Hint {
city 와 joined_on 도 빠뜨리지 말고 열 목록에 넣어라.
}

@Hint {
RETURNING 은 세미콜론 앞 문장 맨 끝에 붙이고, 돌려받을 열을 쉼표로 나열한다.
}
}

@Quiz(id: update-no-where-quiz, answer: all-rows-updated) {
@Question {
UPDATE product SET price = 0 문장에서 WHERE 절을 빠뜨리면 어떻게 되는가?
}

@Choice(id: all-rows-updated) {
조건이 없으므로 product 표의 모든 행이 price 0 으로 바뀐다.
}

@Choice(id: syntax-error) {
WHERE 가 없으면 문법 오류가 나서 아예 실행되지 않는다.
}

@Choice(id: first-row-only) {
WHERE 가 없으면 첫 번째 행만 수정된다.
}

@Choice(id: no-change) {
조건을 판단할 수 없으므로 아무 행도 바뀌지 않는다.
}

@Explanation {
WHERE 는 적용 대상 행을 좁히는 선택 절이지 필수 문법이 아니므로, 생략하면 표의 모든 행이 수정 대상이 된다. 그래서 UPDATE 나 DELETE 를 쓸 때는 WHERE 를 먼저 쓰고 조건을 채우는 습관이 안전하다.
}
}

@Reflection(id: dml-reflection) {
@Prompt(id: preview-before-change) {
UPDATE 나 DELETE 를 실행하기 전에 WHERE 조건에 맞는 행이 무엇인지 먼저 눈으로 확인하고 싶다면, 같은 WHERE 를 어떤 문장에 붙여서 써 보겠는가? 구체적인 문장 형태를 말해 보라.
}

@Prompt(id: returning-benefit) {
RETURNING 이 없던 시절에는 변경이 잘 됐는지 확인하려면 어떤 절차가 더 필요했을까? RETURNING 이 줄여 주는 단계를 정리해 보라.
}

@Prompt(id: recovery-after-mistake) {
WHERE 를 빠뜨린 DELETE 를 이미 실행해 버렸다면, 지워진 행을 되돌리려면 어떤 정보가 미리 기록되어 있어야 할까?
}
}
