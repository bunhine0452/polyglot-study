@Concept(id: create-table-constraints) {
지금까지는 준비된 표를 조회만 했지만, CREATE TABLE 문으로 표를 직접 만들 수 있다. 각 열에는 INTEGER, TEXT 같은 타입을 지정하고, 이어서 제약(constraint)을 붙여 잘못된 데이터의 입력을 막는다.
PRIMARY KEY 는 각 행을 유일하게 식별하는 열이고, UNIQUE 는 중복 값을, NOT NULL 은 값이 없는 경우를 거부한다.
FOREIGN KEY 는 열 정의 뒤에 REFERENCES 다른표(열) 형태로 선언해 표 사이의 관계를 강제하고, CHECK 는 괄호 안의 조건을 만족하는 값만 허용한다.
제약을 위반하는 INSERT 는 기본적으로 오류와 함께 거부되는데, INSERT OR IGNORE 를 쓰면 위반된 행만 조용히 건너뛰고 나머지는 저장한다.
}

@Example(id: example-member-constraints, language: sql, expected: expected/sql-create-table-constraints.txt) {
새 표 team 과 member 를 만들고, 정상 행과 제약에 걸리는 행을 넣어 본다. INSERT OR IGNORE 는 제약 위반 행을 오류 대신 건너뛰므로, 조회 결과로 어떤 행이 살아남았는지 확인할 수 있다.

```sql
PRAGMA foreign_keys = ON;
CREATE TABLE team (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);
CREATE TABLE member (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age >= 0),
  team_id INTEGER REFERENCES team(id)
);
INSERT INTO team VALUES (1, '종이'), (2, '나무');
INSERT INTO member VALUES (1, '정바람', 32, 1);
INSERT INTO member VALUES (2, '한별빛', 27, 2);
INSERT OR IGNORE INTO member VALUES (2, '중복아이디', 20, 1);
INSERT OR IGNORE INTO member VALUES (3, '어린회원', -1, 1);
INSERT OR IGNORE INTO member VALUES (4, '유령팀', 40, 99);
SELECT id, name, age, team_id FROM member ORDER BY id;
```
}

@Blank(id: blank-tag-table, language: sql) {
태그 표 tag 를 만드는 문장이다. 점수 범위를 검사하는 제약 키워드와, 기존 category 표를 가리키는 외래 키가 참조할 표 이름을 채워 넣어 보자.

```sql
CREATE TABLE tag (
  id INTEGER PRIMARY KEY,
  label TEXT NOT NULL UNIQUE,
  score INTEGER NOT NULL ___1___ (score BETWEEN 0 AND 100),
  category_id INTEGER REFERENCES ___2___(id)
);
INSERT INTO tag VALUES (1, '굿노트', 95, 1);
SELECT id, label, score FROM tag ORDER BY id;
```

@Answer(slot: 1) {
`CHECK`
}

@Answer(slot: 2) {
`category`
}
}

@Task(id: task-delivery-table, language: sql, starter: starters/sql-create-table-constraints.sql, tests: tests/sql-create-table-constraints.sql, solution: solutions/sql-create-table-constraints.sql) {
배송 정보를 담을 새 표 delivery 를 직접 만든다. 열 구성은 id INTEGER PRIMARY KEY, city TEXT NOT NULL, fee INTEGER NOT NULL 이고, fee 가 0 미만이면 거부되도록 CHECK 제약을 붙인다.
그다음 아래 다섯 행을 순서대로 INSERT OR IGNORE 로 넣는다. (1, '서울', 3000), (2, '부산', 2500), (1, '중복', 1000), (3, '제주', -500), (3, '제주', 4900).
제약이 올바르면 중복 아이디와 음수 요금 행은 거부되고 세 행만 남는다. 마지막에 SELECT id, city, fee FROM delivery ORDER BY id; 로 결과를 조회한다.

@Hint {
CHECK 제약은 열 정의 뒤에 CHECK (조건) 형태로 붙인다. 예를 들어 CHECK (fee >= 0) 처럼 쓴다.
}

@Hint {
id 가 1 로 중복된 행과 fee 가 -500 인 행은 각각 PRIMARY KEY 와 CHECK 제약에 걸려 저장되지 않아야 한다.
}

@Hint {
마지막 조회에서 ORDER BY id 를 빠뜨리면 행 순서가 달라져 채점에 실패한다.
}
}

@Quiz(id: quiz-unique-reject, answer: statement-rejected) {
@Question {
UNIQUE 제약이 걸린 name 열에 이미 저장된 값과 똑같은 값을 넣는 INSERT 를 실행하면 어떻게 될까?
}

@Choice(id: statement-rejected) {
INSERT 문이 오류와 함께 거부되고, 표에는 아무 변화도 없다.
}

@Choice(id: overwrite-old-row) {
같은 값을 가진 기존 행이 새 값으로 덮어써진다.
}

@Choice(id: row-added-anyway) {
제약을 무시하고 새 행이 추가되어 같은 값을 가진 두 행이 공존한다.
}

@Choice(id: null-stored) {
충돌을 피하려고 값 대신 NULL 이 저장된다.
}

@Explanation {
PRIMARY KEY 와 UNIQUE 위반은 기본적으로 오류와 함께 거부되며 표는 그대로 유지된다. INSERT OR IGNORE 를 쓰면 오류 대신 위반된 행만 조용히 건너뛴다는 점이 예제에서 확인된 동작이다.
}
}

@Reflection(id: reflection-constraints) {
@Prompt(id: compare-constraints) {
NOT NULL, UNIQUE, CHECK 는 각각 어떤 종류의 잘못된 데이터를 막을까? 서로 겹치는 부분이 있는지도 이야기해 보자.
}

@Prompt(id: missing-foreign-key) {
product.category_id 처럼 다른 표를 가리키는 열에 FOREIGN KEY 가 선언되어 있지 않다면, 시간이 지나면서 어떤 데이터가 어떻게 어긋날 수 있을까?
}

@Prompt(id: ignore-vs-error) {
INSERT OR IGNORE 는 제약 위반 행을 조용히 건너뛴다. 위반을 오류로 그대로 드러내는 쪽이 더 나은 상황은 언제일까?
}
}
