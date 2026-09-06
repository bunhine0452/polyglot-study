@Concept(id: dml-basics) {
지금까지는 표에 담긴 데이터를 읽는 SELECT 만 다뤘다. 데이터를 바꾸는 문장은 세 가지다. 행을 넣는 INSERT, 고치는 UPDATE, 지우는 DELETE 다. 셋 다 문장 하나로 표 전체가 아닌 조건에 맞는 대상만 다룰 수 있어서, WHERE 절을 어떻게 쓰느냐가 안전의 핵심이다.

INSERT INTO 표 이름 (열 목록) VALUES (값 목록) 형태로 새 행을 추가한다. 열 목록을 명시하는 습관이 좋다. 표의 열 순서가 바뀌어도 문장이 깨지지 않고, 값을 빠뜨린 것도 바로 보이기 때문이다. VALUES 를 쉼표로 이어 쓰면 한 문장으로 여러 행을 한 번에 넣을 수 있다. id 같은 PRIMARY KEY 열은 표 안에서 유일해야 하므로, 이미 있는 id 를 다시 넣으면 오류가 난다.

UPDATE 표 이름 SET 열 = 새 값 WHERE 조건 형태로 기존 행을 고친다. SET 에서는 stock = stock + 5 처럼 현재 값을 이용한 식도 쓸 수 있다. WHERE 를 빼먹으면 표의 모든 행이 한꺼번에 바뀐다. DELETE FROM 표 이름 WHERE 조건 은 조건에 맞는 행만 지운다. 역시 WHERE 를 생략하면 모든 행이 사라지지만, 표 구조 자체는 남는다.

바뀐 결과를 확인하려면 보통 SELECT 를 다시 실행해야 한다. SQLite 3.35 이상과 PostgreSQL 은 문장 뒤에 RETURNING 열 목록을 붙이면, INSERT·UPDATE·DELETE 가 실제로 넣거나 고치거나 지운 행을 그 자리에서 바로 돌려준다. 결과셋의 모양은 SELECT 와 같아서, 변경 검증을 한 문장으로 끝낼 수 있다.
}

@Example(id: insert-category-returning, language: sql, expected: expected/sql-insert-update-delete.txt) {
새 분류 두 개를 category 표에 한 번에 추가하면서, RETURNING 으로 실제로 들어간 행을 즉시 확인한다.

```sql
INSERT INTO category (id, name) VALUES
  (10, 'toy'),
  (20, 'food')
RETURNING id, name;
```
}

@Blank(id: update-stock-returning, language: sql) {
창고 점검 중이다. 5번 상품의 재고를 10개 늘리고, 어떤 행이 바뀌었는지 바로 확인하는 UPDATE 문이다. 빈칸을 채워 완성하라.

```sql
UPDATE product
SET stock = ___1___
WHERE id = 5
___2___ id, name, stock;
```

@Answer(slot: 1) {
`stock + 10`
}

@Answer(slot: 2) {
`RETURNING`
}
}

@Task(id: insert-new-products, language: sql, starter: starters/sql-insert-update-delete.sql, tests: tests/sql-insert-update-delete.sql, solution: solutions/sql-insert-update-delete.sql) {
문구점에 새 상품이 들어왔다. product 표에 두 행을 추가하라. 첫 번째는 id 101, 이름 '모조지 노트', 분류 1, 가격 1200, 재고 50 이다. 두 번째는 id 102, 이름 '색종이', 분류 1, 가격 500, 재고 200 이다. INSERT 문 마지막에 RETURNING 을 붙여, 추가된 행의 id, name, price 를 이 순서대로 결과로 돌려주게 만들어라.

@Hint {
VALUES 다음에 각 행을 괄호로 묶어 쉼표로 이어 쓰면, INSERT 하나로 여러 행을 한 번에 넣을 수 있다.
}

@Hint {
RETURNING 은 VALUES 목록 뒤, 세미콜론 앞에 붙인다. 반환할 열을 RETURNING id, name, price 처럼 쉼표로 나열하면 된다.
}

@Hint {
아직 행이 하나뿐이다. 두 번째 상품 (102, '색종이', 1, 500, 200) 을 같은 VALUES 안에 추가하고 RETURNING 을 붙여라.
}
}

@Quiz(id: delete-where-semantics, answer: all-rows-deleted) {
@Question {
DELETE FROM product; 처럼 WHERE 를 붙이지 않고 실행하면 어떻게 될까?
}

@Choice(id: error-required) {
WHERE 가 없으면 오류가 나서 아무것도 실행되지 않는다.
}

@Choice(id: all-rows-deleted) {
product 표의 모든 행이 삭제되지만, 표 구조 자체는 남는다.
}

@Choice(id: table-dropped) {
표가 통째로 사라져서 다시 CREATE TABLE 을 해야 한다.
}

@Choice(id: nothing-deleted) {
조건이 없으니 삭제 대상이 없어서 아무 행도 지워지지 않는다.
}

@Explanation {
DELETE 는 WHERE 를 생략하면 조건 없이 표의 모든 행을 지운다. 오류도 나지 않고, 표 정의와 다른 객체는 그대로 남아 표가 사라지는 것도 아니다. 그래서 WHERE 를 먼저 붙여 대상을 RETURNING 이나 SELECT 로 확인한 뒤 지우는 습관이 중요하다.
}
}

@Reflection(id: dml-reflection) {
@Prompt(id: update-without-where) {
UPDATE 에 WHERE 를 깜빡하고 실행했다면 어떤 일이 벌어질까? RETURNING 결과를 보기 전에는 알아차리기 어려운 이유도 함께 적어보자.
}

@Prompt(id: verify-with-select) {
RETURNING 을 지원하지 않는 환경이라면, 추가·수정·삭제 결과를 각각 어떤 SELECT 로 검증할지 구체적으로 설계해보자.
}

@Prompt(id: delete-vs-update) {
실수했을 때 되돌리기 더 어려운 것은 DELETE 일까 UPDATE 일까? 각자의 판단과 이유를 적어보자.
}
}
