@Concept(id: sql-02-concept) {
조회한 결과는 데이터베이스가 저장하고 있는 순서를 따르지 않는다. 특별한 지시가 없으면 어떤 행이 먼저 나올지 보장할 수 없으므로, 결과에 의미 있는 순서를 부여하려면 ORDER BY 를 명시해야 한다. ORDER BY 뒤에 기준이 될 열을 적고 ASC(오름차순) 또는 DESC(내림차순)를 붙인다. 아무것도 붙이지 않으면 ASC 가 기본값이다.

정렬 기준은 여러 개 둘 수 있다. ORDER BY price DESC, name ASC 처럼 쉼표로 나열하면 앞의 열 값이 같은 행들끼리 모여 두 번째 열 기준으로 다시 정렬된다. 가격이 같은 상품을 이름순으로 보여 주는 식이다. 동률인 행에 보조 기준을 두면 순서가 실행할 때마다 흔들리는 일이 없어져, 같은 질의가 언제나 같은 결과를 돌려준다.

LIMIT 은 정렬된 결과 중 앞에서부터 정해진 개수의 행만 반환한다. '판매량 상위 3개'처럼 순위를 매겨 잘라 내는 질의에서 ORDER BY 와 LIMIT 은 항상 짝을 이룬다. ORDER BY 없이 LIMIT 만 쓰면 어떤 행이 잘리는지 예측할 수 없으므로, 반드시 정렬을 먼저 하고 개수를 제한해야 한다.

DISTINCT 는 결과에서 중복된 행을 걷어낸다. SELECT DISTINCT city FROM customer 처럼 쓰면 같은 도시가 여러 번 나와도 한 번만 돌려준다. 주의할 점은 SELECT 뒤에 여러 열을 쓰면 그 열 조합 전체가 같을 때만 중복으로 본다는 것이다. city 가 같아도 district 가 다르면 SELECT DISTINCT city, district 의 결과에서는 별개의 행으로 남는다.

세 키워드는 하나의 질의에서 함께 쓸 수 있다. DISTINCT 로 중복을 걷어내고, ORDER BY 로 순서를 정하고, LIMIT 으로 상위 몇 개만 잘라 내는 흐름은 실무에서 가장 흔한 조회 패턴 중 하나다.
}

@Example(id: sql-02-example, language: sql, expected: expected/sql-order-by-limit-distinct.txt) {
order_item 데이터에는 같은 상품을 같은 수량으로 담은 주문이 여러 개 섞여 있다. DISTINCT 로 상품·수량 조합을 고유하게 만들고, 수량이 많은 순서로 정렬한 뒤 상위 4개만 꺼낸다. 수량이 같은 행은 product_id 를 보조 기준으로 삼아 순서를 완전히 고정했다. 103번과 104번 주문이 모두 (5, 4) 조합을 담고 있으므로 DISTINCT 가 이 둘을 하나로 합치는지도 출력에서 확인해 보라.

```sql
WITH order_item (order_id, product_id, quantity) AS (
  VALUES
    (101, 3, 2),
    (101, 5, 1),
    (102, 3, 2),
    (102, 7, 1),
    (103, 3, 1),
    (103, 5, 4),
    (104, 5, 4)
)
SELECT DISTINCT product_id, quantity
FROM order_item
ORDER BY quantity DESC, product_id ASC
LIMIT 4;
```
}

@Blank(id: sql-02-blank-order-by-limit, language: sql) {
재고가 남아 있는 상품만 대상으로, 비싼 상품부터 두 개만 꺼내려 한다. 빈칸을 채워 질의를 완성하고 실행 전에 어떤 두 상품이 나올지 예상해 본 뒤 결과와 비교해 보라.

```sql
WITH product (id, name, price, stock) AS (
  VALUES
    (1, '볼펜', 1200, 100),
    (2, '노트', 5000, 20),
    (3, '파일', 9000, 15),
    (4, '샤프', 3500, 45),
    (5, '클립', 700, 0)
)
SELECT name, price
FROM product
WHERE stock > 0
ORDER BY ___1___ DESC
___2___ 2;
```

@Answer(slot: 1) {
`price`
}

@Answer(slot: 2) {
`LIMIT`
}
}

@Task(id: sql-02-task, language: sql, starter: starters/sql-order-by-limit-distinct.sql, tests: tests/sql-order-by-limit-distinct.sql, solution: solutions/sql-order-by-limit-distinct.sql) {
고객 데이터에서 고객들이 실제로 살고 있는 도시의 고유한 목록이 필요하다. NULL 인 도시는 제외하고, 도시 이름을 오름차순으로 정렬한 뒤 앞에서 세 개만 반환하는 질의를 완성하라. 결과 열의 이름은 city 이어야 한다.

@Hint {
WHERE city IS NOT NULL 로 도시가 없는 고객을 먼저 걷어낸다.
}

@Hint {
SELECT 뒤에 DISTINCT 를 붙이면 같은 도시가 한 번만 남는다.
}

@Hint {
ORDER BY city 뒤에 LIMIT 3 을 붙여 상위 세 개만 자른다.
}
}

@Quiz(id: sql-02-quiz, answer: quiz-sql-02-b) {
@Question {
SELECT DISTINCT category_id, price FROM product 을 실행할 때 중복을 판정하는 기준은 무엇인가?
}

@Choice(id: quiz-sql-02-a) {
category_id 값이 같은 행은 모두 하나로 합쳐진다
}

@Choice(id: quiz-sql-02-b) {
category_id 와 price 의 값이 모두 같은 행만 하나로 합쳐진다
}

@Choice(id: quiz-sql-02-c) {
price 값이 같은 행은 모두 하나로 합쳐진다
}

@Choice(id: quiz-sql-02-d) {
가장 먼저 조회된 행 하나만 남고 나머지 행은 모두 제거된다
}

@Explanation {
DISTINCT 는 SELECT 절에 나열된 모든 열의 조합을 기준으로 중복을 판정한다. category_id 와 price 를 함께 SELECT 했다면 두 값이 모두 같은 행만 하나로 합쳐지고, 한 열만 같은 행은 서로 다른 행으로 남는다.
}
}

@Reflection(id: sql-02-reflection) {
@Prompt(id: sql-02-reflection-1) {
가격이나 날짜처럼 같은 값을 가진 행이 여러 개일 때, ORDER BY 만으로는 그 행들 사이의 순서가 실행마다 달라질 수 있다. 이런 동률 상황에서 결과 순서를 완전히 고정하려면 어떤 열을 어떻게 활용할 수 있을까? 또, ORDER BY 없이 LIMIT 으로 상위 N 개를 자르면 어떤 문제가 생길지, 실제 서비스에서 사용자에게 보여 주는 목록이라는 관점에서 생각해 보고 정리해 보라.
}

@Prompt(id: sql-02-task) {
고객 데이터에서 고객들이 실제로 살고 있는 도시의 고유한 목록이 필요하다. NULL 인 도시는 제외하고, 도시 이름을 오름차순으로 정렬한 뒤 앞에서 세 개만 반환하는 질의를 작성하라. 결과 열의 이름은 city 이어야 한다. starter 질의는 중복된 도시도 그대로 돌려주므로, DISTINCT 와 ORDER BY 와 LIMIT 을 직접 붙여 완성해야 한다.
}

@Prompt(id: sql-02-example-header) {
지금까지 배운 세 키워드를 하나의 질의에 조합하면 다음과 같은 조회가 가능하다.
}
}
