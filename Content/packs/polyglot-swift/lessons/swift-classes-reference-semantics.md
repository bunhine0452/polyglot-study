@Concept(id: class-reference-semantics) {
**클래스**는 `class` 키워드로 선언하는 참조 타입이다. 구조체는 대입할 때 값 자체가 복사되지만, 클래스 인스턴스를 대입하면 **같은 인스턴스를 가리키는 참조**만 복사된다. 그래서 한쪽에서 프로퍼티를 바꾸면 다른 쪽에서도 바뀐 값이 보인다. 두 참조가 정말 같은 인스턴스를 가리키는지는 `==` 가 아니라 식별 연산자 `===` 로 비교한다.
}

@Example(id: struct-copy-vs-class-reference, language: swift, expected: expected/swift-classes-reference-semantics.txt) {
같은 모양의 구조체와 클래스를 대입·수정하면서 값 복사와 참조 공유의 차이를 눈으로 확인한다.

```swift
struct PointStruct {
    var x: Int
    var y: Int
}

class PointClass {
    var x: Int
    var y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

var structA = PointStruct(x: 1, y: 2)
var structB = structA
structB.x = 100
print("struct a.x = \(structA.x), b.x = \(structB.x)")

let classA = PointClass(x: 1, y: 2)
let classB = classA
classB.x = 100
print("class a.x = \(classA.x), b.x = \(classB.x)")
print("a === b: \(classA === classB)")

let classC = PointClass(x: 1, y: 2)
print("a === c: \(classA === classC)")
```
}

@Blank(id: class-shared-reference-blank, language: swift) {
클래스 인스턴스를 다른 상수에 담아 프로퍼티를 바꾸면 원본에도 그 변화가 보인다. 빈칸을 채워 참조 공유와 식별 비교를 확인해 보자.

```swift
class Score {
    var value: Int

    init(value: Int) {
        self.value = value
    }
}

let original = ___1___(value: 10)
let alias = original
alias.value = 99
print("original.value = \(original.value)")
print("same instance: \(original ___2___ alias)")
```

@Answer(slot: 1) {
`Score`
}

@Answer(slot: 2) {
`===`
}
}

@Task(id: account-class-task, language: swift, starter: starters/swift-classes-reference-semantics.swift, tests: tests/swift-classes-reference-semantics.swift, solution: solutions/swift-classes-reference-semantics.swift) {
클래스 `Account` 를 완성하고, 두 참조가 같은 계좌인지 판별하는 함수 `sameAccount(_:_:)` 를 구현하라.

요구사항:
- `Account` 는 `var balance: Int` 저장 프로퍼티와 `init(balance: Int)` 를 가진다.
- `deposit(_ amount: Int)` 은 잔액을 `amount` 만큼 늘린다.
- `withdraw(_ amount: Int) -> Bool` 은 잔액이 부족하면 아무 것도 바꾸지 않고 `false` 를 반환하고, 충분하면 차감한 뒤 `true` 를 반환한다.
- `sameAccount(_ a: Account, _ b: Account) -> Bool` 은 두 매개변수가 같은 인스턴스를 가리키면 `true` 를 반환한다. 값이 같아도 인스턴스가 다르면 `false` 다.

@Hint {
`deposit` 은 `balance += amount` 한 줄이면 충분하다.
}

@Hint {
`withdraw` 는 `amount > balance` 인 경우를 먼저 거르고 나머지는 차감하면 된다.
}

@Hint {
`sameAccount` 는 값이 아니라 식별을 비교하는 연산자 하나로 끝난다.
}
}

@Quiz(id: class-assignment-quiz, answer: shared-reference) {
@Question {
`let a = SomeClass()` 로 만든 인스턴스를 `let b = a` 로 담은 뒤 `b.property = 10` 을 실행하면 어떤 일이 벌어질까?
}

@Choice(id: independent-copy) {
값이 복사되어 `a` 는 그대로고 `b` 만 바뀐다.
}

@Choice(id: shared-reference) {
`a` 와 `b` 가 같은 인스턴스를 가리켜 `a.property` 도 10 이 된다.
}

@Choice(id: compile-error) {
`let` 으로 선언했으므로 프로퍼티 수정이 컴파일 오류가 된다.
}

@Explanation {
클래스는 참조 타입이라 대입은 인스턴스가 아니라 참조를 복사한다. 두 상수는 같은 객체를 가리키고, `let` 은 상수 재배정을 막을 뿐 참조 타입 프로퍼티의 수정은 막지 않는다. 구조체라면 첫 번째 선택지처럼 동작했을 것이다.
}
}

@Reflection(id: class-reference-reflection) {
@Prompt(id: let-mutation-difference) {
구조체를 `let` 에 담으면 프로퍼티를 못 바꾸지만, 클래스를 `let` 에 담으면 바꿀 수 있다. 이유를 참조와 값의 관점에서 설명해 보라.
}

@Prompt(id: identity-vs-equality) {
`===` 로 비교해야 할 때와 `==` 로 충분할 때를 각각 하나씩 예를 들어 구분해 보라.
}

@Prompt(id: shared-mutation-risk) {
여러 곳에서 같은 클래스 인스턴스를 공유할 때 참조 공유가 버그로 이어질 만한 상황을 하나 상상해 서술해 보라.
}
}
