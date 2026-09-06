@Concept(id: concept-conditionals) {
지금까지 작성한 코드는 항상 위에서 아래로 한 번씩 실행되었다. 조건문은 이 흐름에 갈림길을 만든다. 갈림길에서 어느 쪽으로 갈지를 결정하는 것은 불리언 값, 즉 True 아니면 False다.

비교 연산자는 두 값을 비교해서 불리언을 만든다. == 는 같음, != 는 다름, < 와 > 는 크기를 비교한다. 예를 들어 5 > 3 은 True 로 평가되고, 5 == 3 은 False 로 평가된다. 여기서 주의할 점이 하나 있다. 변수에 값을 담을 때 쓰는 = 는 대입이고, 비교는 == 두 개를 쓴다는 것이다. 초보자가 가장 자주 겪는 실수가 바로 이 둘의 혼동이다.

and, or, not 은 이미 있는 불리언 값을 조합해 더 복잡한 조건을 만든다. and 는 양쪽이 모두 참일 때만 참이고, or 는 둘 중 하나만 참이어도 참이며, not 은 참과 거짓을 뒤집는다. 예를 들어 '나이가 19세 이상이고 티켓을 가지고 있다'라는 조건은 age >= 19 and has_ticket 처럼 쓴다.

if 문은 바로 뒤의 조건식이 참일 때만, 들여쓰기된 블록을 실행한다. elif 는 '앞의 조건이 거짓이었다면 이 조건을 검사하라'는 뜻이고, else 는 앞의 모든 조건이 거짓일 때 실행된다. 중요한 규칙이 하나 있다. 조건 여러 개 중 처음으로 참이 되는 블록 하나만 실행되고, 나머지는 아예 건너뛴다는 것이다. 그래서 조건을 검사하는 순서가 결과를 바꿀 수 있다. 범위가 좁은 조건, 즉 더 엄격한 조건을 먼저 검사하는 것이 안전한 습관이다.

이 레슨에서는 비교 연산식이 어떤 불리언으로 평가되는지 print 로 직접 출력해 확인하고, if 와 elif, else 로 분기를 만들어 본다.
}

@Example(id: example-conditionals, language: python, expected: expected/python-conditionals-if-elif-else.txt) {
비교 연산식과 논리 연산식을 print 로 출력해 불리언 값이 어떻게 나오는지 확인하고, 같은 값으로 분기를 만들어 본다. temperature 가 31이므로 어떤 줄이 True 이고 어떤 줄이 False 인지 실행하기 전에 먼저 예상해 보라.

```python
temperature = 31

print(temperature > 30)
print(temperature == 25)
print(temperature != 25)
print(temperature <= 31 and temperature > 0)
print(temperature < 10 or temperature > 40)

if temperature > 30:
    print("폭염 경보")
elif temperature > 15:
    print("선선한 날씨")
else:
    print("쌀쌀한 날씨")

age = 20
has_ticket = True

if age >= 19 and has_ticket:
    print("입장 가능")

is_raining = False
if not is_raining:
    print("우산 없이 외출")
```
}

@Blank(id: blank-conditionals, language: python) {
비교, 분기, 논리 연산을 한 코드에 모두 써 봅니다. 도려진 자리에 알맞은 키워드와 값을 채워 실행 결과를 예상해 보세요. score가 74일 때 어떤 등급이 출력될지, happy가 True일 때 and 대신 어떤 연산자가 '둘 중 하나는 참'을 만족하는지 생각해 보세요.

```python
score = 74

print(score >= 70)

___1___ score >= 90:
    print("A등급")
___2___ score >= 80:
    print("B등급")
else:
    print(___3___)

happy = True
if happy ___4___ not happy:
    print("둘 중 하나는 참")
```

@Answer(slot: 1) {
`if`
}

@Answer(slot: 2) {
`elif`
}

@Answer(slot: 3) {
`"C등급"`
}

@Answer(slot: 4) {
`or`
}
}

@Task(id: task-ticket-price, language: python, starter: starters/python-conditionals-if-elif-else.py, tests: tests/python-conditionals-if-elif-else.py, solution: solutions/python-conditionals-if-elif-else.py) {
놀이공원 매표소 요금 계산 함수를 완성합니다. 나이와 학생 여부를 받아 요금을 정수로 반환하는 함수 ticket_price 를 아래 규칙대로 구현하세요.

- age가 8 미만이면 0 (음수 나이도 8 미만으로 처리)
- age가 65 이상이면 3000 (학생 여부와 관계없이)
- age가 8 이상 65 미만이고 학생이면(is_student가 True이면) 5000
- 그 외에는 8000

숨은 테스트에는 8세와 65세 같은 경계값과 65세 이상이면서 학생인 경우가 포함되어 있습니다. 조건을 검사하는 순서에 유의하세요.

@Hint {
조건을 검사하는 순서가 중요합니다. 나이 구간 조건을 먼저 검사하고, 그다음 학생 여부를 검사하세요.
}

@Hint {
if 와 elif 로 이어진 분기에서는 처음으로 참이 되는 블록만 실행되므로, 이미 검사가 끝난 범위를 elif 에서 다시 쓸 필요가 없습니다.
}

@Hint {
반환은 print 가 아니라 return 으로 합니다.
}
}

@Quiz(id: quiz-conditionals, answer: a) {
@Question {
score가 95일 때 아래 코드가 출력하는 것은?

if score >= 90:
    print("A")
elif score >= 80:
    print("B")
else:
    print("C")
}

@Choice(id: a) {
A
}

@Choice(id: b) {
A와 B
}

@Choice(id: c) {
B
}

@Choice(id: d) {
C
}

@Explanation {
if 와 elif 로 이어진 분기에서는 처음으로 참이 되는 블록 하나만 실행되고 나머지는 건너뛴다. score >= 90 이 참이므로 A만 출력되고, score >= 80 도 참이지만 이미 elif 는 검사조차 되지 않는다.
}
}

@Reflection(id: reflection-conditionals) {
@Prompt(id: reflection-q1) {
조건을 검사하는 순서를 바꾸면 결과가 달라지는 상황을 예시로 하나 들어 보세요. 예를 들어 점수로 등급을 나눌 때 조건을 어떤 순서로 배치해야 하는지, 왜 그래야 하는지 자기 말로 설명해 보세요.
}

@Prompt(id: reflection-q2) {
and 와 or 중 어느 쪽이 조건을 더 엄격하게 만드는지, 본인이 실제로 분기를 작성할 때 활용할 만한 예를 곁들여 설명해 보세요.
}
}
