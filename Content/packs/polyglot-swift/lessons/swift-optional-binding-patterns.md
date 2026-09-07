@Concept(id: optional-binding-patterns) {
옵셔널에 담긴 nil 가능성을 다루는 대표적인 방법은 세 가지다. guard let 은 nil 이면 함수를 즉시 종료(early exit)하고, nil 이 아니면 언래핑된 상수를 그 이후 코드 전체에서 쓸 수 있게 해 준다. nil 병합 연산자 ?? 는 옵셔널이 nil 이면 오른쪽의 대체값을 골라 주는 한 줄 짜리 표현식이다. 강제 언래핑 ! 은 컴파일러에게 무조건 값을 꺼내겠다고 선언하는 것이고, 값이 nil 이면 프로그램이 실행 중에 중단되므로 값이 반드시 있다는 것이 보장될 때만 써야 한다.
}

@Example(id: guard-let-nil-coalescing-example, language: swift, expected: expected/swift-optional-binding-patterns.txt) {
같은 딕셔너리 조회를 guard let, ??, 강제 언래핑 세 가지 방식으로 처리하고 결과를 출력한다. 없는 키를 조회하면 nil 이 나오고, 각 패턴이 그 nil 을 어떻게 대응하는지 비교한다.

```swift
let scores = ["kim": 90, "lee": 75]

func findScore(_ name: String) -> Int {
    guard let score = scores[name] else {
        return 0
    }
    return score
}

let withGuard = findScore("kim")
let missingGuard = findScore("park")
print("kim: \(withGuard)")
print("park: \(missingGuard)")

let leeCoalesced = scores["lee"] ?? 0
let parkCoalesced = scores["park"] ?? 0
print("lee: \(leeCoalesced)")
print("park: \(parkCoalesced)")

let forced = scores["kim"]!
print("kim: \(forced)")
```
}

@Blank(id: optional-binding-blank, language: swift) {
guard let 으로 nil 을 걸러내고, ?? 로 대체값을 고르는 코드의 빈칸을 채워라.

```swift
let ages = ["kim": 20]

let kimAge = ages["kim"] ___1___ 0
let choiAge = ages["choi"] ___2___ -1

var total = 0
guard let age = ages["kim"] else {
    ___3___
}
total = age
print("total: \(total)")
```

@Answer(slot: 1) {
`??`
}

@Answer(slot: 2) {
`??`
}

@Answer(slot: 3) {
`exit(1)`
}
}

@Task(id: optional-binding-task, language: swift, starter: starters/swift-optional-binding-patterns.swift, tests: tests/swift-optional-binding-patterns.swift, solution: solutions/swift-optional-binding-patterns.swift) {
옵셔널 점수를 문자열 라벨로 바꾸는 gradeLabel(_:) 과, nil 을 0 으로 바꾸는 normalize(_:) 를 구현하라. gradeLabel 은 nil 이 아니면 언래핑된 점수로 "점수: 90" 형태의 문자열을 만들어야 하며 Optional(90) 같은 형태가 노출되면 안 된다. normalize 는 nil 일 때 0, nil 이 아니면 원래 값을 Int 로 돌려준다.

@Hint {
guard let else 블록 안에서는 return 이 반드시 필요하다 — guard 는 그 블록을 빠져나가지 않으면 컴파일되지 않는다.
}

@Hint {
guard let 을 통과한 score 는 함수 끝까지 옵셔널이 아닌 Int 로 쓸 수 있으므로, 문자열 보간에 그대로 넣으면 Optional(...) 이 붙지 않는다.
}

@Hint {
normalize 는 ?? 연산자 한 줄이면 끝난다 — nil 이면 0, 아니면 언래핑된 값이 나온다.
}
}

@Quiz(id: optional-binding-quiz, answer: after-guard-until-function-end) {
@Question {
guard let value = maybeValue else { return } 으로 바인딩한 상수 value 를 사용할 수 있는 범위는 어디까지인가?
}

@Choice(id: after-guard-until-function-end) {
guard 문 바로 다음부터 함수가 끝나는 지점까지 — else 블록에서 함수를 종료했으므로 이후 코드에는 nil 이 없음이 보장된다.
}

@Choice(id: only-inside-guard-else) {
그 guard 문의 else 블록 안에서만 — 블록을 벗어나면 value 에 접근할 수 없다.
}

@Choice(id: only-next-statement) {
guard 문 바로 다음 한 문장에서만 — 그 다음 문장부터는 다시 옵셔널로 돌아간다.
}

@Explanation {
guard 는 조건이 거짓이면 else 블록에서 함수 흐름을 반드시 종료시키기 때문에, guard 를 통과한 이후 코드는 모두 값이 존재함이 보장된 영역이다. 그래서 if let 과 달리 바인딩된 상수의 스코프가 if 블록이 아니라 함수 끝까지 벌어진다. 오답 둘은 if let 의 스코프 규칙이나 언래핑 동작을 혼동한 경우다.
}
}

@Reflection(id: optional-binding-reflection) {
@Prompt(id: when-force-unwrap) {
강제 언래핑(!)을 써도 괜찮다고 판단할 수 있는 상황은 언제일까? nil 이 될 수 없음을 어떻게 보장할 수 있을지 생각해 보라.
}

@Prompt(id: guard-let-vs-nil-coalescing) {
같은 옵셔널을 다룰 때 guard let 을 써야 하는 경우와 ?? 로 충분한 경우는 어떻게 다를까? nil 일 때 해야 할 일이 한 줄 대체값 이상이라면 어떤 패턴이 맞을까?
}

@Prompt(id: readability-comparison) {
학습목표에서 말한 것처럼 같은 처리를 if let, guard let, ?? 로 모두 작성해 봤다면, 세 코드 중 어떤 것이 읽기 가장 쉬웠고 그 이유는 무엇이었는지 스스로 설명해 보라.
}
}
