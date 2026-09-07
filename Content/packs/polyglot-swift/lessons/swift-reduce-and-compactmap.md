@Concept(id: reduce-compactmap-sorted) {
`reduce` 는 배열을 순회하면서 누적값 하나로 접어 주는 고차 함수다. `numbers.reduce(0) { $0 + $1 }` 처럼 초기 누적값과 클로저를 넘기면, 첫 번째 인자 `$0` 은 지금까지의 누적값, `$1` 은 이번 원소가 되어 배열 전체가 단일 값으로 합쳐진다.

`compactMap` 은 `map` 처럼 원소를 변환하되, 변환 결과가 `nil` 인 원소를 결과에서 자동으로 걷어 낸다. 옵셔널 배열에서 `compactMap { $0 }` 를 쓰면 nil 이 제거된 배열이 나오고, 변환 클로저가 옵셔널을 반환하는 경우에도 nil 만 골라내므로 결과는 옵셔널이 아닌 배열이 된다.

`sorted(by:)` 는 정렬 기준을 클로저로 직접 정한다. 클로저는 두 원소를 받아 Bool 을 반환하는데, true 를 반환하면 첫 번째 원소 `$0` 가 두 번째 원소 `$1` 보다 앞에 온다. 따라서 `{ $0 < $1 }` 은 오름차순, `{ $0 > $1 }` 은 내림차순이 되고, 원소의 `.count` 같은 속성을 비교해 원하는 기준으로 정렬할 수도 있다.
}

@Example(id: reduce-compactmap-sorted-example, language: swift, expected: expected/swift-reduce-and-compactmap.txt) {
reduce 로 총합과 평균을 구하고, compactMap 으로 nil 과 잘못된 입력을 걷어낸 뒤, sorted(by:) 로 기준을 바꿔 정렬해 본다.

```swift
let scores = [80, 90, 100]

let total = scores.reduce(0) { $0 + $1 }
print("총합: \(total)")

let average = Double(total) / Double(scores.count)
print("평균: \(average)")

let raws: [String?] = ["3", nil, "10", nil, "7"]
let numbers = raws.compactMap { raw -> Int? in
    guard let raw = raw, let n = Int(raw) else { return nil }
    return n
}
print("숫자로 변환: \(numbers)")

let words = ["banana", "kiwi", "apple"]
let byLength = words.sorted(by: { $0.count < $1.count })
print("길이순: \(byLength)")

let descending = scores.sorted(by: { $0 > $1 })
print("내림차순: \(descending)")
```
}

@Blank(id: fill-reduce-compactmap-sorted, language: swift) {
배열을 하나의 값으로 접고, nil 을 걷어내고, 기준을 정해 정렬하는 표준 함수 이름으로 빈칸을 채워라.

```swift
let numbers = [4, 8, 15, 16, 23, 42]
let total = numbers.___1___(0) { $0 + $1 }

let raws: [String?] = ["a", nil, "b", nil]
let letters = raws.___2___ { $0 }

let scores = [72, 95, 88]
let topFirst = scores.___3___ { $0 > $1 }

print(total)
print(letters)
print(topFirst)
```

@Answer(slot: 1) {
`reduce`
}

@Answer(slot: 2) {
`compactMap`
}

@Answer(slot: 3) {
`sorted`
}
}

@Task(id: task-reduce-compactmap-sorted, language: swift, starter: starters/swift-reduce-and-compactmap.swift, tests: tests/swift-reduce-and-compactmap.swift, solution: solutions/swift-reduce-and-compactmap.swift) {
시험 점수 데이터를 가공하는 세 함수를 구현하라.

totalScore(_ scores: [Int]) -> Int — 점수 배열의 총합을 반환한다. 빈 배열이면 0 을 반환한다.

parseScores(_ raws: [String?]) -> [String?] — 문자열 옵셔널 배열을 받아 nil 이 아니면서 Int 로 변환 가능한 원소만 골라 [Int] 로 반환한다. 빈 배열이나 모두 nil 인 입력은 빈 배열을 반환한다. 순서는 원본 순서를 유지한다.

topScores(_ scores: [Int], count: Int) -> [Int] — 점수를 내림차순으로 정렬해 앞에서 count 개만 잘라 반환한다. count 가 배열 길이보다 크면 정렬된 배열 전체를, 배열이 비어 있으면 빈 배열을 반환한다.

세 함수 모두 원본 배열을 수정하지 말고 새 값을 반환하라.

@Hint {
totalScore 는 reduce 의 초기 누적값으로 0 을 넘기면 빈 배열도 자연스럽게 처리된다.
}

@Hint {
parseScores 는 compactMap 안에서 guard let 으로 nil 과 변환 실패를 한 번에 걸러 낼 수 있다.
}

@Hint {
topScores 는 sorted(by:) 로 내림차순 정렬한 뒤 prefix 로 앞부분만 잘라 내면 count 가 배열보다 큰 경우도 함께 처리된다.
}
}

@Quiz(id: quiz-reduce-initial-value, answer: value-26) {
@Question {
let total = [3, 5, 8].reduce(10) { $0 + $1 } 을 실행하면 total 의 값은 무엇인가?
}

@Choice(id: value-26) {
26 — 누적이 초기값 10 부터 시작해 10 + 3 + 5 + 8 이 된다.
}

@Choice(id: value-16) {
16 — 초기값은 무시되고 원소들만 더해진다.
}

@Choice(id: value-0) {
0 — reduce 는 항상 0 에서 누적을 시작한다.
}

@Choice(id: compile-error) {
컴파일 오류 — reduce 의 초기값 인자는 생략할 수 없어 10 을 쓸 수 없다.
}

@Explanation {
reduce 의 첫 번째 인자는 누적의 시작값이다. 클로저가 처음 호출될 때 $0 이 10, $1 이 3 이고 이후 15, 23 을 거쳐 최종 26 이 된다. 초기값을 바꾸면 결과도 그만큼 달라지므로, 예를 들어 16 은 초기값을 무시한 경우에 나오는 값이다.
}
}

@Reflection(id: reflection-reduce-compactmap-sorted) {
@Prompt(id: reduce-start-value) {
reduce 의 초기 누적값을 0 대신 다른 값으로 넘기면 어떤 상황에서 유용할까? 예를 하나 떠올려 보라.
}

@Prompt(id: map-vs-compactmap) {
map 대신 compactMap 을 써야 하는 상황은 언제인가? nil 이 섞여 들어오는 입력의 예를 하나 생각해 보라.
}

@Prompt(id: sort-closure-direction) {
sorted(by:) 에 { $0 > $1 } 을 넘기면 내림차순이 되는 이유를, 클로저가 true 를 반환했을 때 두 원소의 순서를 기준으로 설명해 보라.
}
}
