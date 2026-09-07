@Concept(id: concept-1) {
데이터베이스에는 데이터가 표(테이블) 형태로 저장된다. 가로줄은 행(레코드), 세로줄은 열(컬럼)이며, 각 열에는 이름이 붙어 있다. 이 레슨에서 사용하는 product 테이블은 상품 한 건이 한 행에 담기고, id, name, category_id, price, stock 다섯 개의 열을 가진다.

테이블에서 데이터를 꺼내는 질의는 SELECT 로 시작한다. SELECT 뒤에는 결과에 담을 열 이름을 쉼표로 나열하고, FROM 뒤에는 데이터를 꺼낼 테이블 이름을 쓴다. 예를 들어 SELECT name, price FROM product 는 상품의 이름과 가격만 골라 보여 준다. 모든 열을 다 보고 싶을 때는 열 이름 대신 별표(*)를 쓰면 된다. 질의 끝에는 세미콜론을 붙이고, SELECT 나 FROM 같은 키워드는 대문자와 소문자를 구분하지 않지만 읽기 쉽도록 대문자로 쓰는 것이 관례다.

전체 행이 아니라 조건에 맞는 행만 골라 내고 싶을 때는 WHERE 절을 붙인다. WHERE 뒤에는 행마다 참인지 거짓인지 판단되는 조건식을 쓰고, 참이 된 행만 결과에 남는다. 비교 연산자로는 같음을 뜻하는 =, 같지 않음을 뜻하는 <>, 작다를 뜻하는 <, 크거나 같다를 뜻하는 >= 등을 쓴다. 예를 들어 WHERE price >= 10000 는 가격이 10000원 이상인 행만 골라 낸다. 등호가 프로그래밍 언어와 달리 = 하나라는 점, 같지 않음이 <> 라는 점에 주목하라.

조건을 두 개 이상 조합할 때는 AND 와 OR 을 쓴다. AND 는 양쪽 조건을 모두 만족하는 행만 남기고, OR 은 둘 중 하나라도 만족하는 행을 남긴다. SQL 은 AND 를 OR 보다 먼저 계산하므로, '이 조건 또는 저 조건을 만족하면서' 같은 복잡한 의미를 만들 때는 괄호로 묶어 순서를 명확히 하는 습관을 들이는 것이 좋다.

이 팩에서 다루는 표는 category, customer, product, "order", order_item 다섯 개다. 이 중 "order" 는 SQL 의 예약어와 이름이 같아서 질의에 쓸 때 반드시 큰따옴표로 감싸야 한다는 점만 기억해 두자. 자세한 사용은 이후 레슨에서 다룬다.
}

@Example(id: example-1, language: sql, expected: expected/sql-select-from-where.txt) {
예제를 실행하며 WHERE 절이 행을 골라 내는 방식을 확인해 보자. 맨 앞의 WITH 절은 연습용 데이터를 임시로 만드는 장치일 뿐이니 지금은 결과에 집중하자. SELECT name, price, stock 은 세 열만 결과에 담으라는 뜻이고, WHERE 절은 가격이 1000원 이상이라는 조건과 '종류가 paper 이거나 재고가 0개'라는 조건을 AND 로 묶은 것이다. 볼펜은 가격 조건에 걸리고, 책상과 마우스는 괄호 안의 조건에 걸려서 빠진다. 마지막 ORDER BY id 는 결과 행의 순서를 고정하기 위한 것이다.

```sql
WITH demo_product (id, name, category, price, stock) AS (
    VALUES (1, '노트', 'paper', 1200, 50),
           (2, '볼펜', 'paper', 800, 120),
           (3, '책상', 'furniture', 45000, 8),
           (4, '의자', 'furniture', 30000, 0),
           (5, '마우스', 'device', 15000, 25)
)
SELECT name, price, stock
FROM demo_product
WHERE price >= 1000 AND (category = 'paper' OR stock = 0)
ORDER BY id;
```
}

@Blank(id: blank-1, language: sql) {
아래 질의는 product 테이블에서 가격이 10000원 이상이고 재고가 5개 이하인 상품의 이름, 가격, 재고를 조회한다. 빈칸에 들어갈 절과 연산자를 채워라.

```sql
SELECT name, price, stock
___1___ product
___2___ price >= 10000 ___3___ stock <= 5
ORDER BY id;
```

@Answer(slot: 1) {
`FROM`
}

@Answer(slot: 2) {
`WHERE`
}

@Answer(slot: 3) {
`AND`
}
}

@Task(id: task-1, language: sql, starter: starters/sql-select-from-where.sql, tests: tests/sql-select-from-where.sql, solution: solutions/sql-select-from-where.sql) {
product 테이블에서 가격이 10000원 이상이고, 카테고리가 1번이거나 3번인 상품만 골라 내려 한다. id, name, category_id, price, stock 열을 조회하고, id 오름차순으로 정렬하라. WHERE 절에 AND 와 OR 을 함께 쓰고, OR 쪽 조건을 괄호로 묶어야 한다.

@Hint {
AND 를 OR 보다 먼저 계산하므로, OR 로 묶은 조건이 하나의 덩어리가 되게 괄호로 감싸야 한다.
}

@Hint {
같다는 뜻의 비교 연산자는 = 하나다.
}
}

@Quiz(id: quiz-1, answer: opt-1) {
@Question {
product 테이블에서 '재고가 0개이거나, 가격이 30000원 이상인 상품'을 조회하려 한다. 옳은 WHERE 절은 무엇인가?
}

@Choice(id: opt-0) {
WHERE stock = 0 OR price >= 30000
}

@Choice(id: opt-1) {
WHERE stock = 0 AND price >= 30000
}

@Choice(id: opt-2) {
WHERE stock = 0, price >= 30000
}

@Choice(id: opt-3) {
WHERE stock <> 0 OR price >= 30000
}

@Explanation {
OR 는 두 조건 중 하나라도 만족하는 행을 남긴다. AND 를 쓰면 두 조건을 동시에 만족하는 행만 남아 '또는'이라는 요구사항과 어긋난다. WHERE 절에서 조건을 쉼표로 나열하는 문법은 없고, <> 는 '같지 않다'이므로 재고가 0개가 아닌 행을 고르게 된다.
}
}

@Reflection(id: reflection-1) {
@Prompt(id: prompt-1) {
WHERE 절에서 두 조건을 AND 로 묶을 것인지 OR 로 묶을 것인지 판단하는 기준을, 일상 언어의 '그리고'와 '또는'에 빗대어 자기 말로 정리해 보자. AND 와 OR 을 함께 쓸 때 괄호를 붙이면 의미가 어떻게 달라지는지도 덧붙여라.
}

@Prompt(id: prompt-2) {
SELECT 뒤에 열 이름을 일부만 쓰는 것과 별표(*)를 쓰는 것은 결과의 어떤 면이 달라지는가? 열을 줄여 조회하면 실무에서 어떤 이점이 있을지 생각해 보자.
}
}
