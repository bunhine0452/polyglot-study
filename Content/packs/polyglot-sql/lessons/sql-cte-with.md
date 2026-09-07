@Concept(id: cte-with) {
복잡한 쿼리 안에 서브쿼리가 여러 겹 겹치면 무엇이 무엇을 위한 것인지 알아보기 어렵다. WITH 절은 서브쿼리에 이름을 붙여 쿼리 위쪽에 먼저 선언하는 문법이고, 이렇게 이름 붙은 결과를 공통 테이블 식(CTE, Common Table Expression)이라고 부른다. CTE 는 선언하는 순간부터 그 쿼리 안에서 마치 실제 표처럼 FROM 에 쓸 수 있다.

CTE 의 진짜 힘은 여러 개를 연결할 때 나온다. WITH 안에서 하나의 CTE 를 쉼표로 닫고 다음 이름을 이어 선언하면, 뒤에 오는 CTE 는 앞에서 만든 CTE 를 참조할 수 있다. 이렇게 하면 1단계 고객별 집계, 2단계 평균 계산, 3단계 평균과 비교 같은 절차를 위에서 아래로 읽히는 단계로 쪼갤 수 있다.

같은 결과는 서브쿼리를 중첩해서도 만들 수 있지만, 중첩이 깊어질수록 가장 안쪽 쿼리부터 거꾸로 읽어야 한다. CTE 는 계산 순서대로 위에서 아래로 읽히므로 로직 파악이 쉽고, 같은 중간 결과를 여러 번 참조해야 할 때 이름을 재사용할 수 있다는 점도 편하다.
}

@Example(id: cte-chained-avg, language: sql, expected: expected/sql-cte-with.txt) {
월별 매출 CTE 에서 평균 매출 CTE 를 만들고, 각 월이 평균과 얼마나 차이 나는지 계산하는 쿼리다. 두 개의 CTE 가 쉼표로 연결되어 단계를 이루는 것을 확인하라.

```sql
WITH monthly_sales(month_name, amount) AS (
  SELECT '2024-01', 30000 UNION ALL
  SELECT '2024-02', 42000 UNION ALL
  SELECT '2024-03', 30000
),
avg_overall(avg_amount) AS (
  SELECT AVG(amount) FROM monthly_sales
)
SELECT m.month_name,
       m.amount,
       a.avg_amount,
       m.amount - a.avg_amount AS diff_from_avg
FROM monthly_sales AS m
CROSS JOIN avg_overall AS a
ORDER BY m.month_name;
```
}

@Blank(id: cte-city-count, language: sql) {
고객 표에서 도시별 인원을 세는 CTE 를 선언하고, 그 이름 붙은 결과를 표처럼 조회하는 쿼리다. 빈칸을 채워 완성하라.

```sql
___1___ city_stats AS (
  SELECT city, COUNT(*) AS n
  FROM customer
  GROUP BY city
)
SELECT city, n
FROM ___2___
ORDER BY n DESC, city;
```

@Answer(slot: 1) {
`WITH`
}

@Answer(slot: 2) {
`city_stats`
}
}

@Task(id: cte-customer-items, language: sql, starter: starters/sql-cte-with.sql, tests: tests/sql-cte-with.sql, solution: solutions/sql-cte-with.sql) {
고객별 총 구매 수량을 구하고, 그 평균 이상을 구매한 고객만 출력하라. WITH 절로 CTE 를 둘 이상 만들어 단계를 나눠라. 첫째 열은 name, 둘째 열은 total_items 이어야 하고, total_items 내림차순으로 정렬하되 수량이 같으면 이름 오름차순으로 정렬하라. 주문이 하나도 없는 고객은 결과에서 제외한다.

@Hint {
첫 번째 CTE 에서 고객별 총 수량을 구하려면 customer 표에서 order 표를 거쳐 order_item 표까지 연결한 뒤 quantity 를 합산해야 한다.
}

@Hint {
두 번째 CTE 는 첫 번째 CTE 를 FROM 에 쓰고 AVG 로 평균을 계산하면 된다.
}

@Hint {
최종 SELECT 에서는 두 CTE 를 나란히 FROM 에 놓고, 각 고객의 수량이 평균 이상인 행만 걸러내면 된다.
}
}

@Quiz(id: cte-separator, answer: comma) {
@Question {
하나의 WITH 절 안에서 여러 개의 CTE 를 이어 선언할 때, 앞 CTE 와 다음 CTE 사이에는 무엇을 써야 하는가?
}

@Choice(id: comma) {
쉼표(,)로 앞 CTE 를 닫고 다음 CTE 이름을 이어 선언한다.
}

@Choice(id: semicolon) {
세미콜론(;)으로 앞 CTE 를 끝맺고 새로 WITH 를 다시 쓴다.
}

@Choice(id: union-all) {
UNION ALL 키워드로 앞 CTE 와 다음 CTE 를 연결한다.
}

@Choice(id: as-keyword) {
AS 키워드만 쓰면 이름이 계속 이어지므로 별도 구분자가 필요 없다.
}

@Explanation {
CTE 들은 하나의 WITH 안에서 쉼표로 나열하며, 뒤에 오는 CTE 는 앞에서 만든 CTE 를 참조할 수 있다. 세미콜론은 문장 자체의 끝을 뜻하고, UNION ALL 은 두 결과집합의 행을 합치는 연산이라 CTE 선언과는 무관하다.
}
}

@Reflection(id: cte-reflection) {
@Prompt(id: readability) {
같은 결과를 내는 서브쿼리 버전과 CTE 버전을 나란히 실행해 보았을 때, 어느 쪽이 더 읽기 쉬웠고 그 이유는 무엇이라고 생각하는가?
}

@Prompt(id: step-boundary) {
복잡한 요구사항을 CTE 단계로 쪼갤 때, 어디를 하나의 단계 경계로 삼으면 좋을까? 본인만의 기준을 말해 보라.
}

@Prompt(id: reuse) {
중간 결과를 쿼리 안에서 두 번 이상 참조해야 할 때 CTE 는 어떤 편의를 주는가? 서브쿼리였다면 어떻게 해야 했을지 비교해 보라.
}
}
