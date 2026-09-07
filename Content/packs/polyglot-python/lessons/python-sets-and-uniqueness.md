@Concept(id: set-basics) {
집합(set)은 중복을 허용하지 않는 자료형으로, 같은 값을 여러 번 넣어도 하나만 남습니다. 리스트를 set()에 넘기면 중복이 자동으로 제거된 집합이 만들어지고, add()로 새 요소를 추가할 수 있습니다. 이미 들어 있는 값을 다시 추가해도 아무 일도 일어나지 않으므로 집합의 크기는 변하지 않습니다. in 연산자로 어떤 값이 집합에 들어 있는지 빠르게 확인할 수 있고, len()으로 서로 다른 값이 몇 개인지 셀 수 있습니다.
}

@Example(id: set-fruit-basket, language: python, expected: expected/python-sets-and-uniqueness.txt) {
과일 목록에서 중복을 제거해 고유한 과일이 몇 종류인지 세고, 새 과일을 추가해 봅니다.

```python
fruits = ["사과", "바나나", "사과", "포도", "바나나", "사과"]
basket = set(fruits)
print(f"전체 항목: {len(fruits)}개")
print(f"고유한 항목: {len(basket)}개")
print(f"중복이었던 항목: {len(fruits) - len(basket)}개")

if "포도" in basket:
    print("포도가 바구니에 있습니다")

basket.add("딸기")
basket.add("딸기")
print(f"딸기 추가 후: {len(basket)}개")
```
}

@Blank(id: set-fill-blank, language: python) {
방문한 도시 목록에서 집합으로 중복을 지우고, 새 도시를 추가한 뒤 대전 방문 여부를 확인하는 코드입니다.

```python
visited = ["서울", "부산", "서울", "대구", "부산"]
cities = ___1___(visited)
cities.___2___("광주")

if "대전" ___3___ cities:
    print("대전 방문 기록 있음")
else:
    print(f"고유 도시 수: {___4___(cities)}개")
```

@Answer(slot: 1) {
`set`
}

@Answer(slot: 2) {
`add`
}

@Answer(slot: 3) {
`in`
}

@Answer(slot: 4) {
`len`
}
}

@Task(id: unique-values-task, language: python, starter: starters/python-sets-and-uniqueness.py, tests: tests/python-sets-and-uniqueness.py, solution: solutions/python-sets-and-uniqueness.py) {
리스트를 받아 중복을 제거한 값을 첫 등장 순서 그대로 리스트로 반환하는 함수 unique_values(items)를 완성하세요. 집합 하나와 결과 리스트 하나를 두고, 각 요소가 집합에 이미 있는지 in으로 확인한 뒤 없으면 집합에 add()하고 결과 리스트에도 추가합니다. 빈 리스트는 빈 리스트를 반환합니다.

@Hint {
처음 보는 값인지 확인하려면 if item not in seen: 처럼 not in을 쓸 수 있습니다.
}

@Hint {
값을 결과에 넣은 뒤 반드시 seen.add(item)으로 기록해야 같은 값이 다시 들어오지 않습니다.
}

@Hint {
반복이 끝나면 result를 return 하면 됩니다.
}
}

@Quiz(id: set-quiz, answer: distinct-count) {
@Question {
numbers = [1, 2, 2, 3, 3, 3]일 때 len(set(numbers))의 값은 무엇일까요?
}

@Choice(id: list-length) {
6 — 집합은 원래 리스트의 모든 항목을 그대로 유지한다
}

@Choice(id: distinct-count) {
3 — 집합이 중복을 지워 {1, 2, 3}이 되므로
}

@Choice(id: duplicate-count) {
4 — 중복된 항목의 개수만큼 크기가 줄어든다
}

@Choice(id: raises-error) {
오류가 발생한다 — 리스트를 set()에 바로 넘길 수 없다
}

@Explanation {
set(numbers)는 중복을 자동으로 제거해 {1, 2, 3}이 되고, 여기에 len()을 적용하면 서로 다른 값의 개수인 3이 나옵니다. 집합은 항목을 유지하지도, 중복 개수만큼 줄지도 않으며 리스트를 그대로 넘겨도 오류 없이 변환됩니다.
}
}

@Reflection(id: set-reflection) {
@Prompt(id: when-set-over-list) {
리스트 대신 집합을 쓰면 좋은 상황을 하나 생각해 보고, 어떤 문제에서 중복 제거나 빠른 포함 확인이 도움이 될지 적어보세요.
}

@Prompt(id: order-tradeoff) {
집합은 값의 순서를 기억하지 않습니다. 순서가 중요한 데이터를 set()으로 바꾸면 무엇을 잃게 되는지 본인 경험이나 상상을 바탕으로 설명해 보세요.
}
}
