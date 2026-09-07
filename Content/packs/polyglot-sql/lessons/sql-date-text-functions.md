@Concept(id: text-date-functions) {
이 쇼핑몰 데이터베이스에서 날짜는 'YYYY-MM-DD' 형태의 TEXT 로 저장되어 있다. SQLite 는 전용 날짜 타입이 없지만, ISO 8601 형식의 TEXT 는 사전순 비교가 곧 시간순 비교이므로 ordered_at > '2024-03-01' 처럼 문자열 비교만으로 특정 날짜 이후를 걸러낼 수 있다. strftime('%Y', ordered_at) 은 연도, strftime('%m') 은 월 같은 조각을 뽑아내고, date(ordered_at, '+7 days') 는 기준 날짜에서 며칠 뒤의 날짜를 계산한다. julianday(날짜) 는 기원전 4714년 11월 24일부터 흘러간 일수를 실수로 돌려주므로, 두 날짜의 julianday 차이가 곧 일수 차이가 된다.
}

@Example(id: date-functions-demo, language: sql, expected: expected/sql-date-text-functions.txt) {
연습용 날짜 네 줄로 연도와 월 뽑기, 7일 뒤 날짜 계산, 배송 소요일 계산, 예정일보다 늦었는지 비교를 한 번에 확인해 보자.

```sql
WITH sample(id, ordered_at, shipped_at) AS (
  VALUES (1, '2024-03-01', '2024-03-04'),
         (2, '2024-03-15', '2024-03-15'),
         (3, '2024-04-02', '2024-04-10')
)
SELECT id,
       strftime('%Y', ordered_at) AS year,
       strftime('%m', ordered_at) AS month,
       date(ordered_at, '+7 days') AS due,
       CAST(julianday(shipped_at) - julianday(ordered_at) AS INTEGER) AS days,
       shipped_at > date(ordered_at, '+7 days') AS late
FROM sample
ORDER BY id;
```
}

@Blank(id: blank-year-and-avg-days, language: sql) {
실제 주문 데이터에서 연도별 주문 수와 평균 배송 소요일을 구하는 쿼리의 빈칸을 채워 보자. 아직 배송되지 않아 shipped_at 이 NULL 인 주문은 제외한다.

```sql
SELECT strftime('%Y', ordered_at) AS year,
       COUNT(*) AS n,
       CAST(AVG(___1___(shipped_at) - ___2___(ordered_at)) AS INTEGER) AS avg_days
FROM "order"
WHERE shipped_at IS NOT NULL
GROUP BY ___3___
ORDER BY year;
```

@Answer(slot: 1) {
`julianday`
}

@Answer(slot: 2) {
`julianday`
}

@Answer(slot: 3) {
`year`
}
}

@Task(id: task-shipping-days, language: sql, starter: starters/sql-date-text-functions.sql, tests: tests/sql-date-text-functions.sql, solution: solutions/sql-date-text-functions.sql) {
"order" 표에서 배송이 완료된 주문(shipped_at 이 NULL 이 아닌 행)만 대상으로, 각 주문의 id, 배송 소요일, 배송 예정일, 지연 여부를 계산하라. days 는 julianday(shipped_at) 에서 julianday(ordered_at) 를 뺀 값을 CAST 로 정수로 만들고, due_date 는 date(ordered_at, '+7 days') 이다. late 는 shipped_at 이 due_date 보다 늦으면 1, 그렇지 않으면 0 이 되도록 CASE 식으로 만든다. 결과는 id 오름차순으로 정렬한다.

@Hint {
julianday(a) - julianday(b) 의 결과는 3.0 처럼 실수로 나오므로, CAST(... AS INTEGER) 로 감싸야 정수 소요일이 된다.
}

@Hint {
date(ordered_at, '+7 days') 처럼 두 번째 인수에 수정자 문자열을 넣으면 기준 날짜에서 7일 뒤를 얻는다.
}

@Hint {
비교 shipped_at > date(ordered_at, '+7 days') 는 두 값이 모두 'YYYY-MM-DD' TEXT 이므로 그대로 문자열 비교로 해도 올바르게 동작한다.
}
}

@Quiz(id: quiz-text-date-compare, answer: iso-lexicographic) {
@Question {
'YYYY-MM-DD' 형태로 저장된 TEXT 날짜를 ordered_at > '2024-03-01' 처럼 문자열 비교 연산자로 걸러도 결과가 올바른 이유는 무엇일까?
}

@Choice(id: iso-lexicographic) {
ISO 8601 형식은 자릿수가 고정되어 있어 사전순(문자열) 순서와 시간 순서가 일치하기 때문이다.
}

@Choice(id: auto-type-conversion) {
SQLite 가 TEXT 를 비교할 때 날짜 형식을 발견하면 자동으로 날짜 값으로 변환해 비교하기 때문이다.
}

@Choice(id: length-only) {
날짜 문자열은 길이가 항상 10자로 같아서 비교 연산자가 결국 길이만 비교하기 때문이다.
}

@Explanation {
연도-월-일 순으로 큰 단위부터 고정 폭(0 채움)으로 쓰인 형식은 사전순 비교가 곧 시간순 비교가 된다. SQLite 는 TEXT 를 자동으로 날짜로 바꿔 주지 않으므로, 형식이 'YYYY-MM-DD' 로 일관될 때만 이 방법이 안전하다.
}
}

@Reflection(id: reflection-text-dates) {
@Prompt(id: prompt-monthly-report) {
이 쇼핑몰에서 월별 매출 보고서를 만들어 달라는 요청을 받았다면, strftime 과 GROUP BY 를 어떻게 조합하겠는가? 어떤 열을 기준으로 묶고 무엇을 집계하겠는가?
}

@Prompt(id: prompt-format-risk) {
날짜가 '2024-3-5' 처럼 0 을 채우지 않고 저장되어 있다면 TEXT 비교와 julianday 계산에서 무엇이 문제가 될 수 있을까?
}

@Prompt(id: prompt-null-shipping) {
shipped_at 이 NULL 인 주문은 배송 소요일 계산에서 어떻게 처리되는가? 보고서에서 이 주문들을 아예 빼는 것과 '미배송' 으로 표시하는 것 중 어떤 쪽이 더 유용할까?
}
}
