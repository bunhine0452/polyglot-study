@Concept(id: swift-enum-associated-values) {
enum 은 어떤 값이 가질 수 있는 경우의 수를 타입으로 한정하는 도구다. 구조체가 여러 속성을 묶는다면, enum 은 서로 다른 여러 상황 중 정확히 하나를 담는다. 예를 들어 결제는 현금일 수도, 카드일 수도, 포인트일 수도 있는데 이 셋을 enum case 로 나열하면 그 외의 값은 아예 만들어낼 수 없다.

연관 값(associated value)은 각 case 가 함께 가지는 데이터다. `case cash(amount: Int)` 처럼 선언하면 `cash` case 를 만들 때 Int 를 함께 넣어야 하고, case 마다 서로 다른 타입과 개수의 데이터를 붙일 수 있다.

연관 값을 꺼내 쓰려면 switch 의 패턴 매칭을 쓴다. `case .cash(let amount)` 처럼 쓰면 해당 case 의 연관 값이 `amount` 상수에 바인딩되어 분기 안에서 자유롭게 사용할 수 있다. enum 의 모든 case 를 switch 에서 다루면 컴파일러가 빠진 case 가 없는지 검사해 주기 때문에, 경우의 수가 추가되어도 컴파일 오류로 알려준다.
}

@Example(id: payment-describe-example, language: swift, expected: expected/swift-enums-associated-values.txt) {
결제 수단을 enum 으로 정의하고, 각 case 의 연관 값에 따라 다른 설명을 만들어 출력한다.

```swift
enum Payment {
    case cash(amount: Int)
    case card(number: String)
    case point(remaining: Int)
}

func describe(_ p: Payment) -> String {
    switch p {
    case .cash(let amount):
        return "현금 \(amount)원"
    case .card(let number):
        let last = String(number.suffix(4))
        return "카드 \(last)로 결제"
    case .point(let remaining):
        return "포인트 \(remaining)점 사용"
    }
}

print(describe(.cash(amount: 12000)))
print(describe(.card(number: "1234567890123456")))
print(describe(.point(remaining: 3000)))
```
}

@Blank(id: result-handle-blank, language: swift) {
작업 결과를 나타내는 enum 의 실패 case 에서 연관 값인 오류 코드를 바인딩해 꺼내 쓰는 코드를 완성하라.

```swift
enum Result {
    case success(message: String)
    case failure(code: Int)
}

func handle(_ r: Result) -> String {
    switch r {
    case .success(let message):
        return "성공: \(message)"
    case .failure(___1___):
        return "실패: 코드 ___2___"
    }
}
```

@Answer(slot: 1) {
`let code`
}

@Answer(slot: 2) {
`\(code)`
}
}

@Task(id: shape-area-task, language: swift, starter: starters/swift-enums-associated-values.swift, tests: tests/swift-enums-associated-values.swift, solution: solutions/swift-enums-associated-values.swift) {
도형 enum `Shape` 가 주어져 있다. 각 case 의 연관 값으로 면적을 계산해 반환하는 함수 `area(_:)` 를 완성하라. 원은 반지름, 정사각형은 한 변, 직사각형은 가로와 세로를 연관 값으로 받는다. 원의 면적은 `Double.pi` 를 사용해 계산하라. 입력이 `Shape` 이므로 nil 은 고려할 필요가 없다.

@Hint {
switch 로 세 개의 case 를 모두 다루고, 각 case 에서 연관 값을 let 으로 바인딩하라.
}

@Hint {
원의 면적 공식은 반지름 × 반지름 × 원주율이고, Swift 에서는 `Double.pi` 로 원주율을 쓸 수 있다.
}

@Hint {
직사각형 case 는 연관 값이 두 개다. `case .rectangle(let width, let height)` 처럼 한 번에 둘 다 바인딩할 수 있다.
}
}

@Quiz(id: associated-value-quiz, answer: case-let-binding) {
@Question {
`enum Shape { case circle(radius: Double) }` 처럼 연관 값을 가진 case 를 정의했을 때, switch 문에서 `radius` 값을 꺼내 쓰는 올바른 방법은 무엇인가?
}

@Choice(id: case-let-binding) {
`case .circle(let radius):` 처럼 switch 패턴에서 let 으로 바인딩해서 분기 안에서 사용한다.
}

@Choice(id: dot-property-access) {
`shape.radius` 처럼 프로퍼티 접근 문법으로 직접 읽어 온다.
}

@Choice(id: raw-value-style) {
`case circle = radius` 처럼 원시값(raw value) 문법으로 정의해 두면 자동으로 꺼낼 수 있다.
}

@Choice(id: optional-unwrap) {
`if let radius = shape.circle` 처럼 옵셔널 바인딩으로 꺼낸다.
}

@Explanation {
연관 값은 프로퍼티가 아니라 case 에 묶인 데이터라서 패턴 매칭으로만 꺼낼 수 있다. switch 의 `case .circle(let radius)` 처럼 바인딩하는 것이 정답이며, 점 문법 접근·원시값·옵셔널 바인딩은 연관 값에 적용되지 않는다.
}
}

@Reflection(id: enum-associated-reflection) {
@Prompt(id: when-enum-vs-struct) {
여러 가지 데이터를 담아야 할 때 구조체를 쓸 수도 있고 연관 값이 있는 enum 을 쓸 수도 있다. 두 가지가 각각 어느 상황에 어울리는지, 본인이 만들어 볼 만한 타입을 예로 들어 설명해 보라.
}

@Prompt(id: compiler-case-check) {
enum 을 switch 로 다룰 때 새로운 case 를 추가하면 컴파일 오류가 난다. 이 특성이 오히려 번거롭다고 느껴질 수 있는 상황과, 그래도 유용하다고 생각하는 이유를 적어 보라.
}
}
