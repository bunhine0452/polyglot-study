@Concept(id: upsert-concept) {
UNIQUE 제약이나 기본 키가 걸린 열에 이미 있는 값을 다시 넣으려고 하면 INSERT 는 충돌 오류로 실패한다. ON CONFLICT 절을 붙이면 충돌이 났을 때 오류 대신 DO UPDATE 로 이어져, 있는 행은 갱신하고 없는 행은 그대로 삽입하는 동작을 하나의 문장으로 만들 수 있다. 이 패턴을 UPSERT 라고 부른다. DO UPDATE SET 절에서는 excluded 접두어로 "충돌해서 들어오다 만 새 값"을 참조할 수 있고, 접두어 없는 열 이름은 기존 행의 현재 값을 가리킨다. 충돌을 갱신이 아니라 조용히 무시하고 싶을 때는 ON CONFLICT DO NOTHING 또는 INSERT OR IGNORE 를 쓴다.
}

@Example(id: upsert-example, language: sql, expected: expected/sql-upsert-on-conflict.txt) {
category 표에 id 1 은 이미 있는 행이므로 이름이 새 값으로 갱신되고, id 4 는 없는 행이므로 새로 삽입된다. RETURNING 절이 실제로 반영된 행을 보여준다.

```sql
INSERT INTO category (id, name)
VALUES (1, '사무용품'), (4, '장난감')
ON CONFLICT (id) DO UPDATE SET name = excluded.name
RETURNING id, name;
```
}

@Blank(id: upsert-blank, language: sql) {
product 표에 새 상품을 넣되, 같은 id 가 이미 있으면 오류 대신 가격과 재고를 새 값으로 갱신하는 UPSERT 를 완성해라.

```sql
INSERT INTO product (id, name, price, stock)
VALUES (11, '클립 보관함', 1200, 40)
ON CONFLICT (___1___) DO UPDATE
SET price = ___2___.price,
    stock = ___3___.stock;
```

@Answer(slot: 1) {
`id`
}

@Answer(slot: 2) {
`excluded`
}

@Answer(slot: 3) {
`excluded`
}
}

@Task(id: upsert-task, language: sql, starter: starters/sql-upsert-on-conflict.sql, tests: tests/sql-upsert-on-conflict.sql, solution: solutions/sql-upsert-on-conflict.sql) {
product 표에 두 행을 UPSERT 하라. id 1 인 행이 이미 있으면 가격을 2000, 재고를 30 으로 갱신하고, id 11 인 '미니 스테이플러'(category_id NULL, 가격 3500, 재고 10)는 새로 삽입한다. 문장 마지막에 RETURNING id, price, stock 을 붙여 실제로 반영된 두 행을 결과셋으로 돌려라.

@Hint {
여러 행을 VALUES 에 쉼표로 나열해 한 문장에서 처리할 수 있다.
}

@Hint {
충돌 시 새로 넣으려던 값은 excluded.가격열 처럼 excluded 접두어로 참조한다.
}

@Hint {
RETURNING 절을 문장 맨 끝에 붙이면 반영된 행이 결과셋으로 나온다.
}
}

@Quiz(id: upsert-quiz, answer: new-value) {
@Question {
ON CONFLICT (id) DO UPDATE SET price = excluded.price 에서 excluded.price 는 무엇을 가리키는가?
}

@Choice(id: new-value) {
이번 INSERT 로 넣으려다 충돌한 새 값
}

@Choice(id: existing-value) {
충돌이 난 기존 행이 현재 갖고 있는 값
}

@Choice(id: null-value) {
충돌이 나면 항상 NULL 이 된다
}

@Choice(id: conflict-column) {
충돌을 일으킨 제약 조건이 걸린 열의 이름
}

@Explanation {
excluded 는 삽입하려다 충돌로 밀려난 "새 행"을 가상으로 참조하는 접두어다. 접두어 없이 price 라고 쓰면 그 반대인 기존 행의 현재 값을 가리킨다.
}
}

@Reflection(id: upsert-reflection) {
@Prompt(id: when-update-vs-ignore) {
같은 충돌 상황에서 DO UPDATE 로 갱신하는 것이 맞을 때와, INSERT OR IGNORE 로 조용히 건너뛰는 것이 맞을 때를 각각 하나씩 예를 들어 설명해 보라.
}

@Prompt(id: ignore-hides-errors) {
INSERT OR IGNORE 는 제약 위반을 오류조차 만들지 않는다. 이 조용한 성격이 어떤 상황에서 버그를 숨길 수 있을지 생각해 보라.
}

@Prompt(id: batch-upsert) {
외부에서 받은 수백 건의 상품 데이터를 매일 product 표에 반영한다고 할 때, UPSERT 하나로 해결되는 일을 INSERT 와 UPDATE 를 따로 쓰면 어떻게 복잡해지는지 서술해 보라.
}
}
