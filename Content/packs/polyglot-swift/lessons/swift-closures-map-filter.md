@Concept(id: closure-map-filter) {
클로저는 이름 없는 함수로, 함수를 값처럼 변수에 담거나 다른 함수에 인자로 넘길 수 있게 해 준다. 기본 형태는 중괄호 안에 매개변수와 반환 타입을 쓰고 in 뒤에 본문을 적는 것이다. map 은 배열의 모든 요소를 클로저로 변환한 새 배열을 만들고, filter 는 조건식이 참인 요소만 골라 새 배열을 만든다. 타입을 추론할 수 있는 자리에서는 매개변수 이름 대신 $0 같은 축약 인자를 써서 클로저를 짧게 표현할 수 있다. $0 은 클로저의 첫 번째 매개변수를 뜻한다.
}

@Example(id: closure-basic-example, language: swift, expected: expected/swift-closures-map-filter.txt) {
클로저를 변수에 담아 호출하고, map 과 filter 에 축약 인자 클로저를 넘겨 새 배열을 만들어 출력한다.

```swift
let greet = { (name: String) -> String in
    return "안녕, \(name)!"
}
print(greet("지수"))

let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map { $0 * 2 }
print(doubled)

let squared = numbers.map { n in n * n }
print(squared)

let evens = numbers.filter { $0 % 2 == 0 }
print(evens)

let overTwo = numbers.filter { $0 > 2 }.map { "\($0)번" }
print(overTwo)
```
}

@Blank(id: blank-filter-map, language: swift) {
filter 로 짝수만 걸러낸 뒤 map 으로 두 배로 만들어 결과를 출력하는 코드다. 빈칸을 채워 완성하라.

```swift
let numbers = [1, 2, 3, 4]
let evens = numbers.___1___ { $0 % 2 == 0 }
let doubled = evens.___2___ { $0 * 2 }
print(doubled)
```

@Answer(slot: 1) {
`filter`
}

@Answer(slot: 2) {
`map`
}
}

@Task(id: doubled-evens-task, language: swift, starter: starters/swift-closures-map-filter.swift, tests: tests/swift-closures-map-filter.swift, solution: solutions/swift-closures-map-filter.swift) {
정수 배열을 받아 짝수만 골라 각각 두 배로 만든 새 배열을 반환하는 함수 doubledEvens 를 완성하라. filter 로 조건을 걸고 map 으로 변환하는 것을 권한다. 입력 순서를 유지해야 하고, 조건을 통과하는 요소가 없으면 빈 배열을 반환한다. 음수와 0 도 정수의 일부로 다루어야 한다.

@Hint {
filter 의 클로저는 Bool 을 반환해야 하고, 조건이 참인 요소만 남는다.
}

@Hint {
짝수 판정은 n % 2 == 0 으로 할 수 있다. 음수 짝수도 이 조건을 통과한다.
}

@Hint {
filter 와 map 을 이어 붙이면 한 문장으로 표현할 수 있다.
}
}

@Quiz(id: quiz-shorthand-arg, answer: first-shorthand-arg) {
@Question {
numbers.map { $0 * $0 } 에서 $0 은 무엇을 뜻하는가?
}

@Choice(id: first-shorthand-arg) {
클로저의 첫 번째(그리고 여기서 유일한) 매개변수를 뜻하는 축약 인자다.
}

@Choice(id: first-element-only) {
배열의 첫 번째 요소만 변환하고 나머지는 그대로 둔다는 뜻이다.
}

@Choice(id: captured-constant) {
클로저 밖에서 캡처한 상수나 변수를 가리키는 특별한 이름이다.
}

@Choice(id: map-only-syntax) {
map 에서만 쓸 수 있는 전용 문법이고 filter 에서 쓰면 컴파일 오류가 난다.
}

@Explanation {
$0 은 클로저의 첫 번째 매개변수를 가리키는 축약 인자다. 매개변수와 in 을 생략해도 타입 추론으로 같은 결과를 낸다. filter 의 조건식에서도 똑같이 쓸 수 있고, 배열 요소 순서나 캡처와는 무관하다.
}
}

@Reflection(id: reflection-closures) {
@Prompt(id: named-vs-shorthand) {
map { n in n * n } 과 map { $0 * $0 } 은 같은 결과를 낸다. 어떤 코드가 더 읽기 쉬운가, 본인의 기준을 예와 함께 설명해 보라.
}

@Prompt(id: map-vs-for-loop) {
for 반복문으로도 map 과 filter 의 결과를 만들 수 있다. 두 방식을 비교했을 때 클로저 방식이 좋은 점과 나쁜 점은 무엇이라고 생각하는가?
}

@Prompt(id: chained-call) {
filter 를 먼저 하고 map 을 나중에 하는 것과 순서를 바꾸면 결과가 달라질 수 있는가? 예를 들어 자기만의 예시 배열로 이유를 설명해 보라.
}
}
