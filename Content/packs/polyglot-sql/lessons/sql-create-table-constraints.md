@Concept(id: concept-create-table-constraints) {
지금까지는 남이 만든 표를 읽기만 했다면, 이제 `CREATE TABLE` 로 표를 직접 만든다. 각 열마다 이름과 타입을 쓰고, 그 뒤에 규칙(제약)을 붙일 수 있다. `id INTEGER PRIMARY KEY` 처럼 표의 한 행을 유일하게 가리킬 기준 열을 정하고, `NOT NULL` 로 비어 있으면 안 되는 열을 지정한다.

제약은 잘못된 데이터가 들어오는 순간 거부하는 문지기다. `UNIQUE` 는 열 전체에서 같은 값이 두 번 나오는 것을 막고, `CHECK (조건)` 은 값이 조건을 만족할 때만 통과시킨다. 두 표를 연결할 때는 `REFERENCES 다른표(열)` 로 외래 키를 선언해서, 존재하지 않는 상대를 가리키는 행을 막을 수 있다(SQLite 에서는 `PRAGMA foreign_keys = ON;` 을 먼저 실행해야 외래 키 검사가 켜진다).

제약을 직접 관찰하는 편한 방법이 `INSERT OR IGNORE` 다. 보통 `INSERT` 는 제약 위반 시 오류를 내고 멈추지만, `INSERT OR IGNORE` 는 `UNIQUE`, `NOT NULL`, `CHECK` 위반 행을 조용히 건너뛴다. 그래서 나쁜 행 여러 개를 몰아 넣고 마지막에 `SELECT` 로 무엇이 살아남았는지 보면, 어떤 제약이 무엇을 막았는지 눈으로 확인할 수 있다. 한 가지 주의할 점: 표 이름으로 `order` 처럼 예약어를 쓰고 싶다면 항상 큰따옴표로 감싸야 한다.
}

@Example(id: example-hall-seat, language: sql, expected: expected/sql-create-table-constraints.txt) {
공연장 좌석 표를 제약과 함께 만들고, 규칙을 어기는 INSERT 를 `INSERT OR IGNORE` 로 시도한 뒤 어떤 행이 살아남는지 확인한다.

```sql
CREATE TABLE hall_seat (
  id INTEGER PRIMARY KEY,
  seat_no TEXT NOT NULL UNIQUE,
  zone TEXT NOT NULL CHECK (zone IN ('A', 'B')),
  price INTEGER NOT NULL CHECK (price > 0)
);
INSERT INTO hall_seat VALUES (1, 'A1', 'A', 50000);
INSERT INTO hall_seat VALUES (2, 'B1', 'B', 40000);
INSERT OR IGNORE INTO hall_seat VALUES (3, 'A1', 'A', 45000);
INSERT OR IGNORE INTO hall_seat VALUES (4, 'A2', 'C', 30000);
INSERT OR IGNORE INTO hall_seat VALUES (5, 'A2', 'A', 0);
INSERT OR IGNORE INTO hall_seat VALUES (6, NULL, 'A', 10000);
SELECT id, seat_no, zone, price FROM hall_seat ORDER BY id;
```
}

@Blank(id: blank-badge-table, language: sql) {
뱃지 표를 만드는 문장에서 제약 키워드가 빠져 있다. 빈칸을 채워 표를 완성하고, 행이 정상적으로 들어가는지 확인해 보자.

```sql
CREATE TABLE badge (
  id INTEGER ___1___,
  code TEXT NOT NULL ___2___,
  tier TEXT NOT NULL CHECK (tier ___3___ ('bronze', 'silver', 'gold')),
  points INTEGER NOT NULL CHECK (___4___ > 0)
);
INSERT INTO badge VALUES (1, 'B001', 'bronze', 100);
SELECT * FROM badge ORDER BY id;
```

@Answer(slot: 1) {
`PRIMARY KEY`
}

@Answer(slot: 2) {
`UNIQUE`
}

@Answer(slot: 3) {
`IN`
}

@Answer(slot: 4) {
`points`
}
}

