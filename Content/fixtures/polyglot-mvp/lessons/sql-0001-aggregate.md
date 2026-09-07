@Concept(id: aggregate-basics) {
집계 함수는 여러 행을 하나의 값으로 접는다. `COUNT` `SUM` `AVG` `MIN` `MAX` 다섯 개면
실무 질의의 대부분을 덮는다.

`GROUP BY` 가 없으면 테이블 전체가 하나의 그룹이 되어 **한 행**이 나온다. `GROUP BY` 를
붙이면 그룹마다 한 행이 나오고, `SELECT` 목록에는 그룹 키이거나 집계 함수인 것만 올 수 있다.

이 레슨의 샘플 데이터는 `assets/shop-seed.sql` 이 만든 `product` 테이블이다.
}

@Example(id: aggregate-run, language: sql, expected: expected/sql-0001-aggregate-run.txt) {
카테고리별 상품 수와 평균 가격을 구한다.

```sql
SELECT category, COUNT(*) AS n, AVG(price) AS avg_price
FROM product
GROUP BY category
ORDER BY category;
```
}

@Blank(id: aggregate-blank, language: sql) {
전체 재고 금액(가격 × 수량의 합)을 구하려 한다. 두 칸을 채워라.

```sql
SELECT ___1___(price * quantity) AS stock_value
FROM ___2___;
```

@Answer(slot: 1) {
`SUM`
}

@Answer(slot: 2) {
`product`
}
}

@Task(id: top-category, language: sql, starter: starters/sql-0001-top-products.sql, tests: tests/sql-0001-top-products.sql, solution: solutions/sql-0001-top-products.sql) {
카테고리별 최고가 상품의 이름과 가격을 카테고리 오름차순으로 뽑는 질의를 작성해라.

열 이름은 `category`, `name`, `price` 여야 한다.

@Hint {
그룹당 최고가를 구하는 것과 그 행의 다른 열을 함께 가져오는 것은 다른 문제다.
서브쿼리나 윈도 함수 중 하나가 필요하다.
}
}

@Quiz(id: aggregate-quiz, answer: skips-null) {
@Question {
`COUNT(column)` 과 `COUNT(*)` 의 차이는 무엇인가?
}

@Choice(id: skips-null) {
`COUNT(column)` 은 그 열이 NULL 인 행을 세지 않는다.
}

@Choice(id: identical) {
둘은 완전히 같고 표기만 다르다.
}

@Choice(id: distinct) {
`COUNT(column)` 은 중복을 제거하고 센다.
}

@Explanation {
집계 함수는 NULL 을 건너뛴다. `COUNT(*)` 는 열을 보지 않고 행을 세므로 NULL 과 무관하다.
중복 제거는 `COUNT(DISTINCT column)` 이라고 명시해야 한다.
}
}

@Reflection(id: aggregate-reflect) {
@Prompt(id: having) {
`WHERE` 와 `HAVING` 이 걸러내는 대상이 어떻게 다른지, 실행 순서를 기준으로 설명해라.
}

@Prompt(id: avg-null) {
`AVG(price)` 가 NULL 을 건너뛴다는 사실이 평균값을 어떻게 바꾸는가? NULL 을 0 으로
취급하고 싶다면 무엇을 써야 하는가?
}
}
