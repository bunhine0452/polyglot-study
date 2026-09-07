@Concept(id: import-and-modules) {
파이썬에는 이미 만들어진 기능들이 모듈이라는 이름표로 묶여 있다. import math 를 쓰면 math 모듈 전체를 가져와서, 점(.)으로 모듈 안의 함수에 접근할 수 있다. 예를 들어 math.sqrt(16) 은 16의 제곱근인 4.0 을 돌려주고, math.pi 는 원주율 값을 담은 변수다. random 모듈은 무작위 숫자를 다룬다. random.random() 은 0 이상 1 미만의 무작위 실수를, random.randint(a, b) 는 a 이상 b 이하의 무작위 정수를, random.choice(리스트) 는 목록에서 하나를 무작위로 골라 돌려준다. 무작위 기능은 실행할 때마다 결과가 달라지는데, random.seed(숫자) 를 먼저 호출하면 같은 숫자에 대해 항상 같은 결과가 나오므로 테스트하거나 재현할 때 유용하다. 주의할 점은 import math 를 했다면 sqrt(16) 처럼 함수 이름만 쓸 수 없다는 것이다. 반드시 math.sqrt(16) 처럼 모듈 이름을 점 앞에 붙여야 파이썬이 어디 있는 함수인지 찾을 수 있다.
}

@Example(id: math-random-demo, language: python, expected: expected/python-modules-and-import.txt) {
math 모듈의 함수와 상수를 점으로 접근해 써 보고, seed 를 심은 뒤 random 모듈로 무작위 실수 두 개를 뽑아 본다.

```python
import math
import random

random.seed(42)

print(math.sqrt(2))
print(math.floor(3.7))
print(math.ceil(3.2))
print(math.pi)

first = random.random()
second = random.random()
print(f"첫 번째: {first}")
print(f"두 번째: {second}")
```
}

@Blank(id: fill-import-blank, language: python) {
math 모듈의 원주율로 원의 넓이를 구하고, random 모듈로 목록에서 하나를 골라 보자. 빈칸을 채워라.

```python
___1___ math

radius = 3
area = math.___2___ * radius ** 2
print(f"넓이: {area:.2f}")

___3___ random
random.seed(1)
pick = random.___4___(["가위", "바위", "보"])
print(pick)
```

@Answer(slot: 1) {
`import`
}

@Answer(slot: 2) {
`pi`
}

@Answer(slot: 3) {
`import`
}

@Answer(slot: 4) {
`choice`
}
}

@Task(id: module-functions-task, language: python, starter: starters/python-modules-and-import.py, tests: tests/python-modules-and-import.py, solution: solutions/python-modules-and-import.py) {
math 와 random 모듈을 import 해서 세 함수를 구현하라. circle_area(radius) 는 반지름이 radius 인 원의 넓이를 math.pi 로 계산해 돌려준다. hypotenuse(a, b) 는 직각삼각형의 빗변 길이를 math.sqrt 로 계산해 돌려준다. pick_random(items, seed) 는 random.seed(seed) 를 먼저 호출한 뒤 random.choice 로 items 에서 하나를 골라 돌려준다. 세 함수 모두 최상위 실행 코드 없이 함수 정의만 둬라.

@Hint {
원의 넓이는 파이 곱하기 반지름의 제곱이다. math.pi 와 ** 연산자를 함께 써라.
}

@Hint {
빗변은 밑변의 제곱과 높이의 제곱을 더한 뒤 제곱근을 씌운 값이다. math.sqrt 가 제곱근을 계산해 준다.
}

@Hint {
random.choice 는 목록 하나를 인자로 받고, random.seed 는 그 전에 호출해야 같은 씨앗에 같은 결과가 나온다.
}
}

@Quiz(id: import-attribute-quiz, answer: nameerror) {
@Question {
import math 를 실행한 뒤 sqrt(4) 라고 모듈 이름 없이 그대로 호출하면 어떻게 될까?
}

@Choice(id: nameerror) {
NameError 가 나서 실행이 멈춘다. math.sqrt(4) 처럼 점으로 접근해야 한다.
}

@Choice(id: auto-resolve) {
파이썬이 알아서 math 모듈 안을 찾아 2.0 을 돌려준다.
}

@Choice(id: returns-none) {
오류는 나지 않지만 아무 일도 하지 않고 None 을 돌려준다.
}

@Explanation {
import math 는 math 라는 이름표만 가져올 뿐, 그 안의 함수들을 현재 코드에 직접 풀어 넣지 않는다. 그래서 sqrt 는 정의되지 않은 이름이고 NameError 가 난다. 반드시 math.sqrt(4) 처럼 모듈 이름을 점 앞에 붙여야 한다.
}
}

@Reflection(id: import-reflection) {
@Prompt(id: why-module-name) {
sqrt(4) 처럼 함수 이름만 쓰면 안 되고 math.sqrt(4) 처럼 모듈 이름을 붙여야 하는 이유를 자기 말로 설명해 보라.
}

@Prompt(id: seed-usage) {
random.seed 를 심으면 결과가 고정되는 데, 이런 기능이 테스트나 디버깅에서 왜 유용할지 생각해 보라.
}

@Prompt(id: find-more-modules) {
math 와 random 말고도 표준 라이브러리에는 여러 모듈이 있다. 어떤 기능이 모듈로 만들어져 있으면 좋겠는지 상상해 보라.
}
}
