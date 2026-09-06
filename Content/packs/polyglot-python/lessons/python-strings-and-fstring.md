@Concept(id: py-03-concept) {
문자열은 글자가 줄지어 있는 값이다. 파이썬에서는 이런 값을 str 이라고 부르고, 큰따옴표나 작은따옴표로 감싸서 만든다. 앞선 레슨에서 변수에 담고 print()로 출력하는 법을 배웠으니, 이번에는 문자열 자체를 자르고 다루는 법을 익힌다.

먼저 문자열의 길이는 len()으로 구한다. len("Python")은 6을 돌려준다. 각 글자에는 왼쪽부터 0, 1, 2, … 번호가 매겨져 있는데, 이 번호를 인덱스라고 부른다. 대괄호로 인덱스를 지정하면 그 자리의 글자 하나를 꺼낼 수 있다. word = "Python" 일 때 word[0]은 "P"이고, word[3]은 "h"이다. 0부터 세기 시작한다는 점이 처음에는 낯설지만, 아주 자주 쓰이는 규칙이니 꼭 기억하자. 음수 인덱스도 있는데, word[-1]은 맨 뒤 글자인 "n"을 꺼낸다.

인덱스가 글자 하나를 꺼낸다면, 슬라이싱은 범위를 잘라낸다. word[0:3]처럼 콜론 앞뒤로 시작 인덱스와 끝 인덱스를 쓴다. 이때 끝 인덱스 자리의 글자는 결과에 포함되지 않는다. word[0:3]은 인덱스 0, 1, 2의 글자인 "Pyt"이지, 인덱스 3까지 포함한 "Pyth"가 아니다. 시작이나 끝을 비워 두면 각각 맨 앞과 맨 뒤를 뜻한다. word[2:]는 "thon"이고, word[:2]는 "Py"이다.

f-string은 변수와 계산 결과를 문장에 끼워 넣는 도구다. 문자열 앞에 f를 붙이고, 중괄호 안에 변수 이름이나 수식을 적으면 실행할 때 그 자리에 값이 채워진다. name = "지우", age = 9 일 때 f"{name}은 {age}살"은 "지우은 9살"이 된다. 중괄호 안에는 word.upper()처럼 메서드 호출도, len(word) 같은 함수 호출도 그대로 쓸 수 있다. + 연산으로 문자열을 이어 붙이는 방식과 달리 숫자를 따로 문자로 바꿔 주지 않아도 되니, 문장을 조립할 때는 f-string이 기본 선택이 된다.

마지막으로 메서드를 본다. 메서드는 값에 점(.)을 찍어서 호출하는 함수다. word.upper()는 모든 글자를 대문자로 바꾼 새 문자열을 돌려주고, "  hi  ".strip()은 양쪽 끝의 공백을 제거한 새 문자열을 돌려준다. 주의할 점은 원본 문자열이 바뀌지 않는다는 것이다. 메서드가 돌려준 새 문자열을 변수에 다시 담아야 변형된 결과를 쓸 수 있다. name.strip() 만 호출하고 결과를 담지 않으면 name 은 여전히 공백이 붙은 원본 그대로다.

이 레슨에서 배운 도구들은 서로 조립된다. 슬라이싱으로 자르고, 메서드로 변형하고, f-string으로 문장에 끼워 넣는 흐름을 실행 예제에서 직접 확인해 보자.
}

@Example(id: py-03-example-1, language: python, expected: expected/python-strings-and-fstring.txt) {
인덱싱, 슬라이싱, f-string, 메서드 호출을 한 번에 확인하는 예제다. len()으로 길이를 구하고, word[0]과 word[-1]로 글자를 꺼내고, word[2:5]로 가운데를 잘라낸다. strip()의 결과를 clean에 다시 담는 이유도 주목하자. name 자체는 여전히 공백이 붙어 있고, 변형된 값은 새 변수에 들어간다.

```python
word = "Python"
print(len(word))
print(word[0])
print(word[-1])
print(word[2:5])

name = "  지우 "
clean = name.strip()
print(f"이름: {clean}, 길이: {len(clean)}")

print(f"{word.upper()}는 {len(word)}글자")
```
}

@Blank(id: py-03-blank-1, language: python) {
아래 코드를 완성해서 word의 길이, 앞 세 글자, 대문자 변형을 f-string과 함께 출력해 보자. ___1___ 부터 ___4___ 까지 순서대로 채우면 된다.

```python
word = "Python"
print(___1___(word))
print(word[0])
print(word[-1])
print(word[0:___2___])
shout = word.___3___()
print(f"{shout} / {___4___}글자")
```

@Answer(slot: 1) {
`len`
}

@Answer(slot: 2) {
`3`
}

@Answer(slot: 3) {
`upper`
}

@Answer(slot: 4) {
`len(word)`
}
}

@Task(id: py-03-task-1, language: python, starter: starters/python-strings-and-fstring.py, tests: tests/python-strings-and-fstring.py, solution: solutions/python-strings-and-fstring.py) {
입력 문자열의 양쪽 공백을 제거하고, 남은 글자를 모두 대문자로 바꿔서 "[단어] len=길이" 형태의 문자열로 만드는 함수 summary(text)를 완성하자. 빈 문자열이나 공백만 있는 문자열도 처리해야 한다.

@Hint {
text.strip() 은 양쪽 공백을 제거한 새 문자열을 돌려준다.
}

@Hint {
cleaned.upper() 처럼 메서드를 이어서 호출할 수도 있다.
}

@Hint {
f"[{...}] len={...}" 처럼 중괄호 안에 변수나 함수 호출을 넣을 수 있다.
}
}

@Quiz(id: py-03-quiz-1, answer: b) {
@Question {
s = "hello" 일 때, 슬라이싱 s[1:4] 의 값은 무엇일까?
}

@Choice(id: a) {
hell
}

@Choice(id: b) {
ell
}

@Choice(id: c) {
ello
}

@Choice(id: d) {
el
}

@Explanation {
슬라이싱 s[1:4]는 시작 인덱스 1부터 끝 인덱스 4 바로 앞(인덱스 3)까지를 잘라낸다. s[1]은 "e", s[2]는 "l", s[3]은 "l"이므로 결과는 "ell"이다. 끝 인덱스 자리의 글자는 포함되지 않는다.
}
}

@Reflection(id: py-03-reflection-1) {
@Prompt(id: py-03-reflection-1-1) {
예제에서 name.strip()의 결과를 clean이라는 새 변수에 담았다. 만약 그냥 name.strip()만 호출하고 결과를 담지 않았다면 name은 어떤 값일까? 문자열 메서드를 호출해도 원본이 바뀌지 않는다면, 변형된 결과를 계속 쓰려면 어떻게 해야 하는지 직접 실험해 보고 자기 말로 설명해 보자.
}

@Prompt(id: py-03-reflection-1-2) {
len(), 인덱싱, 슬라이싱은 각각 언제 쓰면 좋을까? 예를 들어 단어의 마지막 글자를 꺼낼 때와 단어의 앞 절반을 꺼낼 때 각각 어떤 도구를 골랐는지, 그 이유를 적어 보자.
}
}
