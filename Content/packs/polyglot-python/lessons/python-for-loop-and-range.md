@Concept(id: concept) {
같은 코드를 여러 번 쓰는 대신, 파이썬에서는 `for` 문으로 반복을 시킵니다. 가장 기본한 형태는 `for 변수 in range(횟수):` 이고, 그 아래에 들여쓰기한 줄이 반복 횟수만큼 매번 실행됩니다. 콜론과 들여쓰기는 `if` 문에서와 똑같은 규칙입니다. 반복이 한 번 돌 때마다 `range()`가 만들어 낸 값이 순서대로 변수에 하나씩 들어가므로, 반복 안에서 그 변수를 읽으면 지금 몇 번째 차례인지 알 수 있습니다.

`range()`는 숫자 수열을 만드는 도구입니다. 인자를 하나만 쓰면 `range(3)`은 0, 1, 2를 만듭니다. 즉, 끝에 쓴 값 자체는 포함되지 않고 그 직전까지 만들므로, `range(3)`의 반복 횟수는 정확히 3번입니다. 인자를 세 개 쓰면 시작값과 끝값, 증가값을 정할 수 있습니다. `range(2, 11, 3)`은 2에서 시작해 3씩 늘어나되 11은 포함하지 않으므로 2, 5, 8을 만듭니다. 증가값을 음수로 쓰면 거꾸로 줄어드는 수열도 만들 수 있습니다.

반복문과 함께 자주 쓰는 패턴이 누적 변수입니다. 반복을 시작하기 전에 `total = 0`처럼 변수를 미리 만들어 두고, 반복 안에서 `total = total + n`으로 차곡차곡 더합니다. 반복이 끝난 뒤에는 이 변수에 최종 합계가 남아 있습니다. 주의할 점은 누적 변수를 반복 안에서 0으로 다시 만들면 안 된다는 것입니다. 그러면 매 차례마다 값이 지워져 마지막에 더한 것만 남습니다.

`for`는 숫자 수열뿐 아니라 문자열도 한 글자씩 훑을 수 있습니다. `for ch in "파이썬":`처럼 쓰면 첫 차례에 ch가 "파", 다음 차례에 "이", 마지막 차례에 "썬"을 받습니다. 문자열의 길이만큼 반복이 일어나므로, 글자 수를 세거나 특정 문자를 찾는 일을 이렇게 처리합니다.
}

@Example(id: example, language: python, expected: expected/python-for-loop-and-range.txt) {
실행 예제: range()의 인자 개수에 따라 반복 횟수와 값이 어떻게 달라지는지, 누적 변수로 합계를 만드는 과정, 문자열을 한 글자씩 순회하는 모습을 차례로 확인합니다.

```python
for i in range(3):
    print(f"{i}번째 반복")

print("---")

for n in range(2, 11, 3):
    print(n)

print("---")

total = 0
for n in range(1, 6):
    total = total + n
print(f"1부터 5까지 합계: {total}")

print("---")

for ch in "파이썬":
    print(ch)
```
}

@Blank(id: blank, language: python) {
빈칸을 채워 10부터 2까지 2씩 줄어드는 수를 모두 더하는 코드를 완성하세요. 실행하면 `합계: 30`이 출력되어야 합니다.

```python
total = 0
for n in range(___1___, ___2___, ___3___):
    total = total + n
print(f"합계: {total}")
```

@Answer(slot: 1) {
`10`
}

@Answer(slot: 2) {
`0`
}

@Answer(slot: 3) {
`-2`
}
}

@Task(id: task, language: python, starter: starters/python-for-loop-and-range.py, tests: tests/python-for-loop-and-range.py, solution: solutions/python-for-loop-and-range.py) {
문자열 word 안에서 문자 target이 몇 번 나오는지 세는 함수 `count_char(word, target)`을 완성하세요. for로 word를 한 글자씩 순회하고, if로 target과 같은지 비교한 뒤 누적 변수를 1씩 늘리세요. word가 빈 문자열이면 0을 반환해야 하고, 대소문자는 구분하지 않습니다(A와 a를 같은 문자로 셉니다).

@Hint {
for ch in word: 로 문자열을 한 글자씩 꺼내세요.
}

@Hint {
ch.lower()와 target.lower()를 비교하면 대소문자 차이를 무시하고 같은 문자인지 판단할 수 있습니다.
}

@Hint {
count를 늘리는 줄은 if 문 안에 들여써야 조건이 참일 때만 실행됩니다.
}
}

@Quiz(id: quiz, answer: b) {
@Question {
`range(1, 4)`가 만들어 내는 값은 무엇일까요?
}

@Choice(id: a) {
1, 2, 3, 4
}

@Choice(id: b) {
1, 2, 3
}

@Choice(id: c) {
0, 1, 2, 3
}

@Choice(id: d) {
1, 4
}

@Explanation {
range()는 끝에 쓴 값 자체는 포함하지 않고 그 직전까지 만듭니다. 따라서 range(1, 4)는 1에서 시작해 4가 되기 직전인 3까지, 세 개의 값을 만들어 냅니다.
}
}

@Reflection(id: reflection) {
@Prompt(id: reflection-prompt-1) {
range(1, n + 1)처럼 끝자리에 1을 더해 쓰는 이유를 본인의 말로 설명해 보세요. 그리고 1부터 100까지의 합을 구하려면 range에 어떤 값을 넣어야 하는지, 그때 반복이 몇 번 일어나는지도 함께 적어보세요.
}

@Prompt(id: reflection-prompt-2) {
누적 변수를 반복문 안에서 0으로 다시 만들면 어떤 일이 생기는지, 이전에 겪었거나 예상되는 상황을 곁들여 적어보세요.
}

@Prompt(id: reflection-prompt-3) {
문자열 순회는 숫자 range() 순회와 어떤 점이 같고 어떤 점이 다른가요? 반복 횟수가 정해지는 방식을 비교해 보세요.
}
}
