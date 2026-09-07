@Concept(id: string-split-join-strip-replace-concept) {
문자열 메서드는 원본을 바꾸지 않고 가공된 새 문자열이나 리스트를 돌려준다. split()은 문자열을 구분자 기준으로 잘라 리스트를 만들고, join()은 반대로 문자열 리스트를 구분자를 사이에 넣어 하나로 합친다. strip()은 문자열 양 끝의 공백(또는 지정한 문자들)을 잘라내고, replace()는 문자열 안의 특정 부분을 다른 문자열로 바꿔준다. 이 네 가지를 조합하면 사용자 입력이나 파일에서 읽은 지저분한 텍스트를 원하는 모양으로 정리할 수 있다.
}

@Example(id: string-methods-example, language: python, expected: expected/python-string-methods-split-join.txt) {
네 가지 메서드를 한 번에 실행해 보면서 각각이 무엇을 돌려주는지 확인해 보자. replace() 결과는 대괄호로 감싸 출력한다 — strip() 과 달리 양 끝의 공백이 그대로 남아 있다는 것이 눈에 보인다.

```python
line = "  hello, world  "
print(line.strip())

csv = "a,b,c"
parts = csv.split(",")
print(parts)
print("-".join(parts))

print("[" + line.replace("l", "L") + "]")
print("one two  three".split())
```
}

@Blank(id: string-methods-blank, language: python) {
앞뒤 공백을 제거하고 단어로 잘라낸 뒤, 쉼표로 다시 이어 붙여 보자.

```python
text = "  apple banana  "
words = ___1___
joined = ___2___
print(joined)
```

@Answer(slot: 1) {
`text.strip().split()`
}

@Answer(slot: 2) {
`",".join(words)`
}
}

@Task(id: normalize-phone-task, language: python, starter: starters/python-string-methods-split-join.py, tests: tests/python-string-methods-split-join.py, solution: solutions/python-string-methods-split-join.py) {
전화번호 문자열을 정리하는 함수 normalize_phone(text) 를 완성하라. 문자열 양 끝의 공백을 제거하고, 하이픈(-)과 중간에 낀 공백을 모두 없애서 숫자만 이어 붙인 문자열을 돌려줘야 한다. 예를 들어 " 010 - 1234 " 는 "0101234" 가 된다. 빈 문자열이 들어오면 빈 문자열을 돌려준다.

@Hint {
strip() 으로 양 끝 공백을 먼저 제거한다.
}

@Hint {
replace() 는 바꿀 대상이 없으면 문자열을 그대로 돌려주므로, 하이픈이 없는 입력에도 안전하게 동작한다.
}

@Hint {
replace("-", "") 와 replace(" ", "") 를 이어서 호출하면 두 문자를 모두 제거할 수 있다.
}
}

@Quiz(id: join-direction-quiz, answer: separator-join) {
@Question {
리스트 words = ["a", "b", "c"] 의 원소를 쉼표로 이어 붙인 문자열 "a,b,c" 를 만들려고 한다. 올바른 코드는 무엇인가?
}

@Choice(id: separator-join) {
",".join(words)
}

@Choice(id: list-join) {
words.join(",")
}

@Choice(id: join-two-args) {
join(",", words)
}

@Choice(id: str-join-list) {
words.str.join(",")
}

@Explanation {
join() 은 이어 붙일 구분자 문자열이 호출하는 메서드이고, 합칠 리스트를 인자로 받는다. 리스트가 join() 을 호출하는 것(split() 처럼)이 아니라 구분자 문자열이 호출하는 것이므로 ",".join(words) 가 맞다.
}
}

@Reflection(id: string-methods-reflection) {
@Prompt(id: split-noarg-vs-space) {
split() 과 split(" ") 는 결과가 언제 달라질까? 공백이 여러 개인 문장으로 직접 실험해 보고 차이를 설명해 보자.
}

@Prompt(id: immutability) {
text.strip() 을 호출한 뒤 text 를 다시 출력하면 원래 공백이 그대로 남아 있다. 왜 그런지, 원래 값을 바꾸려면 어떻게 해야 하는지 생각해 보자.
}

@Prompt(id: pipeline) {
파일에서 읽은 "이름, 점수" 형태의 줄 여러 개에서 이름과 점수를 분리해 보려면 split, strip, join 중 어떤 것들을 어떤 순서로 쓰면 좋을까?
}
}
