@Concept(id: generics-intro) {
제네릭은 타입을 매개변수로 받아서 하나의 코드로 여러 타입을 다루는 기능이다. 함수 이름 뒤에 <T> 를 붙이면 컴파일러가 호출 시점에 실제 타입을 결정하므로, Int 용과 String 용으로 함수를 복사해 두지 않아도 된다. 구조체·열거형·클래스도 같은 방식으로 제네릭 타입을 선언해 다양한 타입의 값을 담을 수 있다. 다만 T 가 어떤 능력을 갖췄는지 알려 주지 않으면 그 능력의 연산을 쓸 수 없으므로, == 로 값을 비교하려면 T: Equatable 처럼 제약을 걸어야 한다.
}

@Example(id: generics-example, language: swift, expected: expected/swift-generics-basics.txt) {
제네릭 함수와 제네릭 구조체, 그리고 Equatable 제약을 사용한 예제다.

```swift
func largest<T: Comparable>(_ a: T, _ b: T) -> T {
    return a > b ? a : b
}

struct Box<T> {
    let value: T
    func describe() -> String {
        return "Box(\(value))"
    }
}

func findIndex<T: Equatable>(of value: T, in items: [T]) -> Int? {
    for (index, item) in items.enumerated() {
        if item == value {
            return index
        }
    }
    return nil
}

print("largest=\(largest(3, 7))")
print("largest=\(largest("apple", "banana"))")
let intBox = Box(value: 42)
print(intBox.describe())
let stringBox = Box(value: "hi")
print(stringBox.describe())

if let idx = findIndex(of: 5, in: [1, 3, 5, 7]) {
    print("index=\(idx)")
}
if findIndex(of: 9, in: [1, 3, 5, 7]) == nil {
    print("missing")
}
```
}

@Blank(id: generics-blank, language: swift) {
배열 안에서 주어진 값과 같은 원소의 개수를 세는 함수다. 타입 매개변수에 제약을 걸고, 같은지 비교하는 연산자를 채워 완성해 보자.

```swift
func countMatches<T: ___1___>(_ value: T, in items: [T]) -> Int {
    var count = 0
    for item in items {
        if item ___2___ value {
            count += 1
        }
    }
    return count
}

print(countMatches(2, in: [1, 2, 2, 3]))
```

@Answer(slot: 1) {
`Equatable`
}

@Answer(slot: 2) {
`==`
}
}

@Task(id: generics-task, language: swift, starter: starters/swift-generics-basics.swift, tests: tests/swift-generics-basics.swift, solution: solutions/swift-generics-basics.swift) {
제네릭 함수 findIndex(of:in:) 와 제네릭 구조체 Pair 를 구현하라. findIndex 는 items 배열에서 value 와 같은 첫 번째 원소의 인덱스를 반환하고, 없으면 nil 을 반환한다. Pair 는 두 값을 담고, hasEqualParts() 는 두 값이 서로 같으면 true 를 반환한다. 두 타입 모두 Equatable 제약을 사용해야 비교 연산을 쓸 수 있다.

@Hint {
함수 이름 뒤에 <T: Equatable> 을 붙이면 T 끼리 == 로 비교할 수 있다.
}

@Hint {
배열을 for (index, item) in items.enumerated() 로 순회하면 인덱스와 원소를 함께 얻는다.
}

@Hint {
끝까지 찾지 못했으면 함수 마지막에서 nil 을 반환한다.
}
}

@Quiz(id: generics-quiz, answer: equatable-constraint) {
@Question {
제네릭 함수 안에서 두 값을 == 로 비교하려면 타입 매개변수에 어떤 제약이 필요한가?
}

@Choice(id: equatable-constraint) {
T: Equatable 처럼 Equatable 제약을 걸어야 한다.
}

@Choice(id: comparable-constraint) {
T: Comparable 처럼 Comparable 제약을 걸어야 한다.
}

@Choice(id: no-constraint) {
제약 없이도 모든 타입은 == 을 쓸 수 있으니 필요 없다.
}

@Explanation {
== 은 Equatable 프로토콜이 약속한 연산이므로 그 능력이 있다는 제약이 있어야 컴파일러가 허용한다. Comparable 은 < 나 > 같은 순서 비교를 위한 제약이고, 제약이 없는 T 는 == 을 쓸 수 없어 컴파일 오류가 난다.
}
}

@Reflection(id: generics-reflection) {
@Prompt(id: when-generic) {
여러분이 쓴 코드 중에서 타입만 달라서 복사해 둔 함수나 구조체가 있었다면 무엇이었고, 제네릭으로 바꾸면 어떻게 달라질까?
}

@Prompt(id: constraint-choice) {
findIndex 에는 Equatable 이면 충분한데, 어떤 함수에는 Comparable 이 필요할까? 두 제약의 차이를 자기 말로 설명해 보자.
}

@Prompt(id: generic-type) {
Pair<T> 처럼 제네릭 타입을 만들어 보니 구조체를 타입별로 따로 정의하는 것과 비교해 어떤 점이 편리했는가?
}
}
