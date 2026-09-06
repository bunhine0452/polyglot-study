@Concept(id: py-08-concept) {
같은 계산을 여러 곳에서 반복해서 쓰다 보면 코드가 길어지고, 고칠 때마다 여러 군데를 찾아다녀야 한다. 함수는 이런 코드 묶음에 이름을 붙여 두었다가 필요할 때마다 이름으로 불러 쓰는 장치다.

함수는 def 키워드로 정의한다. def 함수이름(매개변수): 형태로 첫 줄을 쓰고, 그 아래 들여쓰기한 블록에 함수가 할 일을 적는다. 매개변수는 함수가 호출될 때 밖에서 받아올 값을 담는 그릇이다. def add(a, b): 로 정의한 함수를 add(3, 5) 처럼 호출하면 a에는 3, b에는 5가 들어가고, 이때 넘겨주는 3과 5를 인자라고 부른다. 호출하는 쪽에서 값을 넣어주지 않아도 되는 매개변수를 만들려면 def introduce(name, age=10): 처럼 매개변수에 기본값을 적어 둔다. 이 함수는 introduce("하늘", 12) 처럼 두 값을 모두 넘길 수도 있고, introduce("하늘") 처럼 age를 생략할 수도 있으며, 생략하면 기본값 10이 사용된다.

함수가 계산한 결과를 밖으로 내보내는 길이 return이다. return 뒤에 적은 값이 호출한 자리로 돌아가서, total = add(3, 5) 처럼 변수에 담거나 print(add(3, 5)) 처럼 바로 쓸 수 있다. return은 함수를 즉시 끝낸다는 뜻도 있어서, return이 실행되면 그 아래에 남은 코드는 돌지 않는다.

반면 return이 없는 함수는 값을 돌려주지 않는다. 화면에 출력만 하는 함수가 대표적이다. 이런 함수를 호출해서 변수에 담으면 아무 값도 담기지 않은 것이 아니라, '값이 없다'는 뜻의 None이 담긴다. print만 하는 함수와 return으로 값을 돌려주는 함수의 차이는 호출 결과를 변수에 담아 출력해 보면 확실히 드러난다. 돌려주는 함수는 그 결과를 다시 다른 계산에 쓸 수 있지만, 출력만 하는 함수는 화면에 보여줬을 뿐 값을 남기지 못한다.
}

@Example(id: py-08-example, language: python, expected: expected/python-functions-def-return.txt) {
add는 return으로 값을 돌려주는 함수고, greet는 print만 하고 돌려주는 값이 없는 함수다. greet의 호출 결과를 변수 value에 담아 출력하면 None이 나오는 것을 확인하라. introduce는 age 매개변수에 기본값 10을 줬으므로 인자를 생략해도 동작한다.

```python
def add(a, b):
    total = a + b
    return total

result = add(3, 5)
print(result)
print(add(10, 20))

def greet(name):
    print(f"안녕, {name}!")

value = greet("철수")
print(value)

def introduce(name, age=10):
    return f"{name}: {age}살"

print(introduce("민지", 12))
print(introduce("하늘"))
```
}

@Blank(id: py-08-blank, language: python) {
multiply 함수는 계산 결과를 돌려줘야 하고, welcome 함수는 기본값 매개변수의 이름과 호출 시 넘기는 인자가 빠져 있다. 빈칸을 채워 프로그램을 완성하라.

```python
def multiply(a, b):
    result = a * b
    ___1___ result

def welcome(___2___="친구"):
    return f"{name}님, 어서 오세요!"

print(multiply(6, 7))
print(welcome())
print(welcome(___3___))
print(welcome())
```

@Answer(slot: 1) {
`return`
}

@Answer(slot: 2) {
`name`
}

@Answer(slot: 3) {
`"지훈"`
}
}

@Task(id: py-08-task, language: python, starter: starters/python-functions-def-return.py, tests: tests/python-functions-def-return.py, solution: solutions/python-functions-def-return.py) {
놀이공원 매표 함수 ticket_price 를 완성하라. 매개변수 age에는 나이, base에는 기본 요금이 들어오고 base에는 기본값 12000이 주어진다. 규칙은 다음과 같다. 8살 미만이면 base의 절반인 base // 2 를 돌려주고, 65살 이상이면 base에서 2000을 뺀 값을 돌려주며, 그 외에는 base를 그대로 돌려준다. 값을 계산해서 return 으로 돌려주어야 하고, 함수 안에서 print 를 하면 안 된다.

@Hint {
if 와 elif 로 나이 구간을 나누고, 각 구간마다 return 문을 하나씩 두면 된다.
}

@Hint {
8살 미만의 절반 가격은 나눗셈 연산자를 써서 base // 2 로 구한다.
}

@Hint {
age가 8일 때는 '8살 미만'이 아니므로 정가 base를 그대로 돌려주어야 한다.
}
}

@Quiz(id: py-08-quiz, answer: c) {
@Question {
다음 코드를 실행하면 화면에 무엇이 출력될까?

def f(x):
    print(x * 2)

result = f(3)
print(result)
}

@Choice(id: a) {
6
}

@Choice(id: b) {
None
}

@Choice(id: c) {
6 과 None이 각 줄에 하나씩
}

@Choice(id: d) {
6 이 두 번
}

@Explanation {
f(3)을 실행하는 동안 함수 안의 print가 먼저 6을 출력한다. 그러나 f에는 return이 없으므로 호출 결과는 None이고, 밖의 print(result)가 None을 출력한다.
}
}

@Reflection(id: py-08-reflection) {
@Prompt(id: py-08-reflection-1) {
print로 화면에 보여주는 함수와 return으로 값을 돌려주는 함수는 결과물이 남는 곳이 다르다. 여러 숫자의 합을 구해 돌려주는 함수를 예로 들어, return이 없으면 그 합을 다음 계산에 왜 쓸 수 없는지 자기 말로 설명해 보라.
}

@Prompt(id: py-08-reflection-2) {
기본값 매개변수를 두면 호출하는 쪽에서 생략할 수 있는 인자가 생긴다. 자신이 만들어 본 함수 중에서 어떤 매개변수에 기본값을 주면 호출하기 편해질지 하나 떠올려 적어 보라.
}
}
