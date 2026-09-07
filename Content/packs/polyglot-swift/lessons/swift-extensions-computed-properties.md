@Concept(id: extension-computed-property) {
extension 은 이미 존재하는 타입(Int, String, 내가 만든 struct 등)의 소스 코드를 고치지 않고도 새 메서드나 프로퍼티를 덧붙일 수 있는 문법이다. 이때 저장 값을 가지는 대신 다른 프로퍼티나 연산으로부터 값을 계산해 돌려주는 프로퍼티를 computed property 라고 부른다. computed property 는 var 로 선언하고 본문에 get 절을 두어 어떤 값을 반환할지 정의하며, 호출할 때마다 계산이 수행된다. extension 안에서 프로토콜을 채택하면 기존 타입에 새로운 능력을 나중에 붙일 수도 있다.
}

@Example(id: extension-example, language: swift, expected: expected/swift-extensions-computed-properties.txt) {
구조체 Point 와 Int, Double, enum 에 extension 으로 computed property 를 붙여서 활용해 본다.

```swift
struct Point {
    var x: Double
    var y: Double
}

extension Point {
    var distanceFromOrigin: Double {
        get {
            return (x * x + y * y).squareRoot()
        }
    }
}

extension Int {
    var squared: Int {
        return self * self
    }
}

extension Double {
    var isPositive: Bool {
        return self > 0
    }
}

enum Direction {
    case north
    case south
}

extension Direction: CustomStringConvertible {
    var description: String {
        switch self {
        case .north:
            return "북"
        case .south:
            return "남"
        }
    }
}

let p = Point(x: 3.0, y: 4.0)
print("원점까지 거리: \(p.distanceFromOrigin)")
print(7.squared)
print((-2.5).isPositive)
print(Direction.north)
print(Direction.south)
```
}

@Blank(id: extension-blank, language: swift) {
Temperature 구조체에 화씨 값을 계산해 주는 computed property 와, extension 으로 영하 여부를 판단하는 프로퍼티를 완성하라.

```swift
struct Temperature {
    var celsius: Double
    var fahrenheit: Double {
        ___1___ {
            return celsius * 9 / 5 + 32
        }
    }
}

extension Temperature {
    var isFreezing: Bool {
        return celsius ___2___ 0
    }
}

let t = Temperature(celsius: 37.5)
print(t.fahrenheit)
print(t.isFreezing)
```

@Answer(slot: 1) {
`get`
}

@Answer(slot: 2) {
`<=`
}
}

@Task(id: extension-task, language: swift, starter: starters/swift-extensions-computed-properties.swift, tests: tests/swift-extensions-computed-properties.swift, solution: solutions/swift-extensions-computed-properties.swift) {
Int 타입에 짝수 여부를 알려주는 computed property isEiven 이 아니라 isEven 과 제곱을 돌려주는 squared 를, String 타입에 공백으로 구분한 단어 수를 돌려주는 wordCount 를 extension 으로 구현하라. 세 프로퍼티 모두 computed property 로 정의해야 하고, 함수가 아니라 var 로 선언되어야 한다. 빈 문자열의 wordCount 는 0 이다.

@Hint {
computed property 는 var 로 선언하고 본문에서 return 으로 값을 돌려준다.
}

@Hint {
짝수 판정은 나머지 연산자 % 를 사용하면 된다. 0 도 짝수임에 유의하라.
}

@Hint {
split(separator: " ") 은 기본적으로 빈 조각을 제외하므로 여러 개의 연속 공백도 자연스럽게 처리된다.
}
}

@Quiz(id: extension-quiz, answer: computed-on-access) {
@Question {
computed property 에 대한 설명으로 옳은 것은 무엇인가?
}

@Choice(id: computed-on-access) {
computed property 는 접근할 때마다 get 본문을 실행해 값을 계산해 돌려준다.
}

@Choice(id: needs-stored-space) {
computed property 는 값을 저장하는 공간을 차지하므로 반드시 초기값을 지정해야 한다.
}

@Choice(id: extension-stored-property) {
extension 안에서는 저장 프로퍼티든 computed property 드 어떤 프로퍼티든 자유롭게 추가할 수 있다.
}

@Choice(id: let-computed) {
computed property 는 계산 결과가 변하지 않으므로 let 으로만 선언할 수 있다.
}

@Explanation {
computed property 는 값을 저장하지 않고 get 이 실행될 때마다 계산해서 돌려주므로 var 로 선언한다. 또한 extension 에서는 저장 프로퍼티를 추가할 수 없고 computed property 만 추가할 수 있다.
}
}

@Reflection(id: extension-reflection) {
@Prompt(id: when-extension) {
내가 만든 구조체에 기능을 추가할 때에도 extension 을 쓸 수 있는데, 구조체 본문에 직접 쓰는 것과 extension 으로 분리하는 것은 각각 어떤 상황에 유리할까?
}

@Prompt(id: computed-vs-method) {
계산된 값을 돌려주는 일을 computed property 로 할지 메서드로 할지 고민해 본 적이 있는가? 어떤 기준으로 나누면 좋을까?
}

@Prompt(id: protocol-conformance) {
extension 으로 프로토콜 채택을 나중에 붙이는 것은 내가 직접 만든 타입뿐 아니라 Int 나 String 같은 기본 타입에도 가능하다. 이 능력이 코드 재사용에 어떤 도움이 될까?
}
}
