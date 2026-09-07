@Concept(id: concept-set-operations) {
집합 연산은 두 쿼리의 결과를 행 단위로 합치거나 빼는 연산이다. **UNION** 은 두 결과를 합치면서 중복 행을 제거하고, **UNION ALL** 은 중복을 그대로 남기므로 일반적으로 더 빠르다. **INTERSECT** 는 양쪽 쿼리 모두에 있는 행만 남기고, **EXCEPT** 는 위쪽 쿼리에는 있지만 아래쪽 쿼리에는 없는 행만 남긴다. 두 쿼리는 열 개수가 같아야 하며 열 이름은 위쪽 쿼리를 따라가고, 정렬이 필요하면 마지막 쿼리 뒤에 `ORDER BY` 를 하나만 붙인다.
}

@Example(id: example-counts, language: sql, expected: expected/sql-set-operations.txt) {
고객 수를 세 가지 관점에서 세어 하나의 결과셋으로 합친다. UNION ALL 이 세 쿼리의 결과를 그대로 이어 붙여, 여섯 명의 고객 중 네 명만 주문했음을 한 표로 보여준다.

```sql
SELECT '전체 고객' AS label, COUNT(*) AS n
FROM customer
UNION ALL
SELECT '주문한 고객', COUNT(DISTINCT customer_id)
FROM "order"
UNION ALL
SELECT '주문 없는 고객', COUNT(*)
FROM customer
WHERE NOT EXISTS (SELECT 1 FROM "order" o WHERE o.customer_id = customer.id)
ORDER BY n;
```
}

@Blank(id: blank-union-order, language: sql) {
같은 집합을 UNION 으로 자기 자신과 합치면 중복이 제거되어 하나의 집합이 된다. 중복을 없애고 번호순으로 정렬해 보자.

```sql
WITH nums(n) AS (VALUES (1), (2), (2), (3))
SELECT n
FROM nums
___1___
SELECT n
FROM nums
___2___ n;
```

@Answer(slot: 1) {
`UNION`
}

@Answer(slot: 2) {
`ORDER BY`
}
}

@Task(id: task-except-no-order, language: sql, starter: starters/sql-set-operations.sql, tests: tests/sql-set-operations.sql, solution: solutions/sql-set-operations.sql) {
주문 기록이 하나도 없는 고객의 이름을 EXCEPT 로 구하세요. 위쪽 쿼리는 전체 고객의 이름, 아래쪽 쿼리는 주문이 있는 고객의 이름 집합을 만들어 차집합을 구하고, name 오름차순으로 정렬하세요. 결과 열 이름은 name 이어야 합니다.

@Hint {
EXCEPT 위쪽 쿼리는 customer 의 전체 이름을, 아래쪽 쿼리는 주문이 있는 고객의 이름을 만들어야 합니다.
}

@Hint {
주문이 있는 고객은 customer 와 "order" 를 customer_id 로 조인하면 구할 수 있습니다. 표 이름 order 는 큰따옴표로 감싸야 합니다.
}

@Hint {
두 쿼리의 열 개수를 맞추고, 정렬은 합집합 전체에 딱 한 번 ORDER BY name 으로 붙입니다.
}
}

@Quiz(id: quiz-union-vs-union-all, answer: union-all-keeps) {
@Question {
UNION 과 UNION ALL 의 차이로 옳은 것은?
}

@Choice(id: both-dedupe) {
두 연산 모두 결과에서 중복 행을 자동으로 제거한다.
}

@Choice(id: union-all-keeps) {
UNION ALL 은 중복 행을 그대로 남겨서 UNION 보다 일반적으로 빠르고, UNION 은 중복 제거를 위한 추가 작업이 필요하다.
}

@Choice(id: union-column-names) {
UNION 은 양쪽 쿼리의 열 이름이 달라도 합칠 수 있지만, UNION ALL 은 열 이름이 같아야 한다.
}

@Explanation {
UNION 은 중복 제거를 위해 정렬이나 해시 같은 추가 작업을 수행하므로 UNION ALL 보다 느릴 수 있다. 중복을 의도적으로 유지해도 된다면 UNION ALL 이 맞다. 열 이름은 항상 위쪽 쿼리를 따라가며, 두 연산 모두 열 개수만 같으면 된다.
}
}

@Reflection(id: reflection-set-ops) {
@Prompt(id: prompt-choose) {
중복 제거가 꼭 필요한 상황과 그렇지 않은 상황을 각각 하나씩 들고, 각 상황에서 어떤 집합 연산을 택할지 설명해 보세요.
}

@Prompt(id: prompt-except-vs-exists) {
EXCEPT 로 구한 주문 없는 고객과 NOT EXISTS 로 구한 결과가 같습니다. 두 방식 중 무엇이 더 읽기 쉽다고 생각하는지 이유와 함께 적어보세요.
}

@Prompt(id: prompt-order-by-place) {
집합 연산에서 ORDER BY 는 마지막 쿼리 뒤에 하나만 붙입니다. 중간 쿼리마다 ORDER BY 를 붙이면 어떻게 될지 예상을 적어보고 직접 실험해 보세요.
}
}
