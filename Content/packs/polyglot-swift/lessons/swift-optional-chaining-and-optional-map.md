@Concept(id: optional-chaining-map-concept) {
옵셔널 체이닝은 옵셔널 뒤에 ? 를 붙여 안전하게 타고 들어가는 문법이다. 중간에 하나라도 nil 이면 전체가 nil 이 되고, 성공해도 결과는 항상 옵셔널로 감싸진다. 예를 들어 user.address?.city 의 타입은 String? 이다. Optional.map 은 옵셔널 안의 값을 클로저로 변환하는 메서드다. 값이 있으면 변환 결과를 다시 옵셔널로 감싸 주고, nil 이면 그대로 nil 을 돌려준다. 변환 결과 자체가 또 옵셔널이면 Optional.flatMap 을 써서 겹겹이 감싸는 것을 막는다. 마지막에 ?? 를 붙이면 체이닝이나 map 의 결과가 nil 일 때 기본값으로 바꿔치기할 수 있어, 옵셔널을 깔끔하게 일반 값으로 되돌릴 수 있다.
}

@Example(id: optional-chaining-map-example, language: swift, expected: expected/swift-optional-chaining-and-optional-map.txt) {
체이닝으로 중첩 프로퍼티에 접근하고, map 으로 옵셔널 내부를 변환하며, ?? 로 기본값을 붙이고, flatMap 으로 이중 옵셔널을 푸는 과정을 실행해 본다.

```swift
struct Address {
    var city: String?
}

struct User {
    var name: String?
    var address: Address?
}

let user = User(name: "지수", address: Address(city: "서울"))

print(user.address?.city)
print(user.address?.city ?? "주소 없음")
print(user.name?.count)
print(user.name.map { "이름: \($0)" } ?? "이름 없음")

let guest = User(name: nil, address: nil)
print(guest.address?.city ?? "주소 없음")
print(guest.name.map { $0.count } ?? 0)

let texts: [String?] = ["42", "hello", nil]
for text in texts {
    let n = text.flatMap { Int($0) }
    print(n.map { $0 * 2 } ?? -1)
}
```
}

@Blank(id: optional-chaining-map-blank, language: swift) {
주문의 메모 길이를 체이닝으로 꺼낸 뒤, 옵셔널에 map 을 적용해 두 배로 만들고, ?? 로 기본값을 붙여 문자열로 출력하는 코드다. 빈칸을 채워 완성하라.

```swift
struct Order {
    var note: String?
}

let order = Order(note: "급송")
let noteLength = order.note?.count
let doubled = noteLength.___1___ { $0 * 2 }
let display = "글자 수: \(doubled ___2___ 0)"
print(display)
```

@Answer(slot: 1) {
`map`
}

@Answer(slot: 2) {
`??`
}
}

@Task(id: optional-chaining-map-task, language: swift, starter: starters/swift-optional-chaining-and-optional-map.swift, tests: tests/swift-optional-chaining-and-optional-map.swift, solution: solutions/swift-optional-chaining-and-optional-map.swift) {
세 함수를 옵셔널 체이닝, map, flatMap 만으로 구현하라. bestFriendName(of:) 는 사람의 친구의 이름을 체이닝으로 꺼내고, 값이 없으면 "친구 없음" 을 돌려준다. doubledScore(*:) 는 옵셔널 점수에 map 을 적용해 두 배로 만들고, nil 이면 0 을 돌려준다. parseCount(*:) 는 옵셔널 문자열에 flatMap 과 Int 초기화기를 써서 숫자로 변환하고, 변환에 실패하거나 nil 이면 nil 을 돌려준다. 반복문이나 if 로 언래핑하지 말고 체이닝과 map, flatMap, ?? 를 활용하라. Person 은 친구를 참조할 수 있어야 하므로 class 로 선언되어 있다.

@Hint {
person?.friend?.name 처럼 ? 를 연달아 붙이면 중간에 nil 이 있어도 전체가 nil 이 된다.
}

@Hint {
Optional.map 은 nil 이 아닐 때만 클로저를 실행하고 결과를 다시 옵셔널로 감싼다.
}

@Hint {
문자열을 숫자로 바꾸는 Int($0) 의 결과는 이미 옵셔널이므로, 겹침을 막으려면 map 대신 flatMap 을 써라.
}
}

@Quiz(id: optional-chaining-map-quiz, answer: optional-wrapped) {
@Question {
user.address?.city 처럼 옵셔널 체이닝으로 String 타입 프로퍼티에 접근하면, 결과의 타입은 무엇일까?
}

@Choice(id: optional-wrapped) {
String? 이다 — 체인이 성공해도 결과는 항상 옵셔널로 감싸진다.
}

@Choice(id: plain-string) {
String 이다 — 체인이 성공하면 옵셔널이 벗겨진 값이 그대로 나온다.
}

@Choice(id: runtime-crash) {
String 이지만, 체인 중간에 nil 이 만나면 런타임 오류로 프로그램이 멈춘다.
}

@Explanation {
옵셔널 체이닝의 결과는 성공 여부와 관계없이 항상 옵셔널이다. 중간에 하나라도 nil 이면 전체가 nil 이 되고, 모두 성공해도 감싸진 상태로 돌아온다. 그래서 체이닝 뒤에 ?? 를 붙여 기본값을 붙이는 패턴이 자주 쓰인다.
}
}

@Reflection(id: optional-chaining-map-reflection) {
@Prompt(id: chaining-vs-binding) {
옵셔널 체이닝과 if let 바인딩은 둘 다 nil 을 안전하게 다룬다. 어떤 상황에서는 어느 쪽이 더 읽기 좋다고 생각하는지, 자신이 쓴 코드를 떠올리며 설명해 보라.
}

@Prompt(id: map-vs-flatmap) {
Optional 의 map 과 flatMap 의 차이를 자신의 말로 설명해 보라. 변환 클로저가 옵셔널을 돌려줄 때 map 을 쓰면 어떤 모양의 값이 되는가?
}

@Prompt(id: default-value-habit) {
?? 로 기본값을 붙이는 습관은 언제 도움이 되고, 언제 오히려 문제를 숨길 수 있을까? 기본값을 붙이면 안 되는 경우의 예를 하나 생각해 보라.
}
}