@Task(id: task-cafe-menu, language: sql, starter: starters/sql-create-table-constraints.sql, tests: tests/sql-create-table-constraints.sql, solution: solutions/sql-create-table-constraints.sql) {
카페 메뉴 표 `cafe_menu` 를 제약과 함께 정의해 보자. `name` 열에는 `NOT NULL` 과 `UNIQUE` 를 붙여 같은 이름의 메뉴가 두 번 등록되지 않게 하고, `kind` 열에는 `CHECK` 로 'coffee', 'tea', 'ade', 'snack' 넷 중 하나만 허용하며, `price` 열에는 `CHECK` 로 0보다 큰 값만 허용하라. `CREATE TABLE` 의 열 정의만 고치고 아래의 `INSERT` 문들은 그대로 둘 것. 규칙을 어기는 행은 `INSERT OR IGNORE` 덕분에 조용히 거부되고, 마지막 `SELECT` 는 통과한 행만 보여 준다.

@Hint {
제약은 열 정의 뒤에 이어 붙인다. 예: price INTEGER NOT NULL CHECK (price > 0)
}

@Hint {
한 열에 여러 제약을 붙일 수 있다: name TEXT NOT NULL UNIQUE
}

@Hint {
나열한 값 중 하나인지 검사할 때는 IN 을 쓴다: CHECK (kind IN ('coffee', 'tea', 'ade', 'snack'))
}
}

@Quiz(id: quiz-on-conflict-fk, answer: foreign-key-violation) {
@Question {
`INSERT OR IGNORE` 는 제약 위반 행을 조용히 건너뛰지만, 어떤 제약 위반에는 이 ON CONFLICT 절이 적용되지 않아 그대로 오류가 난다. 무엇인가?
}

@Choice(id: not-null-violation) {
NOT NULL 위반 — NULL 값은 IGNORE 로도 막을 수 없어서 항상 오류가 난다.
}

@Choice(id: check-violation) {
CHECK 위반 — CHECK 는 표 정의에만 쓸 수 있어서 INSERT 단계에서는 무시된다.
}

@Choice(id: foreign-key-violation) {
FOREIGN KEY 위반 — ON CONFLICT 절은 외래 키 제약에는 적용되지 않는다.
}

@Choice(id: unique-violation) {
UNIQUE 위반 — UNIQUE 는 인덱스가 아니라서 IGNORE 로 건너뛸 수 없다.
}

@Explanation {
SQLite 에서 ON CONFLICT 절(INSERT OR IGNORE 포함)은 UNIQUE, PRIMARY KEY, NOT NULL, CHECK 위반에는 적용되지만 FOREIGN KEY 위반은 대상이 아니다. 그래서 존재하지 않는 부모를 가리키는 행을 INSERT OR IGNORE 로 넣으려고 하면 조용히 건너뛰어지지 않고 문이 실패한다. 외래 키 위반은 PRAGMA foreign_keys = ON 상태에서 별도로 검사된다.
}
}

@Reflection(id: reflection-constraints) {
@Prompt(id: pk-vs-unique) {
PRIMARY KEY 와 UNIQUE 는 모두 중복된 값을 막는다. 두 제약의 공통점과 차이를, 예를 들어 만들어 볼 표 하나를 정해서 자기 말로 정리해 보세요.
}

@Prompt(id: null-vs-missing) {
NOT NULL 을 선언하지 않은 열에는 NULL 이 들어올 수 있습니다. customer.city 처럼 '아직 모르는' 정보와 '실수로 빠진' 정보를 데이터로 어떻게 구분할 수 있을까요?
}

@Prompt(id: db-vs-app-validation) {
CHECK 와 FOREIGN KEY 가 데이터베이스에서 검사해 준다면, 애플리케이션 코드에서의 값 검사는 불필요해질까요? 각 검사가 맡는 시점과 책임을 생각해 보세요.
}
}
