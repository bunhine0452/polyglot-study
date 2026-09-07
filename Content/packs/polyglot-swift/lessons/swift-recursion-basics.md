@Concept(id: recursion-basics) {
재귀는 함수가 자기 자신을 다시 호출하는 방식으로, 큰 문제를 같은 모양의 더 작은 문제로 쪼개서 푸는 기법이다. 재귀 함수는 반드시 두 부분으로 나뉜다. 더 이상 쪼개지 않고 바로 답을 돌려주는 **기저 사례(base case)**와, 자기 자신을 더 작은 입력으로 호출하는 **재귀 사례(recursive case)**다.

예를 들어 팩토리얼은 0! 이 1이라는 기저 사례와, n! = n × (n-1)! 이라는 재귀 사례로 정의된다. 호출이 거듭될수록 입력이 기저 사례에 가까워져야 하고, 결국 재귀 사례를 더 이상 타지 않고 멈춰야 한다.

기저 사례가 없거나 입력이 기저 사례로 다가가지 않으면 호출은 끝없이 쌓이고, 스택 한도를 넘어 프로그램이 비정상 종료된다. 재귀 함수를 쓸 때는 항상 "언제 멈추는가"를 먼저 정하는 습관이 중요하다.
}

@Example(id: factorial-recursion, language: swift, expected: expected/swift-recursion-basics.txt) {
기저 사례와 재귀 사례로 팩토리얼을 계산하는 예제다. 5! 은 5×4×3×2×1 이고, 기저 사례 덕분에 0! 도 안전하게 1이 나온다.

```swift
func factorial(_ n: Int) -> Int {
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1)
}

print(factorial(5))
print(factorial(0))
print(factorial(1))
```
}

@Blank(id: blank-factorial, language: swift) {
팩토리얼 재귀 함수의 빈칸을 채워 완성해 보자. 어느 조건에서 멈추는지가 핵심이다.

```swift
func factorial(_ n: Int) -> Int {
    if ___1___ {
        return 1
    }
    return n * ___2___(n - 1)
}

print(factorial(6))
```

@Answer(slot: 1) {
`n <= 1`
}

@Answer(slot: 2) {
`factorial`
}
}

@Task(id: task-recursion, language: swift, starter: starters/swift-recursion-basics.swift, tests: tests/swift-recursion-basics.swift, solution: solutions/swift-recursion-basics.swift) {
두 개의 재귀 함수를 구현한다. factorial 은 0 이상의 정수 n 을 받아 n! 을 돌려주고, 0! 은 1이다. power 는 밑 base 와 0 이상의 지수 exp 를 받아 base 의 exp 거듭제곱을 돌려주고, 지수가 0이면 1이다. 반복문을 쓰지 말고 반드시 재귀 호출로 작성해라.

@Hint {
기저 사례를 가장 먼저 확인하고, 조건을 만족하면 곧바로 값을 반환하세요.
}

@Hint {
factorial 의 재귀 사례는 n × factorial(n - 1) 모양입니다.
}

@Hint {
power 는 지수를 하나씩 줄이며 base 를 곱하고, 지수가 0이 되면 1을 반환하세요.
}
}

@Quiz(id: quiz-base-case, answer: grows-forever) {
@Question {
다음 설명 중, 재귀 호출이 멈추지 않는 함수의 동작은 무엇인가?
}

@Choice(id: stops-at-zero) {
n 이 0이 되면 0을 돌려주고, 그렇지 않으면 n 에 n-1 까지의 합을 더해 n 이 0에 다가간다.
}

@Choice(id: grows-forever) {
n 을 받을 때마다 n+1 을 넘겨 자기 자신을 호출하고, 멈추는 조건이 어디에도 없다.
}

@Choice(id: halves-input) {
n 이 1 이하가 되면 0을 돌려주고, 그렇지 않으면 n 을 2로 나눈 값으로 자기 자신을 호출한다.
}

@Choice(id: no-recursion) {
n 이 음수면 -1 을 돌려주고, 그 외에는 자기 자신을 호출하지 않고 n 을 그대로 돌려준다.
}

@Explanation {
입력이 계속 커지고 멈추는 조건이 없으면 재귀 호출이 끝없이 쌓여 스택 한도를 넘어 비정상 종료된다. 나머지 셋은 입력이 기저 사례 조건으로 반드시 다가가므로 안전하게 멈춘다.
}
}

@Reflection(id: reflection-recursion) {
@Prompt(id: trace-factorial) {
factorial(4) 를 재귀 호출하면 함수 호출이 어떤 순서로 쌓이고, 어떤 순서로 곱해져서 24가 되는지 손으로 따라가 보세요.
}

@Prompt(id: base-case-first) {
재귀 함수를 설계할 때 기저 사례를 먼저 정하는 것이 왜 안전한지, 기저 사례를 나중에 정하면 어떤 실수가 생길 수 있는지 생각해 보세요.
}

@Prompt(id: recursion-vs-loop) {
방금 작성한 factorial 을 while 반복문으로도 써 볼 수 있다면, 재귀로 쓴 것과 반복문으로 쓴 것 중 어느 쪽이 읽기 쉬웠는지 이유와 함께 적어보세요.
}
}
