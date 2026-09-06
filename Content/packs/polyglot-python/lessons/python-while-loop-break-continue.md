@Concept(id: concept-while-break-continue) {
`for`가 정해진 횟수만큼 도는 반복이었다면, `while`은 조건이 참인 동안 계속 도는 반복이다. 몇 번 반복할지 미리 알 수 없고, "조건이 만족되는 동안"이라는 기준으로 반복해야 할 때 쓴다. 예를 들어 "체력이 0보다 큰 동안 게임을 계속한다", "사용자가 올바른 비밀번호를 입력할 때까지 다시 묻는다" 같은 상황이다.

`while`의 모양은 `if`와 닮았다. `while 조건식:` 아래에 들여쓰기한 블록을 쓰면, 파이썬은 조건식을 검사하고 참이면 블록을 실행한 뒤 다시 조건식으로 돌아간다. 이 검사와 실행을 조건식이 거짓이 나올 때까지 되풀이한다. 조건식이 처음부터 거짓이면 블록은 한 번도 실행되지 않는다.

여기서 실수하기 쉬운 지점이 하나 있다. 조건식에서 쓰는 변수를 블록 안에서 갱신하지 않으면 조건식이 영원히 참인 채로 남아, 프로그램이 끝나지 않는 무한 루프에 빠진다. 예를 들어 `while count < 3:`처럼 `count`를 조건에 써 놓고 블록 안에서 `count += 1`을 빠뜨리면 `count`는 영원히 0에 머문다. `while`을 쓸 때는 "이 반복은 언제 조건이 거짓이 되는가"를 항상 확인해야 한다.

반복 흐름을 더 세밀하게 조종하는 두 키워드가 `break`와 `continue`다. `break`를 만나면 조건을 검사할 필요조차 없이 반복이 즉시 종료되고, 실행은 반복 블록 바로 다음 문장으로 넘어간다. 주로 "정답을 찾았으니 더 볼 필요 없다"처럼 반복을 일찍 끝내야 할 때 쓴다. `continue`를 만나면 현재 회차의 남은 코드를 건너뛰고 조건식 검사로 되돌아간다. 반복 전체를 끝내는 것이 아니라 이번 한 회차만 생략하는 것이다. 주로 "이 값은 예외니까 건너뛰자"처럼 특정 회차만 제외할 때 쓴다.

`while True:`처럼 조건을 항상 참으로 놓고, 안에서 `break`로 끝내는 패턴도 자주 쓰인다. "언제 끝날지 모르지만, 어떤 일이 생기면 그때 멈춘다"를 코드로 표현하는 방식이다. 다만 `continue`를 쓸 때는 주의할 점이 있다. 조건을 거짓으로 만들어 주는 갱신 코드가 `continue`보다 뒤에 있으면, `continue`가 그 갱신을 매번 건너뛰게 되어 무한 루프에 빠진다. 반복 변수 갱신은 `continue`보다 앞에 두거나, `continue` 경로에서도 갱신이 일어나도록 배치해야 한다.
}

@Example(id: example-while-break-continue, language: python, expected: expected/python-while-loop-break-continue.txt) {
코드를 한 줄씩 따라가 보세요. 첫 번째 반복은 `count`가 3이 될 때까지 돌고, 조건식 `count <= 3`이 거짓이 되는 순간 멈춥니다. 두 번째 반복은 조건이 항상 참인 `while True:`이므로, `break`가 실행되는 순간에만 끝납니다.

```python
# while: 조건이 참인 동안 반복한다
count = 1
while count <= 3:
    print(f"count={count}")
    count += 1

# continue로 짝수는 건너뛰고, break로 반복을 끝낸다
total = 0
num = 0
while True:
    num += 1
    if num % 2 == 0:
        continue
    if num > 9:
        break
    total += num

print(f"홀수 합={total}")
print("프로그램 종료")
```
}

@Blank(id: blank-while-break-continue, language: python) {
빈칸을 채워 10 이하의 홀수만 더하는 코드를 완성해 보세요. 짝수는 continue로 건너뛰고, 9까지 더했으면 반복을 끝내야 합니다.

```python
total = 0
n = 0
while ___1___:
    n += 1
    if n % 2 == ___2___:
        continue
    if n > 9:
        ___3___
    total += n
print(f"10 이하 홀수의 합: {total}")
```

@Answer(slot: 1) {
`True`
}

@Answer(slot: 2) {
`0`
}

@Answer(slot: 3) {
`break`
}
}

@Task(id: task-while-break-continue, language: python, starter: starters/python-while-loop-break-continue.py, tests: tests/python-while-loop-break-continue.py, solution: solutions/python-while-loop-break-continue.py) {
`sum_until_negative(numbers)` 함수를 완성하세요. 리스트를 앞에서부터 훑으면서 합계를 구하는데, **음수를 만나면 그 즉시 반복을 멈추고**(`break`), **0은 합계에 넣지 않고 건너뛰어야 합니다**(`continue`). 이번 레슨의 주제인 `while` 반복과 `break`, `continue`를 모두 사용해 보세요. 음수가 한 번도 없으면 리스트 전체의 합(0 제외)을, 리스트가 비어 있으면 0을 반환합니다.

@Hint {
반복 변수 `i`를 갱신하는 코드는 `continue`보다 앞에 두어야 무한 루프를 피할 수 있습니다.
}

@Hint {
음수를 만나면 그 뒤의 값은 전부 무시합니다. `break`의 위치를 어디에 둘지 생각해 보세요.
}
}

@Quiz(id: quiz-while-break-continue, answer: b) {
@Question {
`n = 0` 인 상태에서 `while True:` 안에 `n += 1` 이 있고, `n % 3 == 0` 이면 `break` 하는 코드다. 루프가 끝난 뒤 `print(n)` 은 무엇을 출력할까?
}

@Choice(id: a) {
1
}

@Choice(id: b) {
3
}

@Choice(id: c) {
값이 계속 커지다가 오류가 난다
}

@Choice(id: d) {
`break`가 실행되지 않아 `print`에 도달하지 못한다
}

@Explanation {
`n`은 1, 2로 증가하다가 3이 되는 순간 `n % 3 == 0`이 참이 되어 `break`로 반복을 빠져나옵니다. 반복이 정상적으로 끝났으므로 그 다음 문장인 `print(n)`이 실행되어 3이 출력됩니다.
}
}

@Reflection(id: reflection-while-break-continue) {
@Prompt(id: infinite-loop-guard) {
이번 레슨에서 무한 루프에 빠질 수 있는 상황을 두 가지 이상 떠올려 보고, 각 상황에서 `while` 코드의 어느 부분을 고치면 빠져나올 수 있을지 자기 말로 정리해 보세요. 조건식에서 쓰는 변수의 갱신 위치와 `continue`의 관계도 함께 다뤄 보면 좋습니다.
}

@Prompt(id: while-vs-for) {
지난 레슨에서 배운 `for` 반복 대신 `while`을 쓰는 것이 더 자연스러운 상황을 하나 상상해서 적어 보세요. 반복 횟수가 정해져 있지 않다는 점이 어떻게 드러나는 상황이면 충분합니다.
}
}
