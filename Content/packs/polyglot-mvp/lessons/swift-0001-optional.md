@Concept(id: optional-basics) {
Swift 의 `Optional<Wrapped>` 은 "값이 없을 수 있음"을 **타입에 적어 둔 것**이다.
`String` 과 `String?` 은 서로 다른 타입이고, 컴파일러가 둘을 섞지 못하게 막는다.

값을 꺼내는 방법은 셋이다.

- `if let` / `guard let` — 있으면 이름에 묶어 쓰고, 없으면 다른 경로로 간다.
- `??` — 없을 때 쓸 기본값을 그 자리에 적는다.
- `!` — "여기는 절대 nil 이 아니다"라는 선언이고, 틀리면 즉시 크래시한다.

앞의 둘은 없는 경우를 코드에 적게 만들고, 마지막 하나는 적지 않아도 되게 해 준다.
그래서 학습 단계에서는 `!` 를 쓰지 않는 편이 낫다.
}

@Example(id: optional-run, language: swift, expected: expected/swift-0001-optional-run.txt) {
`Int(_:)` 는 실패할 수 있으므로 옵셔널을 돌려준다. `if let` 으로 두 단계를 한 번에 푼다.

```swift
let raw: String? = "42"
if let text = raw, let value = Int(text) {
    print("parsed \(value)")
} else {
    print("no value")
}
```
}

@Blank(id: optional-blank, language: swift) {
값이 없을 때 0 을 쓰도록 한 칸을 채워라.

```swift
let maybe: Int? = nil
let value = maybe ___1___ 0
print(value)
```

@Answer(slot: 1) {
`??`
}
}

@Task(id: safe-divide, language: swift, starter: starters/swift-0001-safe-divide.swift, tests: tests/swift-0001-safe-divide.swift, solution: solutions/swift-0001-safe-divide.swift) {
0 으로 나누면 `nil` 을, 아니면 몫을 돌려주는 `safeDivide(_:by:)` 를 완성해라.

정수 나눗셈이며 나머지는 버린다.

@Hint {
반환 타입이 `Int?` 라는 것은 "실패를 값으로 돌려준다"는 뜻이다. `guard` 로 먼저 걸러라.
}
}

@Quiz(id: optional-quiz, answer: force-unwrap-crashes) {
@Question {
`let value: Int? = nil` 일 때 `value!` 를 평가하면 무슨 일이 일어나는가?
}

@Choice(id: force-unwrap-crashes) {
런타임에 즉시 크래시한다.
}

@Choice(id: returns-zero) {
`Int` 의 기본값인 0 이 나온다.
}

@Choice(id: compile-error) {
컴파일이 되지 않는다.
}

@Explanation {
강제 언래핑은 컴파일러에게 "확인은 내가 했다"고 말하는 것이라 타입 검사를 통과한다.
그 약속이 틀리면 런타임에 `Unexpectedly found nil` 로 트랩이 걸린다. 기본값이 필요하면
`??` 를, 분기가 필요하면 `if let` 을 써라.
}
}

@Reflection(id: optional-reflect) {
@Prompt(id: api-design) {
직접 만든 함수가 실패할 수 있을 때 `Int?` 를 돌려주는 것과 `throws` 로 던지는 것 중
어느 쪽이 나은지, 호출자가 실패 이유를 알아야 하는지를 기준으로 판단해라.
}

@Prompt(id: chaining) {
`a?.b?.c` 처럼 옵셔널 체이닝이 길어질 때, 중간 어디가 nil 이었는지 알 수 없다는 점이
디버깅에 어떤 영향을 주는가?
}
}
