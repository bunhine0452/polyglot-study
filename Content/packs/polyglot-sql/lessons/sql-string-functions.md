@Concept(id: string-functions-concept) {
저장된 텍스트가 지저분해도 조회할 때 다듬을 수 있다. **UPPER** 와 **LOWER** 는 각각 모든 글자를 대문자·소문자로 바꿔 대소문자가 섞인 이름·도시를 한 기준으로 통일해 준다. **LENGTH** 는 문자열의 글자 수를, **SUBSTR**(문자열, 시작, 개수)은 원하는 구간을 잘라내며, 시작 위치는 1부터 센다. **REPLACE**(문자열, 찾을 것, 바꿀 것)는 특정 부분을 다른 텍스트로 치환한다. 마지막으로 **||** 연산자는 여러 문자열을 이어 붙이는데, 피연산자 중 하나라도 NULL 이면 결과 전체가 NULL 이 된다는 점을 기억하라.
}

@Example(id: string-functions-example, language: sql, expected: expected/sql-string-functions.txt) {
샘플 두 행을 직접 만들어 다섯 가지 문자열 기능을 한 번에 확인한다. 각 열이 어떻게 변했는지 출력과 비교해 보라.

```sql
WITH demo(name, city, joined_on) AS (
  VALUES ('kim minjun', 'SEOUL', '2023-03-14'),
         ('Park Jisung', 'Busan', '2022-11-02')
)
SELECT
  UPPER(name) AS up_name,
  name || ' / ' || LOWER(city) AS name_city,
  SUBSTR(joined_on, 1, 7) AS joined_ym,
  LENGTH(name) AS name_len,
  REPLACE(joined_on, '-', '.') AS joined_dot
FROM demo
ORDER BY up_name;
```
}

@Blank(id: blank-string-functions, language: sql) {
고객 이름을 대문자로 통일하고, 가입일에서 연도 네 글자만 잘라내며, 이름과 도시를 슬래시로 이어 붙여 한 열로 출력하는 쿼리다. 빈칸을 채워 완성하라.

```sql
SELECT UPPER(name) AS name_up,
       SUBSTR(joined_on, 1, ___1___) AS joined_year,
       name || ___2___ || city AS name_city
FROM customer
ORDER BY name_up;
```

@Answer(slot: 1) {
`4`
}

@Answer(slot: 2) {
`' / '`
}
}

@Task(id: task-customer-string-report, language: sql, starter: starters/sql-string-functions.sql, tests: tests/sql-string-functions.sql, solution: solutions/sql-string-functions.sql) {
customer 표의 모든 고객에 대해 네 열을 출력하라. id 는 그대로, name_up 은 이름을 대문자로 바꾼 것, joined_ym 은 joined_on 의 앞 일곱 글자(YYYY-MM), city_label 은 도시를 소문자로 바꾼 것인데 도시가 NULL 인 고객은 문자열 '미지정' 이 나오게 하라. id 오름차순으로 정렬한다.

@Hint {
문자열 시작 위치는 0 이 아니라 1부터 센다.
}

@Hint {
LOWER 함수에 NULL 을 넘기면 NULL 이 돌아온다 — NULL 을 다루는 레슨의 COALESCE 로 기본값을 씌워라.
}

@Hint {
COALESCE(LOWER(city), '미지정') 처럼 문자열 함수를 겹쳐 쓸 수 있다.
}
}

@Quiz(id: quiz-concat-null, answer: concat-null-result) {
@Question {
city 가 NULL 인 고객에 대해 name || ' (' || city || ')' 을 계산하면 어떻게 되는가?
}

@Choice(id: concat-null-ignored) {
|| 는 NULL 을 빈 문자열처럼 무시해서 이름과 괄호만 남는다.
}

@Choice(id: concat-null-result) {
피연산자 하나가 NULL 이므로 전체 결과가 NULL 이 된다.
}

@Choice(id: concat-null-error) {
NULL 은 문자열이 아니라서 쿼리가 오류로 중단된다.
}

@Explanation {
SQLite 의 || 연산자에서 피연산자 하나라도 NULL 이면 결과는 NULL 이다. 빈 문자열로 취급되지 않으므로, NULL 가능한 열을 붙일 때는 COALESCE 로 먼저 기본값을 정해 주는 것이 안전하다.
}
}

@Reflection(id: reflection-string-functions) {
@Prompt(id: why-normalize-case) {
같은 도시가 'Seoul' 과 'SEOUL' 로 섞여 저장돼 있을 때, 출력 단계에서 UPPER 로 통일하는 것과 데이터 자체를 고치는 것은 어떤 차이가 있을까?
}

@Prompt(id: substr-indexing) {
SUBSTR 의 시작 위치가 1부터라는 점은 0부터 세는 프로그래밍 언어와 다르다. 'YYYY-MM-DD' 에서 연도와 월을 각각 잘라내려면 시작 위치와 개수를 어떻게 정해야 할까?
}

@Prompt(id: concat-with-null) {
이름과 도시를 || 로 붙일 때 NULL 도시가 끼면 결과 전체가 사라진다. 학습자가 의도한 문장을 온전히 얻으려면 쿼리를 어떻게 바꿔야 할까?
}
}
