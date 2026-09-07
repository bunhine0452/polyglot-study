@Concept(id: optional-if-let) {
**옵셔널**은 값이 있거나(nil) 없거나(nil) 둘 중 하나인 값을 담는 타입입니다. 타입 뒤에 물음표를 붙여 `Int?`, `String?` 처럼 쓰고, 값이 없음을 `nil` 로 표현합니다. 옵셔널은 겉보기에 일반 값처럼 생겼지만 실제로는 포장지가 씌워진 값이라, 그대로 일반 값처럼 쓰면 컴파일 오류가 납니다. **if let** 바인딩은 포장지를 안전하게 열어 값이 있을 때만 그 값을 임시 상수에 꺼내 쓰게 해 주며, 값이 없으면 else 쪽 분기가 실행됩니다. 딕셔너리에서 존재하지 않는 키로 조회하면 오류가 나는 대신 `nil` 을 돌려주므로, 조회 결과는 언제나 옵셔널입니다.
}

@Example(id: optional-print-demo, language: swift, expected: expected/swift-optionals-and-nil.txt) {
옵셔널에 값을 넣거나 nil 을 넣어 print 로 찍어보고, 딕셔너리 조회 결과를 if let 으로 안전하게 꺼내 써 봅니다.

```swift
var score: Int? = 90
print(score)
score = nil
print(score)

let ages = ["철수": 12, "영희": 11]
let minsu = ages["민수"]
print(minsu)

if let age = ages["철수"] {
    print("철수는 \(age)살")
} else {
    print("철수를 모릅니다")
}

if let age = ages["민수"] {
    print("민수는 \(age)살")
} else {
    print("민수를 모릅니다")
}
```
}

@Blank(id: optional-blank, language: swift) {
딕셔너리에서 키로 값을 조회한 뒤, if let 으로 값이 있을 때만 꺼내 쓰는 코드를 완성해 봅시다.

```swift
let ages = ["kim": 20, "lee": 25]
let result = ages[___1___]
if ___2___ age = result {
    print("kim의 나이는 \(age)살")
} else {
    print("kim을 모릅니다")
}
```

@Answer(slot: 1) {
`"kim"`
}

@Answer(slot: 2) {
`let`
}
}

@Task(id: optional-lookup-task, language: swift, starter: starters/swift-optionals-and-nil.swift, tests: tests/swift-optionals-and-nil.swift, solution: solutions/swift-optionals-and-nil.swift) {
딕셔너리와 이름을 받아, 그 이름의 나이를 찾아 문자열로 돌려주는 함수 `lookupAge(_ name:)` 를 완성하세요. 값이 있으면 `"이름: 나이살"` 형태로, 값이 없으면 `"이름: 나이를 모릅니다"` 를 반환합니다. 반드시 if let 바인딩을 사용하세요.

@Hint {
딕셔너리에 없는 키로 조회하면 nil 이 나옵니다 — 이것이 옵셔널인 이유입니다.
}

@Hint {
if let age = ages[name] 형태로 쓰면 age 는 괄호 안에서 일반 Int 로 쓸 수 있습니다.
}

@Hint {
값이 0 이어도 nil 이 아니라 정상적인 값입니다 — if let 은 0 을 값으로 취급합니다.
}
}

@Quiz(id: optional-quiz, answer: compile-error) {
@Question {
`var count: Int? = 3` 일 때 `count + 1` 처럼 옵셔널을 일반 Int 처럼 바로 더하려 하면 어떻게 될까요?
}

@Choice(id: compile-error) {
컴파일 오류가 난다 — 옵셔널은 포장된 값이라 바로 산술에 쓸 수 없다
}

@Choice(id: treats-as-nil) {
count 가 nil 로 취급되어 결과가 nil 이 된다
}

@Choice(id: auto-unwrap) {
Swift 가 자동으로 언래핑해 4 로 계산된다
}

@Choice(id: optional-result) {
Optional(4) 가 되어 정상적으로 더해진다
}

@Explanation {
옵셔널은 값이 없을 수 있는 포장지라서 일반 Int 가 필요한 자리에 그대로 쓸 수 없고 컴파일 오류가 납니다. if let 바인딩으로 값을 안전하게 꺼낸 뒤에야 일반 값처럼 쓸 수 있습니다.
}
}

@Reflection(id: optional-reflection) {
@Prompt(id: why-optional) {
딕셔너리 조회 결과가 옵셔널인 이유를, 옵셔널이 없었다면 어떤 문제가 생겼을지 상상하며 설명해 보세요.
}

@Prompt(id: nil-vs-zero) {
값이 0 인 것과 값이 nil 인 것은 어떻게 다른가요? if let 바인딩에서 두 경우가 각각 어떻게 처리되는지 적어 보세요.
}

@Prompt(id: print-optional) {
print 로 옵셔널을 찍으면 Optional(3) 처럼 표시되는 이유는 무엇일까요? 포장지라는 비유와 연결해 설명해 보세요.
}
}
