@Concept(id: if-and-switch-basics) {
조건문은 프로그램이 상황에 따라 다른 길을 걷게 만드는 장치다. 비교 연산의 결과는 참 또는 거짓인 불 값이 되고, if 는 그 값이 참일 때만 본문을 실행한다. else if 와 else 를 붙이면 여러 갈래 중 정확히 하나만 골라 실행되는데, 위에서부터 차례로 조건을 검사하다가 처음으로 참이 된 분기에서 멈춘다. 값이 정해진 후보 중 하나인 경우에는 switch 가 더 읽기 쉽다. 각 case 옆에 값을 적어 두면 일치하는 case 의 문장만 실행되고, 어느 것에도 해당하지 않으면 default 가 실행된다.
}

@Example(id: weather-and-grade-example, language: swift, expected: expected/swift-conditionals-if-switch.txt) {
온도와 등급 값을 바꿔 가며 실행하면 어떤 분기가 도는지 바로 확인할 수 있다. 아래 코드는 if 체인 하나와 switch 하나를 차례로 돌리고 결과를 출력한다.

```swift
let temperature = 28

if temperature >= 30 {
    print("덥다")
} else if temperature >= 20 {
    print("선선하다")
} else {
    print("춥다")
}

let grade = "B"

switch grade {
case "A":
    print("우수")
case "B":
    print("양호")
default:
    print("노력 요망")
}
```
}

@Blank(id: fill-if-switch, language: swift) {
점수에 따라 등급을 분류하는 if 체인과, 코드 번호에 따라 문구를 고르는 switch 이다. 도려낸 자리에 알맞은 키워드와 식별자를 채워 넣어라.

```swift
let score = 85

___1___ score >= 90 {
    print("A")
} else if score >= 80 {
    print("B")
} ___2___ {
    print("F")
}

let code = 2
switch ___3___ {
___4___ 1:
    print("하나")
case 2:
    print("둘")
default:
    print("많음")
}
```

@Answer(slot: 1) {
`if`
}

@Answer(slot: 2) {
`else`
}

@Answer(slot: 3) {
`code`
}

@Answer(slot: 4) {
`case`
}
}

@Task(id: weekday-switch-task, language: swift, starter: starters/swift-conditionals-if-switch.swift, tests: tests/swift-conditionals-if-switch.swift, solution: solutions/swift-conditionals-if-switch.swift) {
숫자 요일을 한글 이름으로 바꾸는 함수 weekdayName 을 switch 문으로 완성하라. day 가 1이면 월, 2이면 화, 3이면 수, 4이면 목, 5이면 금, 6이면 토, 7이면 일을 돌려주고, 그 밖의 값(0 이나 음수, 8 이상)은 없는 요일을 돌려준다. 입출력: Int 하나를 받아 String 하나를 반환한다.

@Hint {
switch 뒤에는 검사할 값을 적고, 각 case 옆에는 비교할 값을 적는다.
}

@Hint {
1부터 7까지 일곱 개의 case 가 필요하다.
}

@Hint {
나머지 모든 값은 default 에서 없는 요일을 돌려주면 된다.
}
}

@Quiz(id: else-if-chain-quiz, answer: only-b) {
@Question {
점수가 85점일 때, 90점 이상이면 A, 80점 이상이면 B, 둘 다 아니면 C 를 출력하는 if 와 else if 와 else 로 이어진 코드를 실행하면 어떤 출력이 나오는가?
}

@Choice(id: both-a-and-b) {
A 와 B 가 둘 다 출력된다
}

@Choice(id: only-b) {
B 만 출력된다
}

@Choice(id: only-c) {
C 만 출력된다
}

@Explanation {
85 는 90 이상이 아니므로 첫 분기는 건너뛰고, 80 이상이므로 두 번째 분기가 실행된다. else if 체인은 처음 참이 된 분기 하나만 실행하고 나머지는 검사하지 않으므로 C 는 절대 출력되지 않는다.
}
}

@Reflection(id: branching-reflection) {
@Prompt(id: which-branch-first) {
if 체인에서 조건의 순서를 바꾸면 결과가 달라질 수 있다. 본인이 작성한 조건들 중 순서를 바꾸면 다른 분기가 도는 경우가 있는지 생각해 보라.
}

@Prompt(id: if-vs-switch) {
같은 분기 로직을 if 와 switch 두 가지로 작성해 보았을 때, 어떤 상황에서 어느 쪽이 더 읽기 쉬웠는지 본인의 기준을 말해 보라.
}

@Prompt(id: default-role) {
switch 에 default 가 없으면 어떤 값이 들어왔을 때 문제가 생길지, 본인이 만든 예시를 들어 설명해 보라.
}
}
