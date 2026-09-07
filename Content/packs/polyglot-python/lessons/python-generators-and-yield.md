@Concept(id: generator-yield-concept) {
제너레이터는 값을 한 번에 다 만들어 두지 않고, 요청이 올 때마다 하나씩 만들어 내는 함수다. 함수 안에 `yield`를 한 번이라도 쓰면 그 함수는 제너레이터 함수가 되고, 호출해도 바로 실행되지 않고 제너레이터 객체를 돌려준다. `for` 반복이 제너레이터를 만나면 `yield` 자리에서 값을 하나 받아 쓰고, 다음 값을 요청할 때 함수가 멈췄던 자리부터 이어서 실행된다. 제너레이터 표현식은 리스트 컴프리헨션의 괄호를 소괄호로 바꾼 것으로, 리스트 대신 제너레이터를 만들므로 큰 데이터를 다룰 때 메모리를 아낄 수 있다.
}

@Example(id: generator-yield-example, language: python, expected: expected/python-generators-and-yield.txt) {
제너레이터 함수를 `for`로 순회하고, `next()`로 값을 하나씩 꺼내며, 제너레이터 표현식과 리스트 컴프리헨션의 타입 차이를 확인한다.

```python
def counter(limit):
    n = 1
    while n <= limit:
        yield n
        n += 1

for value in counter(3):
    print(f"value={value}")

gen = (x * x for x in range(4))
lst = [x * x for x in range(4)]
print(type(gen).__name__)
print(type(lst).__name__)
print(f"sum={sum(gen)}")

g = counter(2)
print(f"first={next(g)}")
print(f"second={next(g)}")
```
}

@Blank(id: generator-yield-blank, language: python) {
`yield`로 1부터 limit까지의 제곱수를 하나씩 내놓는 제너레이터를 완성하고, `sum()`으로 그 값들을 모두 더해 본다.

```python
def squares(limit):
    n = 1
    while n <= limit:
        ___1___ n * n
        n += 1

total = ___2___(squares(3))
print(total)
```

@Answer(slot: 1) {
`yield`
}

@Answer(slot: 2) {
`sum`
}
}

@Task(id: generator-yield-task, language: python, starter: starters/python-generators-and-yield.py, tests: tests/python-generators-and-yield.py, solution: solutions/python-generators-and-yield.py) {
함수 `countdown(n)`을 제너레이터 함수로 작성하라. n부터 1까지의 값을 큰 수부터 작은 수 순서로 하나씩 `yield`한다. n이 1보다 작거나 같은 정수가 아니라 0 이하이면 아무 값도 내놓지 않아야 하고, 값의 개수는 정확히 n개다. 함수 정의만 두고 최상위 실행 코드는 넣지 마라.

@Hint {
함수 안에 yield를 한 번이라도 쓰면 그 함수가 제너레이터 함수가 된다.
}

@Hint {
while 반복과 변수 하나를 써서 current가 1에 도달할 때까지 값을 내놓고 1씩 줄여라.
}

@Hint {
n이 0 이하면 while 조건이 처음부터 거짓이 되어 아무 값도 내놓지 않는다.
}
}

@Quiz(id: generator-yield-quiz, answer: lazy-generator) {
@Question {
`(x * x for x in range(4))`와 `[x * x for x in range(4)]`의 차이로 옳은 것은?
}

@Choice(id: lazy-generator) {
소괄호 버전은 제너레이터를 만들어 값을 나중에 하나씩 계산하고, 대괄호 버전은 즉시 모든 값을 계산한 리스트를 만든다.
}

@Choice(id: same-result-same-type) {
둘은 같은 리스트를 만들며 저장 방식만 다르다.
}

@Choice(id: parens-is-tuple) {
소괄호 버전은 튜플을 만들고, 대괄호 버전은 리스트를 만든다.
}

@Choice(id: parens-faster-list) {
소괄호 버전이 더 빨리 모든 값을 계산하지만 결과는 같다.
}

@Explanation {
제너레이터 표현식은 요청이 올 때까지 계산을 미루는 제너레이터를 만들고, 리스트 컴프리헨션은 순회를 모두 끝낸 리스트를 즉시 만든다. 소괄호가 튜플을 만드는 것은 함수 호출 인자가 아닌 일반 문맥에서는 해당하지 않는다.
}
}

@Reflection(id: generator-yield-reflection) {
@Prompt(id: when-generator) {
리스트로 충분한 상황에서도 굳이 제너레이터를 쓰면 좋은 경우는 언제일까? 파일이나 큰 데이터를 다뤄 본 경험에 빌려서 생각해 보자.
}

@Prompt(id: one-pass-only) {
제너레이터를 한 번 끝까지 순회한 뒤 다시 `for`로 순회하면 아무 값도 나오지 않는다. 왜 그런지 yield가 멈췄다가 이어서 실행되는 방식과 연결 지어 설명해 보자.
}
}
