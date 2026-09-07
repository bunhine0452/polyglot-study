@Concept(id: struct-basics) {
struct 는 여러 값을 하나의 타입으로 묶어주는 선언이다. 구조체 안에 변수 선언처럼 **프로퍼티**를 두고, 함수처럼 **메서드**를 정의할 수 있다. Swift 는 프로퍼티 이름만 나열하면 자동으로 만들어 주는 **memberwise initializer** 를 제공해서 `Point(x: 3, y: 4)` 처럼 인스턴스를 바로 생성할 수 있다. struct 는 값 타입이라서 인스턴스를 다른 변수에 넘기면 복사되며, 한쪽의 프로퍼티를 바꿔도 다른 쪽은 영향을 받지 않는다.
}

@Example(id: struct-example, language: swift, expected: expected/swift-structs-properties-methods.txt) {
struct 로 점을 표현하는 타입을 만들고, memberwise initializer 로 인스턴스를 생성한 뒤 메서드 호출과 값 타입의 복사 동작을 print 로 확인한다.

```swift
struct Point {
    var x: Int
    var y: Int

    func distanceFromOrigin() -> Int {
        x * x + y * y
    }

    func moved(byX dx: Int, byY dy: Int) -> Point {
        Point(x: x + dx, y: y + dy)
    }
}

let a = Point(x: 3, y: 4)
print("a: (\(a.x), \(a.y))")
print("a.distanceFromOrigin: \(a.distanceFromOrigin())")

let b = a.moved(byX: 1, byY: 1)
print("b: (\(b.x), \(b.y))")
print("a after move: (\(a.x), \(a.y))")

var c = Point(x: 0, y: 0)
c.x = 10
print("c: (\(c.x), \(c.y))")
print("a unchanged: (\(a.x), \(a.y))")
```
}

@Blank(id: struct-blank, language: swift) {
struct 로 카운터 타입을 정의하고 memberwise initializer 로 인스턴스를 만들어 메서드를 호출하는 코드다. 빈칸을 채워 완성하라.

```swift
struct Counter {
    var count: Int

    func doubled() -> Int {
        return ___1___ * 2
    }
}

let counter = ___2___(count: 5)
print(counter.doubled())
```

@Answer(slot: 1) {
`count`
}

@Answer(slot: 2) {
`Counter`
}
}

@Task(id: rectangle-struct-task, language: swift, starter: starters/swift-structs-properties-methods.swift, tests: tests/swift-structs-properties-methods.swift, solution: solutions/swift-structs-properties-methods.swift) {
struct Rectangle 을 완성하라. 프로퍼티는 정수형 width 와 height 이고, memberwise initializer 는 그대로 사용한다. 메서드 area() 는 너비와 높이를 곱한 값을 반환하고, 메서드 scaled(by factor: Int) 는 가로세로가 factor 배인 새 Rectangle 인스턴스를 반환한다. 원본 인스턴스는 절대 바꾸지 말아야 한다.

@Hint {
area() 는 두 프로퍼티를 곱한 값을 return 하면 된다.
}

@Hint {
scaled(by:) 는 기존 인스턴스의 프로퍼티에 factor 를 곱한 값으로 새 인스턴스를 생성해 반환한다.
}

@Hint {
memberwise initializer 는 따로 작성하지 않아도 Rectangle(width:height:) 형태로 자동 제공된다.
}
}

@Quiz(id: struct-value-semantics-quiz, answer: one) {
@Question {
struct Point { var x: Int; var y: Int } 가 있을 때 다음 코드를 실행하면 출력은 무엇인가? var a = Point(x: 1, y: 2) / var b = a / b.x = 100 / print(a.x)
}

@Choice(id: one) {
1 을 출력한다. b 에 복사된 값만 바뀌었기 때문이다.
}

@Choice(id: hundred) {
100 을 출력한다. b 는 a 와 같은 인스턴스를 가리키므로 함께 바뀐다.
}

@Choice(id: compile-error) {
컴파일 에러가 난다. 프로퍼티를 나중에 바꿀 수 없다.
}

@Explanation {
struct 는 값 타입이라 변수에 대입하면 프로퍼티가 통째로 복사된 별개의 인스턴스가 생긴다. 따라서 b.x 를 바꿔도 a.x 는 원래 값 1 을 유지한다.
}
}

@Reflection(id: struct-reflection) {
@Prompt(id: memberwise) {
memberwise initializer 덕분에 프로퍼티 값을 넣는 init 코드를 직접 쓰지 않아도 되었다. 프로퍼티에 기본값이 있고 어떤 프로퍼티는 나중에 넣고 싶다면 자동으로 만들어지는 초기화 방식이 어떻게 달라질지 상상해 보라.
}

@Prompt(id: copy-vs-share) {
예제에서 scaled 나 moved 같은 메서드는 원본을 바꾸지 않고 새 인스턴스를 반환했다. 만약 원본 자체를 바꾸는 메서드를 쓴다면 구조체에서 무엇을 추가해야 할지, 그리고 값 타입의 복사 동작과 어떤 차이가 생길지 생각해 보라.
}

@Prompt(id: naming-types) {
지금까지 함수로 계산을 표현해 왔다. 어떤 상황에서는 함수 대신 struct 로 타입을 만드는 편이 코드를 읽기 좋게 만들지, 본인이 만들어 볼 만한 타입 하나를 예로 들어 설명해 보라.
}
}
