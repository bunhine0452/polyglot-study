@Concept(id: dictionary-basics) {
딕셔너리(Dictionary)는 키-값 쌍을 저장하는 컬렉션으로, 배열과 달리 순서가 보장되지 않는다. `[키: 값]` 형태의 리터럴로 만들고, `scores["kim"]` 처럼 대괄호 subscript 에 키를 넣어 값을 읽는다. 존재하는 키로 접근하면 값을 감싼 옵셔널이 돌아오고, 존재하지 않는 키로 접근하면 `nil` 이 돌아온다. subscript 에 새 값을 대입하면 기존 키의 값은 갱신되고, 없던 키면 새 쌍이 추가된다. `for (key, value) in dict` 로 모든 쌍을 순회할 수 있고, 순서가 필요하면 `sorted(by:)` 로 정렬해야 한다.
}

@Example(id: dictionary-observe, language: swift, expected: expected/swift-dictionaries-key-value.txt) {
딕셔너리를 만들고, 있는 키와 없는 키로 각각 접근해 옵셔널과 nil 이 어떻게 출력되는지 관찰한 뒤, 값 갱신·추가·순회를 실행해 본다.

```swift
var scores = ["kim": 90, "lee": 85, "park": 60]

// 있는 키로 접근하면 옵셔널이, 없는 키로 접근하면 nil 이 돌아온다
print(scores["kim"])
print(scores["sun"])

// subscript 대입: 기존 키는 갱신, 새 키는 추가
scores["kim"] = 95
scores["sun"] = 88

// 키를 정렬해 순서를 고정한 뒤 전체를 출력
for name in scores.keys.sorted() {
    print("\(name): \(scores[name])")
}

// 조건에 맞는 항목만 골라 세기
var passed = 0
for (_, score) in scores {
    if score >= 85 {
        passed += 1
    }
}
print("합격 인원: \(passed)")
```
}

@Blank(id: dictionary-fill, language: swift) {
카페 메뉴 딕셔너리에서 값을 읽고, 새 메뉴를 추가하고, 전체를 순회하는 코드다. 빈칸을 채워라.

```swift
var menu = ["coffee": 3800, "tea": 2900]

// coffee 의 값을 읽어 출력한다
print(menu[___1___])

// latte 라는 새 키를 추가한다
menu["latte"] = ___2___

// 전체 쌍을 순회하며 출력한다
for (item, price) in ___3___ {
    print("\(item): \(price)")
}
```

@Answer(slot: 1) {
`"coffee"`
}

@Answer(slot: 2) {
`4200`
}

@Answer(slot: 3) {
`menu`
}
}

@Task(id: high-scorers-task, language: swift, starter: starters/swift-dictionaries-key-value.swift, tests: tests/swift-dictionaries-key-value.swift, solution: solutions/swift-dictionaries-key-value.swift) {
함수 highScorers 를 구현하라. 첫 번째 매개변수 scores 는 학생 이름을 키로, 점수를 값으로 가지는 딕셔너리이고, threshold 이상인 점수를 받은 학생 이름만 모아 사전순으로 정렬한 [String] 을 반환한다. threshold 와 정확히 같은 점수도 포함해야 하고, 조건에 맞는 학생이 없으면 빈 배열을 반환한다.

@Hint {
for (name, score) in scores 로 키와 값을 한 번에 꺼낼 수 있다.
}

@Hint {
조건을 score >= threshold 로 쓰면 threshold 와 같은 점수도 포함된다.
}

@Hint {
순서가 흔들리지 않도록 마지막에 result.sorted() 로 정렬해서 반환하라.
}
}

@Quiz(id: missing-key-quiz, answer: nil-returned) {
@Question {
var d = ["a": 1] 인 딕셔너리에서 d["b"] 를 print 하면 무엇이 출력되는가?
}

@Choice(id: nil-returned) {
nil 이 출력된다. 없는 키로 접근하면 값 대신 nil 을 돌려준다.
}

@Choice(id: runtime-crash) {
실행 중 오류로 프로그램이 비정상 종료된다.
}

@Choice(id: zero-default) {
0 이 출력된다. 값 타입의 기본값이 돌아온다.
}

@Choice(id: key-echo) {
b 가 출력된다. 접근에 실패하면 키 자신을 돌려준다.
}

@Explanation {
딕셔너리의 subscript 접근은 항상 옵셔널을 반환한다. 키가 존재하면 Optional(값) 이, 존재하지 않으면 nil 이 돌아오며 print 로 찍으면 nil 이 출력된다. 크래시가 나는 것은 옵셔널 강제 해제(!) 를 했을 때의 이야기다.
}
}

@Reflection(id: dictionary-reflection) {
@Prompt(id: why-optional) {
딕셔너리 subscript 접근이 값을 그대로가 아니라 옵셔널로 돌려주는 이유를 문장으로 설명해 보라.
}

@Prompt(id: order-matters) {
딕셔너리를 그대로 순회하면 실행마다 순서가 달라질 수 있다. 순서가 중요한 출력을 만들어야 한다면 어떻게 해야 하는가?
}

@Prompt(id: array-vs-dictionary) {
학생 이름과 점수 목록을 저장한다고 할 때, 배열 대신 딕셔너리를 쓰면 좋은 점은 무엇일까?
}
}
