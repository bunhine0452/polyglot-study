@Concept(id: array-basics) {
Array 는 여러 값을 하나의 순서 있는 목록으로 묶는 타입이다. 대괄호 리터럴 [10, 20, 30] 으로 만들 수 있고, 타입을 명시할 때는 [Int] 처럼 적는다. 각 요소는 0 부터 시작하는 인덱스로 접근하며, numbers[0] 이 첫 번째 요소다. append(_:) 메서드로 배열 끝에 새 값을 추가하면 count 프로퍼티가 자동으로 늘어난다. 배열의 모든 요소를 차례로 처리할 때는 for-in 순회가 가장 간단하다: for value in numbers { ... } 형태로 쓰면 value 에 요소가 하나씩 전달된다. 빈 배열은 var list: [Int] = [] 처럼 만들고, 이후 append 와 반복문으로 값을 채워 나간다.
}

@Example(id: array-example, language: swift, expected: expected/swift-arrays-and-element-access.txt) {
배열 리터럴 생성, 인덱스 접근, append 와 count 확인, for-in 순회로 합계를 구하는 과정을 실행해 본다.

```swift
var scores = [90, 75, 88]
print("첫 번째 점수: \(scores[0])")
print("요소 수: \(scores.count)")

scores.append(95)
print("추가 후 요소 수: \(scores.count)")

var total = 0
for score in scores {
    total += score
}
print("합계: \(total)")

var filled: [Int] = []
print("빈 배열 요소 수: \(filled.count)")
for i in 1...3 {
    filled.append(i * 10)
}
print(filled)
```
}

@Blank(id: array-blank, language: swift) {
배열에 append 로 값을 추가하고, for-in 문으로 모든 요소를 더하는 코드다. 빈칸을 채워 완성하라.

```swift
var numbers = [10, 20, 30]
___1___.append(40)
print("개수: \(numbers.count)")

var total = 0
for n ___2___ numbers {
    total += n
}
print("합계: \(total)")
```

@Answer(slot: 1) {
`numbers`
}

@Answer(slot: 2) {
`in`
}
}

@Task(id: array-sum-task, language: swift, starter: starters/swift-arrays-and-element-access.swift, tests: tests/swift-arrays-and-element-access.swift, solution: solutions/swift-arrays-and-element-access.swift) {
함수 sumUpTo(_ n: Int) -> Int 를 구현하라. 빈 배열을 만들고, 1 부터 n 까지의 정수를 for-in 또는 while 반복으로 append 하여 채운 뒤, 배열의 모든 요소를 순회해 합계를 반환한다. n 이 0 이하이면 아무것도 채우지 않고 0 을 반환해야 한다. 배열 범위 밖의 반복(예: n 이 0 일 때의 닫힌 범위)은 실행 오류를 일으키므로 주의하라.

@Hint {
빈 배열은 var list: [Int] = [] 처럼 만든다.
}

@Hint {
1...n 범위는 n 이 0 이하이면 실행 오류이므로 while 반복이나 조건 검사로 경계를 처리하라.
}

@Hint {
합계는 total 변수를 0 으로 두고 for value in numbers 로 더하면 된다.
}
}

@Quiz(id: array-index-quiz, answer: runtime-crash) {
@Question {
var fruits = ["사과", "배"] 인 배열이 있을 때 fruits[2] 를 실행하면 어떻게 되는가?
}

@Choice(id: runtime-crash) {
인덱스가 범위를 벗어나 프로그램이 런타임 오류로 멈춘다.
}

@Choice(id: returns-nil) {
값이 없으므로 nil 을 반환한다.
}

@Choice(id: returns-empty) {
빈 문자열 "" 을 반환한다.
}

@Explanation {
Swift 배열 인덱스는 0 부터 count - 1 까지만 유효하다. fruits 는 인덱스 0 과 1 만 가지므로 2 에 접근하면 런타임 오류가 발생해 프로그램이 비정상 종료된다. nil 을 반환하는 방식이 아니므로 범위를 벗어난 접근은 미리 count 로 확인해야 한다.
}
}

@Reflection(id: array-reflection) {
@Prompt(id: count-before-index) {
반복문 안에서 인덱스로 배열 요소에 접근할 때, 범위를 벗어나는 오류를 피하려면 어떤 값과 비교해야 하는가?
}

@Prompt(id: append-mutation) {
append 로 값을 추가하려면 배열이 let 이 아니라 var 로 선언되어 있어야 한다. 그 이유를 자신의 말로 설명해 보라.
}

@Prompt(id: empty-array-use) {
처음부터 값이 들어 있는 배열 리터럴 대신 빈 배열을 만들어 append 로 채우는 방식이 유용한 상황은 언제인지 예를 들어 보라.
}
}
