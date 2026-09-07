@Concept(id: self-join-basics) {
지금까지는 서로 다른 두 표를 조인했지만, 같은 표를 두 번 조인하는 것도 가능하다. 이것을 **self join** 이라고 한다. SQL 은 표 이름을 두 번 그대로 쓸 수 없으므로, `FROM product AS p1` 처럼 **AS 별칭**을 붙여 두 개의 독립된 복사본처럼 다룬다. 별칭이 다르면 `p1.name` 과 `p2.name` 처럼 같은 열을 구분해서 쓸 수 있다. self join 을 하면 모든 행이 모든 행과 짝지어지므로, `p1.id < p2.id` 같은 조건으로 **자기 자신과의 짝**과 **(가, 나) (나, 가) 처럼 순서만 다른 중복 짝**을 걸러 주는 것이 핵심 기술이다.
}

@Example(id: pair-products-example, language: sql, expected: expected/sql-self-joins.txt) {
아래 예제는 작은 상품 목록을 직접 만들어 같은 범주 안의 상품 쌍을 뽑아낸다. 같은 표를 p1, p2 두 별칭으로 조인하고 id 크기 비교로 각 쌍이 한 번만 나오게 한다.

```sql
WITH demo_product (id, name, category_id) AS (
  VALUES
    (1, '볼펜', 10),
    (2, '노트', 10),
    (3, '지우개', 10),
    (4, '충전기', 20)
)
SELECT p1.name AS name_a, p2.name AS name_b
FROM demo_product AS p1
JOIN demo_product AS p2 ON p1.category_id = p2.category_id
WHERE p1.id < p2.id
ORDER BY p1.id, p2.id;
```
}

@Blank(id: self-join-blank, language: sql) {
같은 product 표를 두 번 조인해 같은 범주 안의 서로 다른 상품 쌍을 뽑는 쿼리다. 빈칸을 채워 완성해라.

```sql
SELECT p1.name AS name_a, p2.name AS name_b
FROM product AS ___1___
JOIN product AS p2 ON p1.category_id = p2.category_id
WHERE p1.id ___2___ p2.id
ORDER BY name_a, name_b
```

@Answer(slot: 1) {
`p1`
}

@Answer(slot: 2) {
`<`
}
}

@Task(id: same-city-pairs, language: sql, starter: starters/sql-self-joins.sql, tests: tests/sql-self-joins.sql, solution: solutions/sql-self-joins.sql) {
customer 표를 self join 해서 **같은 도시에 사는 서로 다른 고객 쌍**을 뽑아라. 출력 열은 순서대로 name_a, name_b, city 이고 name_a 가 항상 id 가 작은 쪽 고객이어야 한다. 각 쌍은 한 번만 나와야 하고(city, name_a, name_b 순 오름차순 정렬), city 가 NULL 인 고객은 짝을 만들지 않는다.

@Hint {
같은 표를 두 번 조인할 때는 FROM customer AS c1 JOIN customer AS c2 처럼 별칭을 둘 붙인다.
}

@Hint {
조인 조건에 c1.id < c2.id 를 넣으면 자기 자신과의 짝과 (가,나)(나,가) 중복이 모두 사라진다.
}

@Hint {
SQL 에서 NULL = NULL 은 참이 아니다. city 가 NULL 인 고객은 등호 조건에 걸리지 않으므로 별도로 걱정하지 않아도 짝에서 제외된다.
}
}

@Quiz(id: pair-dedup-quiz, answer: both-orders) {
@Question {
self join 에서 중복 제거 조건을 `p1.id <> p2.id` 로 쓰면 `p1.id < p2.id` 와 결과가 어떻게 달라질까?
}

@Choice(id: same-result) {
결과가 완전히 같다. 두 조건은 논리적으로 동치다.
}

@Choice(id: both-orders) {
같은 쌍이 (가, 나) 와 (나, 가) 로 두 번씩 나온다.
}

@Choice(id: no-rows) {
id 가 서로 다른 행끼리는 아예 한 행도 나오지 않는다.
}

@Explanation {
`<>` 는 순서를 구분하지 않으므로 (1, 2) 와 (2, 1) 이 모두 조건을 통과해 같은 짝이 두 번 나온다. 반면 `<` 는 두 행 중 id 가 작은 쪽을 항상 p1 으로 두기 때문에 각 쌍이 정확히 한 번만 나온다.
}
}

@Reflection(id: self-join-reflection) {
@Prompt(id: why-alias-needed) {
같은 표를 두 번 조인할 때 별칭을 붙이지 않으면 어떤 문제가 생길까? p1 처럼 짧은 별칭 외에 더 읽기 좋은 별칭 이름을 하나 생각해 보라.
}

@Prompt(id: lt-vs-ne) {
쌍의 순서가 의미 있는 데이터(예: 경기 결과의 홈팀-원정팀)라면 p1.id < p2.id 대신 어떤 조건을 써야 할까?
}

@Prompt(id: null-pairs) {
city 가 NULL 인 고객 둘이 실제로는 같은 도시에 살더라도 이 쿼리 결과에는 나오지 않는다. NULL 의 이런 성질이 다른 조인 상황에서는 어떤 함정이 될 수 있을까?
}
}
