@Concept(id: fstring-basics) {
파이썬의 f-string 은 문자열 리터럴 앞에 `f` 를 붙이고, 중괄호 안에 식을 그대로 쓰는 서식 문법이다.

`str.format()` 이나 `%` 서식과 달리 값이 **쓰이는 자리에 그대로** 보인다. 인자 순서가
어긋나는 실수가 구조적으로 생기지 않고, 읽는 사람이 결과 문자열을 눈으로 조립할 수 있다.

중괄호 안에는 이름뿐 아니라 임의의 식이 들어간다 — `f"{a + b}"` 도 유효하다.
}

@Example(id: fstring-run, language: python, expected: expected/py-0001-fstring-run.txt) {
아래 코드를 실행해 f-string 이 값을 어떻게 끼워 넣는지 확인한다.

```python
name = "polyglot"
count = 3
print(f"{name} has {count} tracks")
```
}

@Blank(id: fstring-blank, language: python) {
리스트의 합을 구해 f-string 으로 출력하려 한다. 두 칸을 채워라.

```python
values = [1, 2, 3]
total = ___1___(values)
print(f"total={___2___}")
```

@Answer(slot: 1) {
`sum`
}

@Answer(slot: 2) {
`total`
}
}

@Task(id: initials, language: python, starter: starters/py-0001-initials.py, tests: tests/py-0001-initials.py, solution: solutions/py-0001-initials.py) {
공백으로 나뉜 이름을 받아 각 단어의 첫 글자를 대문자로 이어 붙인 이니셜을 돌려주는
`initials(full_name)` 를 완성해라.

빈 문자열이 들어오면 빈 문자열을 돌려준다.

@Hint {
`str.split()` 은 인자 없이 부르면 연속된 공백을 하나로 묶어 처리한다.
}

@Hint {
문자열을 이어 붙일 때는 `"".join(...)` 이 반복 `+=` 보다 빠르고 읽기 쉽다.
}
}

@Quiz(id: fstring-quiz, answer: repr-conversion) {
@Question {
f-string 안에서 `!r` 변환 플래그는 무엇을 하는가?
}

@Choice(id: repr-conversion) {
값을 `repr()` 로 변환해 끼워 넣는다.
}

@Choice(id: rounding) {
소수점 이하를 반올림한다.
}

@Choice(id: raw-string) {
문자열을 raw 문자열로 만든다.
}

@Explanation {
`f"{value!r}"` 은 `repr(value)` 의 결과를 넣는다. 디버깅 출력에서 따옴표와 이스케이프를
그대로 보고 싶을 때 쓴다. 반올림은 `:.2f` 같은 **서식 명세**가 하는 일이고, raw 문자열은
`rf"…"` 접두사가 하는 일이다.
}
}

@Reflection(id: fstring-reflect) {
@Prompt(id: readability) {
같은 출력을 `%` 서식과 `str.format()` 으로도 써 보고, 셋 중 어느 쪽이 여섯 달 뒤의
자신에게 가장 잘 읽힐지 판단해라.
}

@Prompt(id: injection) {
사용자 입력을 f-string 에 그대로 넣어 SQL 문을 만들면 왜 위험한가? 이 레슨의 문법과
파라미터 바인딩의 차이를 한 문장으로 정리해라.
}
}
