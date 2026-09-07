@Concept(id: for-in-while-basics) {
같은 일을 여러 번 하려면 반복문을 씁니다. **for-in 문**은 구간을 한 바퀴 돌면서 매번 값을 하나씩 꺼내 줍니다. 구간은 range 연산자로 만드는데, `1...5` 는 1부터 5까지의 닫힌 구간이라 5도 포함됩니다. **while 문**은 조건식이 참인 동안 몸통을 반복합니다. 보통 몸통 안에서 카운터를 직접 바꿔 주며, 조건이 false 가 되는 순간 반복이 끝납니다. 몸통 안에서 **continue** 를 만나면 남은 코드를 건너뛰고 다음 반복으로 넘어갑니다. 반복문 전체를 끝내는 것은 아니고 이번 바퀴만 건너뛴다는 점이 중요합니다. while 문에서 continue 로 카운터 갱신 줄을 건너뛰거나 갱신하는 줄을 빠뜨리면 조건이 영원히 참이라 무한 루프에 빠지니 주의하세요.
}

@Example(id: trace-loops-example, language: swift, expected: expected/swift-loops-for-while.txt) {
아래 예제는 for-in 문으로 1부터 5까지 출력하고, continue 로 3을 건너뛰며 합을 구하고, while 문으로 카운터를 줄여 가며 반복이 끝나는 순간을 확인한다.

```swift
for n in 1...5 {
    print("n=\(n)")
}

var sum = 0
for n in 1...5 {
    if n == 3 {
        continue
    }
    sum += n
}
print("sum=\(sum)")

var i = 3
while i > 0 {
    print("while i=\(i)")
    i -= 1
}
print("반복 끝")
```
}

@Blank(id: while-skip-blank, language: swift) {
while 문으로 1부터 5까지 세되, 3인 경우만 continue 로 건너뛰는 코드다. 카운터를 몸통 맨 앞에서 늘려 continue 가 증가를 건너뛰지 않게 했다. 빈칸을 채워 출력이 i=1, i=2, i=4, i=5, total=12 순서로 나오게 하라.

```swift
var total = ___1___
var i = ___2___
while i < 5 {
    i += 1
    if i == 3 {
        ___3___
    }
    print("i=\(i)")
    total += i
}
print("total=\(total)")
```

@Answer(slot: 1) {
`0`
}

@Answer(slot: 2) {
`0`
}

@Answer(slot: 3) {
`continue`
}
}

@Task(id: sum-skip-multiples-task, language: swift, starter: starters/swift-loops-for-while.swift, tests: tests/swift-loops-for-while.swift, solution: solutions/swift-loops-for-while.swift) {
두 함수를 구현하라. `sumSkipMultiplesForIn(from:to:step:)` 는 for-in 문과 continue 를 써서 from...to 구간의 정수를 대상으로 합을 구한다. step 이 양수이면 step 의 배수는 건너뛰고 나머지를 더하고, step 이 음수이면 규칙이 뒤집혀 배수가 아닌 수를 건너뛰고 배수만 더한다. `sumSkipMultiplesWhile(from:to:step:)` 는 같은 일을 while 문으로 한다. from 이 to 보다 크면 구간이 비어 있는 것이므로 0 을 돌려준다. step 이 0 인 경우는 입력으로 주어지지 않는다.

@Hint {
for-in 문에서는 if 로 건너뛸 대상인지 검사한 뒤 continue 로 이번 반복을 건너뛰면 된다.
}

@Hint {
while 문에서는 카운터 변수를 from 으로 두고 몸통 안에서 1 씩 늘려야 무한 루프에 빠지지 않는다.
}

@Hint {
step 이 양수이면 n % step == 0 인 배수를 건너뛰고, step 이 음수이면 검사가 뒤집혀 n % step != 0 인 수를 건너뛴다.
}
}

@Quiz(id: continue-behavior-quiz, answer: skip-current-iteration) {
@Question {
반복문 몸통 안에서 continue 를 만나면 어떤 일이 일어나는가?
}

@Choice(id: skip-current-iteration) {
이번 반복의 남은 코드를 건너뛰고 다음 반복으로 넘어간다.
}

@Choice(id: exit-whole-loop) {
반복문 전체를 즉시 종료하고 몸통 밖으로 나간다.
}

@Choice(id: restart-from-beginning) {
같은 값으로 이번 반복을 처음부터 다시 실행한다.
}

@Explanation {
continue 는 이번 바퀴만 건너뛰고 다음 값으로 넘어간다. 반복문 전체를 끝내는 것은 break 이고, 같은 값을 다시 실행하는 동작은 continue 에 없다.
}
}

@Reflection(id: loop-trace-reflection) {
@Prompt(id: while-counter-mistake) {
while 문에서 카운터를 갱신하는 줄을 빠뜨리거나 continue 가 갱신 줄을 건너뛰게 하면 어떤 일이 벌어지는지, 실제로 코드를 실행해 보기 전에 출력만으로 알 수 있는 방법이 있을까?
}

@Prompt(id: for-in-vs-while) {
같은 횟수를 반복할 때 for-in 문과 while 문 중 어느 쪽이 실수할 여지가 적다고 생각하는지, 이유와 함께 적어 보라.
}

@Prompt(id: continue-order) {
continue 를 만나면 이번 반복의 print 도 건너뛰었다. continue 아래에 카운터 갱신 같은 코드가 있으면 무엇이 달라지는지 예를 들어 설명해 보라.
}
}
