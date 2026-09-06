@Concept(id: concept) {
지금까지는 행 단위로 데이터를 조회했다. 이번 레슨에서는 관점을 바꿔, 여러 행을 하나의 값으로 요약하는 집계 함수를 배운다.

COUNT 는 행의 개수를 센다. COUNT(*) 는 NULL 을 포함해 표의 모든 행을 세고, COUNT(열이름) 는 그 열의 값 중 NULL 이 아닌 것만 센다. 앞에서 본 customer 표에는 city 가 비어 있는 행이 둘 있으므로, COUNT(*) 는 6 을 반환하지만 COUNT(city) 는 4 를 반환한다. 이 차이를 읽어 내는 것이 집계의 첫걸음이다.

SUM 과 AVG 는 수치 열에 쓴다. SUM 은 값을 모두 더하고, AVG 는 평균을 낸다. 둘 다 NULL 은 계산에서 제외한다. AVG 는 나눗셈 결과이므로 정수 데이터를 넣어도 실수가 나올 수 있다는 점에 유의하라.

MIN 과 MAX 는 열에서 가장 작은 값과 큰 값을 찾는다. 숫자뿐 아니라 TEXT 도 비교할 수 있어서, 'YYYY-MM-DD' 형식의 날짜 열에 쓰면 가장 이른 날짜와 가장 늦은 날짜를 알 수 있다.

이 함수들은 FROM 절로 가져온 행 전체를 대상으로 한 번 계산되므로, 결과는 보통 행이 하나다. 그래서 집계 결과에는 ORDER BY 가 필요 없다. 한 가지 주의할 점은 이 팩의 주문 표 이름이 order 라는 것. order 는 SQL 예약어이므로 FROM "order" 처럼 반드시 큰따옴표로 감싸야 한다.
}

@Example(id: example, language: sql, expected: expected/sql-aggregate-functions.txt) {
다섯 개의 집계 함수를 작은 데이터로 한 번에 확인해 본다. VALUES 절로 네 개의 숫자를 담은 임시 표를 만들고, 그 위에서 COUNT, SUM, AVG, MIN, MAX 를 동시에 계산한다. COUNT(*) 는 행 개수인 4, SUM 은 4+9+2+9 = 24, AVG 는 24 를 4 로 나눈 6.0, MIN 은 2, MAX 는 9 다. 결과는 행이 하나뿐이므로 ORDER BY 가 필요 없다는 것도 눈여겨보라.

```sql
WITH nums(n) AS (VALUES (4), (9), (2), (9))
SELECT COUNT(*) AS n_rows,
       SUM(n) AS total,
       AVG(n) AS mean,
       MIN(n) AS lo,
       MAX(n) AS hi
FROM nums;
```
}

@Blank(id: blank, language: sql) {
이제 product 표를 직접 요약해 본다. category_id 가 NULL 인 제품이 하나 있으므로 COUNT(*) 와 COUNT(category_id) 의 값이 달라진다. 빈칸을 채워 전체 제품 수, 카테고리가 정해진 제품 수, 재고 합계, 최고가와 최저가를 한 행으로 조회하라. 결과는 한 행이므로 ORDER BY 는 필요 없다.

```sql
SELECT COUNT(*) AS n_all,
       ___1___ AS n_categorized,
       SUM(stock) AS total_stock,
       ___2___(price) AS max_price,
       MIN(price) ___3___ min_price
FROM product;
```

@Answer(slot: 1) {
`COUNT(category_id)`
}

@Answer(slot: 2) {
`MAX`
}

@Answer(slot: 3) {
`AS`
}
}

@Task(id: task, language: sql, starter: starters/sql-aggregate-functions.sql, tests: tests/sql-aggregate-functions.sql, solution: solutions/sql-aggregate-functions.sql) {
product 표 전체를 요약하는 질의를 완성하라. 결과는 행이 하나여야 하고, 열은 순서대로 다음 다섯 개여야 한다:

product_count — 제품의 총 개수 (COUNT(*) 사용)
total_stock — 재고 수량의 합계 (stock 열)
avg_price — 가격의 평균 (price 열)
min_price — 가격의 최솟값
max_price — 가격의 최댓값

starter 는 제품 개수만 구하고 있다. 나머지 네 개의 요약 값을 같은 SELECT 문에 추가하라. 이미 있는 product_count 와 열 이름·순서는 그대로 유지해야 한다.

@Hint {
결과는 행이 하나다. 다섯 개의 집계 함수를 SELECT 절에 나열하면 된다.
}

@Hint {
열 이름과 순서가 채점 기준과 정확히 같아야 한다.
}

@Hint {
product 표에는 카테고리가 정해지지 않은 제품이 있지만, 이 과제에서는 행 전체를 대상으로 집계한다.
}
}

@Quiz(id: quiz, answer: b) {
@Question {
customer 표에는 city 값이 비어 있는(NULL) 행이 둘 있다. COUNT(*) 와 COUNT(city) 를 실행하면 각각 어떤 결과가 나오는가?
}

@Choice(id: a) {
둘 다 NULL 을 세므로 항상 같은 값을 반환한다
}

@Choice(id: b) {
COUNT(*) 는 NULL 을 포함해 모든 행을 세고, COUNT(city) 는 city 가 NULL 이 아닌 행만 센다
}

@Choice(id: c) {
둘 다 NULL 을 제외하므로 COUNT(*) 도 city 가 비어 있는 행을 세지 않는다
}

@Choice(id: d) {
COUNT(city) 는 같은 도시 이름을 하나로만 세고, COUNT(*) 는 중복을 그대로 센다
}

@Explanation {
COUNT(*) 는 행 전체를 세고, COUNT(열) 는 그 열에 값이 있는 행, 즉 NULL 이 아닌 행만 센다. city 가 비어 있는 행이 둘이므로 COUNT(*) 는 6, COUNT(city) 는 4 가 나온다. 중복을 하나로 세는 것은 COUNT(DISTINCT 열) 의 기능이다.
}
}

@Reflection(id: reflection) {
@Prompt(id: prompt1) {
이 레슨에서 배운 다섯 개의 집계 함수 중, 당신이 만들려는 서비스의 대시보드에 가장 먼저 보여 주고 싶은 것은 무엇이고 그 이유는 무엇인가? 어떤 표의 어떤 열에 쓰일지도 함께 적어 보라.
}

@Prompt(id: prompt2) {
AVG(price) 의 결과가 소수로 나왔을 때, 이 값을 그대로 보여 줄 것인지 아니면 정수로 반올림해서 보여 줄 것인지 상황을 나누어 판단해 보라.
}
}
