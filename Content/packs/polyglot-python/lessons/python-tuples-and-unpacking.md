@Concept(id: tuple-unpacking-concept) {
튜플은 리스트처럼 여러 값을 묶지만, 한 번 만들면 내용을 바꿀 수 없는 자료형이다. 소괄호로 (1, 2, 3)처럼 쓰고, 인덱스로 요소를 꺼낼 수 있다는 점은 리스트와 같다. 언패킹은 묶여 있던 값을 여러 변수에 한 번에 나눠 담는 문법이다. a, b = (1, 2)처럼 쓰면 a에는 1이, b에는 2가 들어가고, 왼쪽 변수 개수와 오른쪽 값 개수가 같아야 한다. enumerate()는 for 반복에서 (인덱스, 값) 튜플을 하나씩 주는 함수이므로, for i, value in enumerate(items)처럼 언패킹과 함께 쓰면 인덱스와 값을 동시에 다룰 수 있다.
}

@Example(id: tuple-unpacking-example, language: python, expected: expected/python-tuples-and-unpacking.txt) {
튜플을 만들고 인덱스로 꺼내 보고, 언패킹으로 세 변수에 나눠 담은 뒤, enumerate()로 번호와 이름을 함께 출력한다.

```python
sizes = ("S", "M", "L")
print(sizes[1])

small, medium, large = sizes
print(f"중간: {medium}")

names = ("철수", "영희")
for i, name in enumerate(names, start=1):
    print(f"{i}번 {name}")
```
}

@Blank(id: tuple-unpacking-blank, language: python) {
튜플을 좌표로 언패킹하고, enumerate()로 리스트를 반복하면서 인덱스와 값을 함께 출력하는 코드를 완성하자.

```python
point = (3, 5)
x, y = point
print(f"x={x}, y={y}")

fruits = ["사과", "바나나"]
for i, fruit in ___1___(fruits):
    print(f"{___2___}: {fruit}")

a, b = 1, 2
a, b = b, a
print(a, b)
```

@Answer(slot: 1) {
`enumerate`
}

@Answer(slot: 2) {
`i`
}
}

@Task(id: min-max-task, language: python, starter: starters/python-tuples-and-unpacking.py, tests: tests/python-tuples-and-unpacking.py, solution: solutions/python-tuples-and-unpacking.py) {
함수 min_max(numbers)를 완성하라. numbers가 비어 있으면 (None, None)을 반환하고, 그렇지 않으면 가장 작은 값과 가장 큰 값을 순서대로 묶은 튜플을 반환한다. 반복할 때 enumerate()로 인덱스와 값을 함께 꺼내 써도 좋다.

@Hint {
빈 리스트는 if not numbers: 로 판별할 수 있다.
}

@Hint {
첫 요소 numbers[0] 을 최솟값·최댓값 후보로 두고 반복하며 비교하라.
}

@Hint {
최종 반환은 return (smallest, largest) 처럼 괄호로 묶어 튜플로 돌려주면 된다.
}
}

@Quiz(id: unpack-mismatch-quiz, answer: value-error) {
@Question {
튜플 (1, 2, 3)을 두 변수에 언패킹하는 a, b = (1, 2, 3)을 실행하면 어떻게 될까?
}

@Choice(id: value-error) {
개수가 맞지 않아 오류가 발생한다.
}

@Choice(id: extra-dropped) {
a에 1, b에 2가 담기고 3은 버려진다.
}

@Choice(id: rest-in-last) {
a에 1이 담기고 b에 (2, 3)이 담긴다.
}

@Explanation {
언패킹은 왼쪽 변수 개수와 오른쪽 값 개수가 정확히 같아야 하고, 다르면 ValueError가 발생한다. 남는 값을 버리거나 묶어 담는 일은 자동으로 일어나지 않는다.
}
}

@Reflection(id: tuple-unpacking-reflection) {
@Prompt(id: tuple-vs-list) {
값을 묶을 때 리스트 대신 튜플을 쓰면 좋은 상황은 언제일까? 바뀌면 안 되는 데이터를 예로 들어 설명해 보자.
}

@Prompt(id: enumerate-usage) {
리스트를 반복하면서 인덱스도 필요한 코드를 enumerate() 없이 while로 쓰는 것과 비교하면, enumerate()와 언패킹이 어떤 점을 편하게 해 주는가?
}
}
