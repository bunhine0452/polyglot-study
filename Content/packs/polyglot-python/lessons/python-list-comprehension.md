@Concept(id: concept-list-comprehension) {
지난 레슨들에서 리스트를 만들 때는 늘 같은 패턴을 썼다. 빈 리스트를 하나 준비하고, for문으로 반복 가능한 것에서 요소를 하나씩 꺼내고, 원하는 값으로 바꿔서 append 하는 것이다. 이 세 동작은 파이썬에서 매우 자주 등장하기 때문에 한 줄로 압축하는 전용 문법이 마련되어 있다. 그것이 리스트 컴프리헨션이다.
리스트 컴프리헨션은 대괄호 안에 `표현식 for 변수 in 반복 가능한 것` 순서로 쓴다. 예를 들어 numbers의 각 값을 두 배로 만든 리스트는 `[n * 2 for n in numbers]`로 쓴다. for문과 읽는 순서가 반대라는 점에 주의하자. for문은 반복을 먼저 준비하고 몸통에서 일을 하지만, 컴프리헨션은 할 일(표현식)을 먼저 쓰고 반복 대상을 뒤에 붙인다. 만들어지는 결과는 같은 리스트다.
조건을 붙이려면 맨 뒤에 if를 추가한다. `[n * n for n in numbers if n % 2 == 0]`은 numbers에서 짝수만 골라 제곱한 값들을 담는다. 이 if는 표현식이 계산되기 전에 걸러 주는 필터다. 조건이 참인 요소만 표현식으로 넘어가고, 거짓인 요소는 리스트에 들어가지 않는다. 조건식 자체를 표현식 자리에 두는 삼각형 같은 문법이 아니라, 필터로 쓴다는 점이 핵심이다.
이 한 줄은 빈 리스트를 만들고, 반복하고, 조건을 검사하고, append 하는 for문과 정확히 같은 일을 한다. 그래서 컴프리헨션이 아직 낯설다면 같은 결과를 내는 for문을 먼저 써 보고, 두 리스트를 ==로 비교해 출력해 보면 확신을 얻을 수 있다. 다만 반복 안에서 문장을 여러 개 실행해야 하거나 로직이 복잡해지면 억지로 한 줄로 줄이지 말고 for문을 쓰는 편이 읽기 좋다. 컴프리헨션은 반복과 변환, 필터가 단순할 때 가장 빛난다.
}

@Example(id: example-for-vs-comprehension, language: python, expected: expected/python-list-comprehension.txt) {
같은 리스트를 만드는 두 가지 방법을 나란히 실행해 비교한다. for문 여러 줄이 컴프리헨션 한 줄과 정확히 같은 결과를 내는지 확인해 보자.

```python
numbers = [1, 2, 3, 4, 5, 6]

# for문으로: 짝수만 골라 제곱하기
squares_for = []
for n in numbers:
    if n % 2 == 0:
        squares_for.append(n * n)

# 컴프리헨션으로: 같은 일을 한 줄로
squares_comp = [n * n for n in numbers if n % 2 == 0]

print("for문 결과:", squares_for)
print("컴프리헨션 결과:", squares_comp)
print("같은가?", squares_for == squares_comp)

words = ["tea", "coffee", "milk"]
long_words = [w.upper() for w in words if len(w) > 3]
print("긴 단어 대문자:", long_words)
```
}

@Blank(id: blank-comprehension-equivalence, language: python) {
예제에서 본 for문과 컴프리헨션의 등가 관계를 직접 확인하는 코드다. 도려낸 자리에 알맞은 코드 조각을 채워 넣고, 두 방식의 결과가 같게 나오는지 실행해 보자.

```python
numbers = [3, 8, 5, 12, 7, 10]

big = []
for n in numbers:
    if n > 5:
        big.append(___1___)

doubled = [n * ___2___ for n in numbers]
big_comp = [n for n in numbers if ___3___ > 5]

print("big =", big)
print("doubled =", doubled)
print("big_comp =", big_comp)
print("같은가?", big == big_comp)
```

@Answer(slot: 1) {
`n`
}

@Answer(slot: 2) {
`2`
}

@Answer(slot: 3) {
`n`
}
}

@Task(id: task-square-evens, language: python, starter: starters/python-list-comprehension.py, tests: tests/python-list-comprehension.py, solution: solutions/python-list-comprehension.py) {
주어진 숫자 리스트에서 짝수만 골라 제곱한 새 리스트를 반환하는 함수를 완성하세요. for문으로 풀어도 되지만, 이번 레슨의 목표는 컴프리헨션 한 줄로 쓰는 것입니다. 원래 리스트의 순서를 그대로 유지해야 하고, 원래 리스트는 바꾸지 말아야 합니다.

@Hint {
컴프리헨션의 맨 뒤 if 필터로 짝수만 남기고, 표현식 자리에서 n * n을 계산하면 한 줄로 끝납니다.
}
}

@Quiz(id: quiz-comprehension-filter, answer: c) {
@Question {
다음 코드를 실행하면 출력되는 것은? nums = [1, 2, 3, 4] 에서 result = [n * 10 for n in nums if n % 2 == 1] 를 만든 뒤 print(result) 를 한다.
}

@Choice(id: a) {
[10, 20, 30, 40]
}

@Choice(id: b) {
[20, 40]
}

@Choice(id: c) {
[10, 30]
}

@Choice(id: d) {
[1, 3]
}

@Explanation {
if n % 2 == 1은 홀수인 요소만 통과시키는 필터다. nums의 홀수는 1과 3이고, 표현식 n * 10이 계산되어 [10, 30]이 만들어진다. [20, 40]을 고르면 짝수만 남은 것이고, [1, 3]을 고르면 필터는 통과했지만 변환 표현식이 적용되지 않은 것이다.
}
}

@Reflection(id: reflection-comprehension-vs-for) {
@Prompt(id: when-prefer) {
for문으로도 만들 수 있는 리스트를 컴프리헨션으로 쓰면 무엇이 좋고, 무엇이 어려울까? 예제의 코드를 본인이라면 어느 쪽으로 쓰겠는지, 그 이유와 함께 적어 보세요.
}

@Prompt(id: read-aloud) {
컴프리헨션을 소리 내어 읽어 보면 어떤 문장이 되나요? 표현식, for, if를 각각 어떤 말로 읽어야 자연스러운지 찾아 보세요.
}
}
