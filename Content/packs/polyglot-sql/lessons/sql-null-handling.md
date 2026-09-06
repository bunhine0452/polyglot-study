@Concept(id: null-basics) {
NULL 은 '값이 아직 없음' 을 나타내는 특별한 표식이고, 0 이나 빈 문자열과는 전혀 다르다. NULL 이 들어 있는 열과 = 이나 <> 로 비교하면 결과가 참도 거짓도 아닌 UNKNOWN 이 되기 때문에, WHERE city = NULL 처럼 쓰면 아무 행도 걸리지 않는다. 값이 없는 행은 IS NULL 로, 값이 있는 행은 IS NOT NULL 로만 정확히 골라낼 수 있다. 한편 COUNT(city) 같은 집계는 NULL 을 건너뛰므로 COUNT(*) 와 개수가 달라지고, COALESCE(city, '미지정') 처럼 쓰면 NULL 자리를 지정한 기본값으로 바꿔 출력할 수 있다.
}

@Example(id: count-skips-null, language: sql, expected: expected/sql-null-handling.txt) {
COUNT(*) 는 NULL 을 포함해 행 전체를 세지만, COUNT(city) 는 city 에 값이 실제로 들어 있는 행만 센다. 두 수의 차이가 곧 city 가 NULL 인 행의 개수다. 이 쿼리를 실행해 차이를 눈으로 확인해 보자.

```sql
SELECT COUNT(*) AS n_rows,
       COUNT(city) AS n_with_city,
       COUNT(*) - COUNT(city) AS n_null_city
FROM customer;
```
}

@Blank(id: is-null-coalesce-blank, language: sql) {
도시 정보가 없는 고객만 골라내고, 그 자리에 기본 문구를 붙여 출력하는 쿼리다. 빈칸을 채워 완성하라.

```sql
SELECT name,
       ___1___(city, '도시 미등록') AS city_label
FROM customer
WHERE city ___2___
ORDER BY id;
```

@Answer(slot: 1) {
`COALESCE`
}

@Answer(slot: 2) {
`IS NULL`
}
}

@Task(id: find-customers-without-orders, language: sql, starter: starters/sql-null-handling.sql, tests: tests/sql-null-handling.sql, solution: solutions/sql-null-handling.sql) {
주문 기록이 하나도 없는 고객을 찾아라. customer 를 기준으로 "order" 를 LEFT JOIN 한 뒤, 주문 쪽 열이 NULL 이 된 행만 IS NULL 로 골라내는 방식으로 작성하라. 출력 열은 name 하나여야 하고, 이름 오름차순으로 정렬한다.

@Hint {
주문이 없는 고객은 LEFT JOIN 결과에서 order 쪽 열이 모두 NULL 로 채워진다.
}

@Hint {
NULL 인지 검사할 때는 = 이 아니라 IS NULL 을 써야 조건이 참이 된다.
}

@Hint {
o.id 는 주문 표의 기본키라 NULL 이 저장될 일이 없다. 그래서 이 열을 '주문이 존재하는가' 의 판별 기준으로 쓸 수 있다.
}
}

@Quiz(id: null-not-equal-quiz, answer: unknown-comparison) {
@Question {
customer 표에서 SELECT COUNT(*) FROM customer WHERE city <> '부산' 을 실행한다. city 가 NULL 인 고객은 이 결과에 포함되는가?
}

@Choice(id: unknown-comparison) {
포함되지 않는다. NULL 과의 <> 비교는 참도 거짓도 아닌 UNKNOWN 이 되어 WHERE 조건을 통과하지 못한다.
}

@Choice(id: auto-different) {
포함된다. <> 는 '같지 않음' 을 뜻하므로 값이 없는 행도 자동으로 다른 값으로 취급된다.
}

@Choice(id: null-only-remain) {
NULL 인 행만 포함된다. <> 연산이 값을 가진 행을 먼저 걸러내기 때문에 결과에 NULL 행만 남는다.
}

@Explanation {
NULL 과 어떤 값의 = , <> 비교 결과는 참도 거짓도 아닌 UNKNOWN 이고, WHERE 는 조건이 참인 행만 통과시킨다. 그래서 NULL 행은 <> 비교에서도 빠진다. NULL 행을 다루려면 IS NULL 이나 IS NOT NULL 을 써야 한다.
}
}

@Reflection(id: null-reflection) {
@Prompt(id: count-star-vs-column) {
COUNT(*) 와 COUNT(열) 의 결과가 달라지는 상황을 하나 상상하고, 어떤 질문에는 어느 쪽을 써야 하는지 이유와 함께 적어보자.
}

@Prompt(id: store-default-vs-coalesce) {
값이 없을 때 미리 0 이나 '없음' 을 저장해 두는 것과, NULL 로 두고 조회할 때 COALESCE 로 바꿔 보여주는 것 중 어느 쪽이 나을까? 각 방식의 장단점을 비교해 보자.
}

@Prompt(id: explain-unknown) {
= NULL 이 아무 행도 걸지 않는 이유를, 비전공자 친구에게 설명하듯 일상 언어로 적어보자.
}
}
