@Concept(id: swift-set-basics) {
집합(Set)은 중복을 허용하지 않는 원소들의 모음이다. 배열과 달리 같은 값을 두 번 넣어도 하나만 저장되고, 원소 사이에 순서가 없다. 그래서 "목록에 뭐가 있는가"보다 "어떤 값이 들어 있는가"가 중요할 때 쓰기 좋다.

선언은 타입 이름 뒤에 Set 을 붙이는 방식으로 한다. 예를 들어 문자열 집합은 Set<String> 이다. 배열 리터럴과 모양이 같아서 타입을 명시해 주는 것이 좋다. 원소를 추가하려면 insert 를, 제거하려면 remove 를 쓴다. Set 은 값 타입이라서 원소를 바꾸려면 변수가 var 로 선언되어 있어야 한다.

특정 값이 집합에 들어 있는지는 contains 로 확인한다. 배열에서 포함 여부를 찾으면 처음부터 끝까지 훑어야 하지만, 집합은 원소가 들어 있는지를 아주 빠르게 알 수 있다. 원소가 많아질수록 이 차이가 커진다.

두 집합을 하나로 합치는 union, 두 집합에 공통으로 들어 있는 원소만 남기는 intersection 같은 집합 연산도 기본으로 제공된다. 결과는 새로운 Set 이 나오므로 원래 집합은 그대로 유지된다. 집합에는 순서가 없으므로 화면에 찍거나 비교할 때는 sorted 로 배열로 바꿔서 다루면 예측 가능한 결과를 얻는다.
}

@Example(id: set-example-fruits, language: swift, expected: expected/swift-sets-and-operations.txt) {
과일 집합을 만들어 원소를 넣고 빼고, 포함 여부와 집합 연산을 확인해 본다. 집합은 순서가 없으므로 출력 전에 sorted 로 배열로 바꾼다.

```swift
var fruits: Set<String> = ["사과", "바나나", "오렌지"]
fruits.insert("포도")
fruits.remove("바나나")

print(fruits.contains("사과"))
print(fruits.contains("바나나"))

let mine: Set<String> = ["사과", "포도"]
let yours: Set<String> = ["포도", "딸기"]

print(mine.union(yours).sorted())
print(mine.intersection(yours).sorted())
```
}

@Blank(id: set-blank-operations, language: swift) {
두 숫자 집합을 합치고, 겹치는 원소를 찾고, 특정 값이 들어 있는지 확인하는 코드다. 빈칸에 알맞은 집합 기능의 이름을 채워라.

```swift
let numbers: Set<Int> = [1, 2, 3, 4]
let evens: Set<Int> = [2, 4, 6]

let combined = numbers.___1___(evens)
print(combined.sorted())

let shared = numbers.___2___(evens)
print(shared.sorted())

print(numbers.___3___(5))
```

@Answer(slot: 1) {
`union`
}

@Answer(slot: 2) {
`intersection`
}

@Answer(slot: 3) {
`contains`
}
}

@Task(id: set-task-tags, language: swift, starter: starters/swift-sets-and-operations.swift, tests: tests/swift-sets-and-operations.swift, solution: solutions/swift-sets-and-operations.swift) {
태그 데이터를 집합으로 다루는 네 함수를 구현하라.

uniqueSorted 는 문자열 배열에서 중복을 제거하고 정렬한 배열을 돌려준다. 빈 배열이 들어오면 빈 배열을 돌려준다.

unionTags 는 두 집합의 합집합을, commonTags 는 두 집합의 교집합을 돌려준다. 두 집합에 겹치는 원소가 없으면 commonTags 는 빈 집합을 돌려준다.

hasTag 는 집합에 tag 가 들어 있는지를 참·거짓으로 돌려준다.

입력 배열 안에 같은 값이 여러 번 나타날 수 있다는 점과, 결과 집합의 원소 개수가 언제나 0개 이상이라는 점을 생각하며 구현하라.

@Hint {
배열을 Set 으로 바꾸면 중복이 자동으로 사라진다.
}

@Hint {
합집합과 교집합은 union 과 intersection 한 번 호출로 끝난다.
}

@Hint {
포함 여부는 contains 가 참·거짓을 바로 돌려준다.
}
}

@Quiz(id: set-quiz-duplicate-insert, answer: kept-single) {
@Question {
이미 "사과" 가 들어 있는 집합에 다시 fruits.insert("사과") 를 호출하면 어떻게 되는가?
}

@Choice(id: kept-single) {
"사과" 는 그대로 하나만 남고 집합 내용은 변하지 않는다.
}

@Choice(id: stored-twice) {
"사과" 가 두 개가 되어 집합 개수가 1 늘어난다.
}

@Choice(id: runtime-error) {
실행 중에 오류가 발생해 프로그램이 멈춘다.
}

@Explanation {
집합은 중복을 허용하지 않으므로 이미 있는 원소를 insert 하면 집합 내용은 그대로다. insert 반환값이 이미 들어 있었음을 알려줄 뿐, 개수도 내용도 바뀌지 않는다.
}
}

@Reflection(id: set-reflection) {
@Prompt(id: set-vs-array) {
어떤 상황에서 배열 대신 집합을 쓰는 편이 나은가? 순서가 필요할 때와 필요 없을 때를 기준으로 생각해 보라.
}

@Prompt(id: fast-contains) {
원소가 수만 개인 목록에서 포함 여부를 자주 검사한다면, 집합의 contains 가 배열 탐색보다 왜 유리한지 설명해 보라.
}

@Prompt(id: daily-unions) {
일상에서 합집합이나 교집합처럼 다루는 데이터 예를 하나 떠올리고, 그것을 union 과 intersection 으어 어떻게 표현할지 말해 보라.
}
}
