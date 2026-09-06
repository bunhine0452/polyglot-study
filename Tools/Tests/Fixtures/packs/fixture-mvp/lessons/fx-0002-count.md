@Concept(id: count-basics) {
`GROUP BY` 는 행을 그룹으로 접고, 집계 함수는 그룹마다 값을 하나 만든다.
이 레슨의 샘플 데이터는 `assets/seed.sql` 이 만든 `item` 테이블이다.
}

@Example(id: count-run, language: sql, expected: expected/fx-0002-count-run.txt) {
종류별 행 수를 센다.

```sql
SELECT kind, COUNT(*) AS n
FROM item
GROUP BY kind
ORDER BY kind;
```
}

@Blank(id: count-blank, language: sql) {
전체 가격 합을 구하려 한다. 두 칸을 채워라.

```sql
SELECT ___1___(price) AS total
FROM ___2___;
```

@Answer(slot: 1) {
`SUM`
}

@Answer(slot: 2) {
`item`
}
}

@Task(id: top-price, language: sql, starter: starters/fx-0002-count.sql, tests: tests/fx-0002-count.sql, solution: solutions/fx-0002-count.sql) {
종류별 최고가를 `kind`, `price` 두 열로 뽑아라. 정렬은 `kind` 오름차순.

@Hint {
집계 함수와 `GROUP BY` 를 함께 쓴다.
}
}

@Quiz(id: count-quiz, answer: skips-null) {
@Question {
`COUNT(column)` 과 `COUNT(*)` 의 차이는 무엇인가?
}

@Choice(id: skips-null) {
`COUNT(column)` 은 NULL 인 행을 세지 않는다.
}

@Choice(id: identical) {
둘은 완전히 같다.
}

@Explanation {
집계 함수는 NULL 을 건너뛴다.
}
}

@Reflection(id: count-reflect) {
@Prompt(id: having) {
`WHERE` 와 `HAVING` 이 걸러내는 대상은 어떻게 다른가?
}
}
