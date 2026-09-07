@Concept(id: protocol-basics) {
프로토콜은 타입이 반드시 가져야 할 능력, 즉 메서드와 프로퍼티의 목록을 선언하는 약속입니다. 구조체나 열거형이 프로토콜을 채택하면 그 약속에 적힌 요구를 모두 구현해야 하며, 이를 채택(conformance)이라고 부릅니다. 프로토콜 자체는 구현을 갖지 않는 대신 타입처럼 사용할 수 있는데, 프로토콜 타입 변수나 배열에는 그 약속을 지킨 서로 다른 타입들을 함께 담을 수 있습니다. 이 덕분에 상속 없이도 공통 능력을 기준으로 코드를 묶어 다룰 수 있습니다.
}

@Example(id: protocol-example, language: swift, expected: expected/swift-protocols-and-conformance.txt) {
두 구조체가 같은 프로토콜을 채택해 각자 다른 방식으로 요구를 구현하고, 프로토콜 타입 배열에 함께 담아 순회하는 예제다.

```swift
protocol Describable {
    var description: String { get }
}

struct Book: Describable {
    let title: String
    var description: String {
        return "책: \(title)"
    }
}

struct Car: Describable {
    let model: String
    var description: String {
        return "차: \(model)"
    }
}

let items: [Describable] = [Book(title: "스위프트"), Car(model: "모닝")]
for item in items {
    print(item.description)
}

protocol SoundMaker {
    func makeSound() -> String
}

struct Cat: Describable, SoundMaker {
    var description: String {
        return "고양이"
    }
    func makeSound() -> String {
        return "야옹"
    }
}

let cat = Cat()
print(cat.description)
print(cat.makeSound())
```
}

@Blank(id: protocol-blank, language: swift) {
프로토콜 선언, 채택, 프로토콜 타입 배열을 완성해라.

```swift
protocol Greeter {
    func greet() -> String
}

struct Robot: ___1___ {
    func ___2___() -> String {
        return "안녕"
    }
}

let greeters: [___3___] = [Robot()]
for g in greeters {
    print(g.greet())
}
```

@Answer(slot: 1) {
`Greeter`
}

@Answer(slot: 2) {
`greet`
}

@Answer(slot: 3) {
`Greeter`
}
}

@Task(id: protocol-task, language: swift, starter: starters/swift-protocols-and-conformance.swift, tests: tests/swift-protocols-and-conformance.swift, solution: solutions/swift-protocols-and-conformance.swift) {
프로토콜 타입 배열을 받아 모든 도형의 넓이 합을 Double 로 돌려주는 함수 totalArea(of:) 를 구현해라. 배열이 비어 있으면 0.0 을 돌려준다.

@Hint {
빈 배열일 때를 먼저 생각해 초깃값을 정해라.
}

@Hint {
for-in 으로 배열을 순회하면서 각 요소의 area 프로퍼티를 더해라.
}

@Hint {
각 요소는 Shape 프로토콜 타입이므로 area 프로퍼티에 접근할 수 있다.
}
}

@Quiz(id: protocol-quiz, answer: protocol-type-array) {
@Question {
서로 다른 구조체 Book 과 Car 를 하나의 배열에 함께 담고 싶다. 두 구조체 모두 Describable 프로토콜을 채택했을 때 가장 알맞은 방법은 무엇인가?
}

@Choice(id: protocol-type-array) {
배열 타입을 [Describable] 로 선언하고 두 구조체 인스턴스를 담는다
}

@Choice(id: struct-name-array) {
배열 타입을 [Book] 로 선언하고 Car 도 거기에 넣는다
}

@Choice(id: separate-arrays) {
Book 배열과 Car 배열을 따로 만들어 서로 섞지 않는다
}

@Choice(id: copy-properties) {
Book 구조체 안에 Car 의 프로퍼티를 복사해서 같은 타입으로 만든다
}

@Explanation {
프로토콜은 타입처럼 쓸 수 있으므로 [Describable] 배열에는 그 약속을 지킨 서로 다른 타입을 모두 담을 수 있다. [Book] 에는 Book 이 아닌 타입이 담기지 않고, 배열을 나누거나 프로퍼티를 복사하면 공통 능력 기준의 묶음 처리라는 프로토콜의 장점이 사라진다.
}
}

@Reflection(id: protocol-reflection) {
@Prompt(id: why-protocol) {
상속 없이도 서로 다른 타입을 묶어 다룰 수 있다는 점이 실제 코드에서 어떤 상황에 유용할지 자신의 경험에 빗대어 설명해 보라.
}

@Prompt(id: requirement-missing) {
구조체가 프로토콜을 채택했는데 요구를 하나 구현하지 않으면 컴파일 오류가 난다. 이런 오류를 미리 잡아 주는 것이 개발자에게 어떤 이점인가?
}

@Prompt(id: protocol-vs-enum) {
지난 레슨의 열거형과 이번 레슨의 프로토콜 타입 배열을 비교해 보라. 각각 어떤 경우에 더 적합할지 생각해 보라.
}
}
