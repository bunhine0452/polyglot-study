@Concept(id: echo-basics) {
`print` 은 값을 표준 출력으로 내보낸다. 이 픽스처 팩은 `packtool validate` 의
실행 게이트가 실제로 코드를 태우는지 확인하기 위해 존재한다.
}

@Example(id: echo-run, language: python, expected: expected/fx-0001-echo-run.txt) {
아래 코드를 실행하면 한 줄이 나온다.

```python
print("hello fixture")
```
}

@Blank(id: echo-blank, language: python) {
리스트의 합을 출력하려 한다. 한 칸을 채워라.

```python
values = [2, 3]
print(___1___(values))
```

@Answer(slot: 1) {
`sum`
}
}

@Task(id: double, language: python, starter: starters/fx-0001-echo.py, tests: tests/fx-0001-echo.py, solution: solutions/fx-0001-echo.py) {
정수를 두 배로 돌려주는 `double(n)` 을 완성해라.

@Hint {
곱셈 연산자 하나면 된다.
}
}

@Quiz(id: echo-quiz, answer: stdout) {
@Question {
`print` 이 값을 내보내는 곳은 어디인가?
}

@Choice(id: stdout) {
표준 출력.
}

@Choice(id: stderr) {
표준 오류.
}

@Explanation {
`print` 은 기본적으로 `sys.stdout` 에 쓴다.
}
}

@Reflection(id: echo-reflect) {
@Prompt(id: streams) {
표준 출력과 표준 오류를 나누어 두면 무엇이 쉬워지는가?
}
}
