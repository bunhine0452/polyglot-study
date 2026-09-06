@Concept(id: concept-variables-math) {
프로그램은 값을 계산하면서 일을 한다. 그런데 계산 결과를 매번 다시 타이프할 수는 없으니, 값에 이름을 붙여 저장해 두고 이름으로 꺼내 쓴다. 이렇게 이름 붙여 저장한 값을 변수라고 부른다. 변수를 만드는 방법은 아주 단순하다. 이름 = 값 을 한 줄 쓰면 끝이다. 예를 들어 age = 20 이라고 쓰면 age 라는 이름에 20 이 담기고, 이후 코드에서 age 를 쓸 때마다 20 이 나온다. 여기서 = 는 수학의 같다 표시가 아니라 오른쪽 값을 왼쪽 이름에 담으라는 할당 표시라는 점을 기억하자. 같다 비교는 나중에 다른 기호로 배운다.

파이썬이 다루는 숫자는 크게 두 종류다. 소수점이 없는 수는 int(정수), 소수점이 있는 수는 float(실수)다. 20 은 int, 1.72 는 float 다. 눈으로 보기엔 비슷해도 내부에서 다르게 저장되기 때문에 어떤 타입인지 아는 것이 중요하다. 이때 type() 함수를 쓴다. type(20) 을 넣으면 class int 라고 알려 주고, type(1.72) 는 class float 라고 알려 준다.

숫자를 담은 변수로 산술 연산을 할 수 있다. 더하기 +, 빼기 -, 곱하기 * 는 우리가 아는 그대로다. 나누기는 연산자가 세 개다. 슬래시 하나 / 는 우리가 아는 나눗셈인데, 결과가 항상 float 로 나온다. 7 / 2 는 3.5 이고, 나누어떨어지는 10 / 2 도 5 가 아니라 5.0 이 나온다. 슬래시 두 개 // 는 정수 나눗셈으로 소수점 아래를 버리고 몫만 남긴다. 7 // 2 는 3 이다. 퍼센트 기호 % 는 나눈 뒤 남는 나머지를 구한다. 7 % 2 는 1 이다. 별표 두 개 ** 는 거듭제곱이다. 2 ** 10 은 2 를 열 번 곱한 1024 다.

이 연산자들은 서로 섞여 쓸 수 있다. 계산 순서는 수학과 같아서 * 와 / 가 + 와 - 보다 먼저이고, 괄호를 쓰면 괄호가 가장 먼저다. 3 + 4 * 2 가 14 인 이유다. 헷갈릴 것 같으면 괄호로 순서를 직접 표시하면 된다.
}

@Example(id: example-variables-math, language: python, expected: expected/python-variables-and-numeric-operators.txt) {
아래 코드를 실행해 보자. 변수에 값을 담고, 담긴 값을 다시 꺼내 계산과 출력에 쓴다. 특히 네 가지 나눗셈·거듭제곱 연산이 각각 어떤 결과를 내는지 눈으로 확인하자.

```python
age = 20
height = 1.72
print(age, type(age))
print(height, type(height))

total = age + 5
print("total =", total)

print(7 / 2)
print(7 // 2)
print(7 % 2)
print(2 ** 10)

price = 1500
count = 4
print("총액:", price * count)
```
}

@Blank(id: blank-variables-math, language: python) {
빈칸을 채워 아래 프로그램을 완성해 보세요. 328쪽짜리 책을 7일에 걸쳐 읽을 때, 하루에 읽어야 할 페이지 수와 끝에 남는 페이지 수를 구하고, 7일을 분으로 바꿔 봅니다. 마지막 줄로 per_day 에 담긴 값이 어떤 타입인지 확인합니다. 채우고 나면 하루에 읽을 페이지는 46, 남는 페이지는 6, 총 분은 10080 이 나와야 합니다.

```python
pages = 328
days = 7

# 하루에 읽어야 할 페이지 수 (정수 나눗셈)
per_day = pages ___1___ days
print("하루에 읽을 페이지:", per_day)

# 마지막에 남는 페이지 수
rest = pages ___2___ days
print("남는 페이지:", rest)

# 7일을 분 단위로 환산
total_minutes = days ___3___ 24 * 60
print("총 분:", total_minutes)

print(___4___(per_day))
```

@Answer(slot: 1) {
`//`
}

@Answer(slot: 2) {
`%`
}

@Answer(slot: 3) {
`*`
}

@Answer(slot: 4) {
`type`
}
}

@Task(id: task-variables-math, language: python, starter: starters/python-variables-and-numeric-operators.py, tests: tests/python-variables-and-numeric-operators.py, solution: solutions/python-variables-and-numeric-operators.py) {
과자 total 개를 people 명에게 똑같이 나누어 주려 합니다. 한 사람당 몇 개씩 받는지(정수)와 나누고 남는 개수(정수)를 구하는 함수 두 개를 완성하세요. 정수 나눗셈 연산자와 나머지 연산자를 사용하면 한 줄로 해결됩니다. people 은 1 이상이라고 가정해도 됩니다.

@Hint {
정수 나눗셈(몫)은 // 연산자로 구합니다.
}

@Hint {
나머지는 % 연산자로 구합니다.
}

@Hint {
pass 는 아무것도 하지 않는 자리표시자이므로 return 문으로 바꿔야 합니다.
}
}

@Quiz(id: quiz-variables-math, answer: b) {
@Question {
파이썬에서 10 / 2 를 계산하면 결과로 무엇이 나오고, 그 결과의 타입은 무엇일까요?
}

@Choice(id: a) {
정수 5 가 나온다. 10 과 2 가 둘 다 int 이므로 결과도 int 다.
}

@Choice(id: b) {
실수 5.0 이 나온다. / 는 나누어떨어져도 항상 float 를 돌려준다.
}

@Choice(id: c) {
정수 2 가 나온다. / 는 나눗셈의 몫만 구하는 연산자다.
}

@Choice(id: d) {
실수 0.2 가 나온다. / 는 왼쪽 수를 오른쪽 수로 나누는 연산자다.
}

@Explanation {
/ 연산자는 두 수가 모두 정수이고 나누어떨어지는 경우에도 결과를 항상 float 로 돌려준다. 10 / 2 의 결과는 5.0 이고 type(10 / 2) 는 class float 다. 몫만 정수로 얻고 싶다면 // 를 써야 한다.
}
}

@Reflection(id: reflection-variables-math) {
@Prompt(id: reflect-1) {
일상에서 찾을 수 있는 상황 하나를 골라, 그 상황에서 / 와 // 중 어떤 연산자를 써야 하는지 그 이유와 함께 적어 보세요. 예를 들어 피자를 사람 수대로 나누는 경우와 시험 점수 평균을 내는 경우는 결과가 다를 수 있습니다.
}

@Prompt(id: reflect-2) {
변수에 이름을 붙일 때 total_price 처럼 의미가 드러나는 이름과 tp 처럼 짧은 이름 중 어떤 쪽이 좋을까요? 본인이 나중에 다시 코드를 읽는 상황을 상상하며 이유를 적어 보세요.
}
}
