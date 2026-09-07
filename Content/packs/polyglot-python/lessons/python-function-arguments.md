@Concept(id: default-keyword-args) {
함수를 정의할 때 매개변수에 기본값을 지정하면, 호출할 때 그 인자를 생략할 수 있습니다. 예를 들어 def greet(name, greeting="안녕") 처럼 정의하면 greet("민수") 처럼 greeting 을 넘기지 않아도 기본값이 사용됩니다. 호출할 때 greet(name="민수", greeting="하이") 처럼 매개변수 이름을 직접 지정하는 것을 키워드 인자라고 하며, 순서와 상관없이 인자를 넘길 수 있어 호출 의미가 더 명확해집니다. 위치로만 값을 넘기는 방식은 위치 인자라고 부르며, 키워드 인자와 섞어 쓸 때는 반드시 위치 인자를 먼저 써야 합니다.
}

@Example(id: greet-example, language: python, expected: expected/python-function-arguments.txt) {
기본값이 있는 함수를 인자를 생략하거나, 위치로 넘기거나, 이름을 지정해 넘기는 세 가지 방식으로 호출해 봅니다.

```python
def greet(name, greeting="안녕"):
    return f"{greeting}, {name}!"

print(greet("민수"))
print(greet("지은", "좋은 아침"))
print(greet(greeting="잘 가", name="철수"))
```
}

@Blank(id: order-blank, language: python) {
커피 주문 함수의 매개변수에 기본값을 정하고, 키워드 인자로 호출하는 코드의 빈칸을 채워 보세요.

```python
def order(drink, size=___1___, ice=___2___):
    label = "아이스" if ice else "핫"
    return f"{label} {size} {drink}"

print(order("아메리카노"))
print(order("카페라떼", size=___3___))
print(___4___)
```

@Answer(slot: 1) {
`"중간"`
}

@Answer(slot: 2) {
`True`
}

@Answer(slot: 3) {
`"큰"`
}

@Answer(slot: 4) {
`order(size="작은", ice=False, drink="초코")`
}
}

@Task(id: make-profile-task, language: python, starter: starters/python-function-arguments.py, tests: tests/python-function-arguments.py, solution: solutions/python-function-arguments.py) {
프로필 문장을 만드는 함수 make_profile 을 작성하세요. 매개변수는 name, age, city, hobby 네 개이며 city 는 기본값 "서울", hobby 는 기본값 "없음" 을 가집니다. 반환값은 f"{name}({age}세) - {city}, 취미: {hobby}" 형태의 문자열입니다. 호출 시 city 나 hobby 를 생략하거나, 키워드 인자로 순서를 바꿔 넘겨도 올바르게 동작해야 합니다.

@Hint {
def make_profile(name, age, city="서울", hobby="없음") 처럼 매개변수 이름 뒤에 = 기본값 을 붙이면 호출 시 생략할 수 있습니다.
}

@Hint {
기본값이 있는 매개변수는 기본값이 없는 매개변수 뒤에 와야 합니다.
}

@Hint {
반환할 문자열은 f-string 으로 만들고 return 문으로 돌려주면 됩니다.
}
}

@Quiz(id: default-arg-quiz, answer: exp-default-two) {
@Question {
다음 코드를 실행했을 때 출력으로 알맞은 것은?

def power(base, exp=2):
    return base ** exp

print(power(3))
}

@Choice(id: exp-default-two) {
9 — exp 가 생략되면 기본값 2가 사용되어 3의 제곱이 계산된다
}

@Choice(id: exp-missing-error) {
오류가 발생한다 — exp 값이 넘겨지지 않아서 함수를 호출할 수 없다
}

@Choice(id: exp-default-one) {
3 — exp 가 생략되면 1로 취급되어 base 그대로 반환된다
}

@Explanation {
기본값이 정의된 매개변수는 호출 시 생략해도 정의한 기본값이 사용됩니다. exp=2 로 정의되어 있으므로 power(3) 은 power(3, 2) 와 같고 3 ** 2 = 9 가 출력됩니다.
}
}

@Reflection(id: call-style-reflection) {
@Prompt(id: when-keyword) {
여러 매개변수 중 같은 타입의 값이 둘 이상일 때, 키워드 인자로 호출하면 어떤 실수를 예방할 수 있을지 본인 경험을 곁들여 설명해 보세요.
}

@Prompt(id: default-order) {
매개변수 목록에서 기본값이 있는 매개변수를 기본값이 없는 것보다 앞에 두면 왜 문제가 생기는지, 오류 메시지를 상상하며 설명해 보세요.
}
}
