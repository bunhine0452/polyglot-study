@Concept(id: var-let-print) {
Swift 에서 데이터를 담는 그릇은 두 가지다. var 로 선언하면 변수가 되어 나중에 다른 값을 다시 대입할 수 있고, let 으로 선언하면 상수가 되어 처음 넣은 값을 바꿀 수 없다. 타입을 따로 쓰지 않아도 초기값을 보고 타입이 자동으로 정해진다. 상수에 다시 대입하려 하면 프로그램이 실행되기도 전에 컴파일 오류가 난다. 값이 바뀌어야 하는 데이터만 var 로 쓰고, 나머지는 모두 let 으로 쓰는 것이 Swift 의 관습이다. print 함수는 값을 화면에 출력해 주며, 문자열 안에 \(값) 을 넣으면 그 자리에 값이 끼워져 나온다.
}

@Example(id: var-let-print-example, language: swift, expected: expected/swift-variables-and-constants.txt) {
score 와 level 은 var 변수라 값을 여러 번 바꿀 수 있고, maxScore 는 let 상수라 처음 넣은 100 이 그대로 유지된다. 실행 결과를 한 줄씩 따라가 보라.

```swift
var score = 10
print("초기 점수: \(score)")
score = score + 5
print("보너스 후: \(score)")

let maxScore = 100
print("최대 점수: \(maxScore)")

var level = 1
level = level + 1
level = level + 1
print("레벨: \(level)")
```
}

@Blank(id: var-let-blank, language: swift) {
바뀌지 않는 값에는 let, 나중에 더해질 값에는 var 를 골라 빈칸을 채워라.

```swift
___1___ gravity = 9.8
___2___ position = 0.0
position = position + 1.5
print("position: \(position)")
print("gravity: \(gravity)")
```

@Answer(slot: 1) {
`let`
}

@Answer(slot: 2) {
`var`
}
}

@Task(id: score-after-bonus-task, language: swift, starter: starters/swift-variables-and-constants.swift, tests: tests/swift-variables-and-constants.swift, solution: solutions/swift-variables-and-constants.swift) {
기본 점수 base 에 보너스 bonus 를 더한 최종 점수를 반환하는 함수 scoreAfterBonus(base:bonus:) 를 완성하라. 결과는 var 로 선언한 변수에 담아 계산해야 한다. base 나 bonus 가 0 이거나 음수여도 그대로 더하면 된다.

@Hint {
var total = base 로 변수를 하나 만들어 시작해 보라.
}

@Hint {
total 에 bonus 를 더하려면 total = total + bonus 처럼 자기 자신을 다시 대입하면 된다.
}

@Hint {
마지막에는 return total 로 결과를 돌려준다.
}
}

@Quiz(id: let-reassign-quiz, answer: compile-error) {
@Question {
let maxLives = 3 으로 상수를 만든 뒤 maxLives = 5 라고 코드를 작성하면 어떻게 되는가?
}

@Choice(id: compile-error) {
컴파일 오류가 발생해서 프로그램이 아예 빌드되지 않는다
}

@Choice(id: runtime-change) {
프로그램은 실행되고 maxLives 값이 5 로 바뀐다
}

@Choice(id: keep-old-value) {
5 를 무시하고 원래 값 3 이 그대로 유지된다
}

@Choice(id: warning-only) {
경고만 출력되고 프로그램은 정상적으로 실행된다
}

@Explanation {
let 으로 선언한 상수에 새 값을 대입하면 런타임까지 가지 못하고 컴파일 단계에서 오류가 난다. Swift 는 프로그램을 실행하기 전에 이런 실수를 잡아 준다.
}
}

@Reflection(id: var-let-reflection) {
@Prompt(id: choose-var) {
여러분이 만들 게임에서 플레이어의 점수, 게임 제목, 최대 목숨 중 어떤 것을 var 로 만들겠는가? 이유를 설명해 보라.
}

@Prompt(id: compile-error-value) {
상수에 다시 대입하면 실행 전에 오류가 난다. 이 성질이 실수를 막아 주는 상황을 하나 상상해서 적어 보라.
}
}
