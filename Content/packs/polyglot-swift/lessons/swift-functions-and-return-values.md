@Concept(id: func-basics) {
Swift 에서 함수는 func 키워드로 정의한다. 함수 이름 뒤 괄호 안에 매개변수 이름과 타입을 쓰고, 값을 돌려주는 함수라면 화살표 -> 뒤에 반환 타입을 적는다. 예를 들어 func double(_ n: Int) -> Int 는 Int 하나를 받아 Int 하나를 돌려주는 함수다. 함수 몸통에서 return 문은 계산 결과를 호출한 쪽에 돌려주고 함수 실행을 끝낸다. 값을 돌려주지 않는 함수는 -> 부분을 아예 쓰지 않는데, 이때 반환 타입은 Void 로 취급되고 그런 함수는 호출했을 때 되돌려받을 값이 없다. 같은 인자를 넣어 호출하면 함수는 매번 같은 값을 돌려준다. 입력이 같으면 출력도 같다는 이 성질 덕분에 함수를 반복문 안에서 여러 번 호출해 인자별 결과를 차곡차곡 모을 수 있다.
}

@Example(id: square-and-greet, language: swift, expected: expected/swift-functions-and-return-values.txt) {
제곱을 돌려주는 함수와 인사만 출력하고 끝나는 함수를 정의한 뒤, 같은 인자로 여러 번 호출하고 반복문에서 결과를 모아 출력한다.

```swift
func square(_ n: Int) -> Int {
    return n * n
}

func greet(name: String) {
    print("안녕, \(name)!")
}

print(square(3))
print(square(3))
print(square(3))

greet(name: "민수")

var results: [String] = []
for n in [1, 2, 3, 4] {
    results.append("\(n)의 제곱은 \(square(n))")
}
for line in results {
    print(line)
}
```
}

@Blank(id: fill-triple, language: swift) {
세 배를 돌려주는 함수를 func 키워드와 return 문으로 완성하고, 호출 결과를 변수에 담아 출력해 보자.

```swift
___1___ triple(_ n: Int) -> Int {
    ___2___ n * 3
}

let value = triple(4)
print("triple(4) = \(___3___)")
```

@Answer(slot: 1) {
`func`
}

@Answer(slot: 2) {
`return`
}

@Answer(slot: 3) {
`value`
}
}

@Task(id: function-practice, language: swift, starter: starters/swift-functions-and-return-values.swift, tests: tests/swift-functions-and-return-values.swift, solution: solutions/swift-functions-and-return-values.swift) {
세 함수를 구현하라. double(*:) 은 Int 를 받아 두 배를 반환한다. grade(for:) 는 점수를 받아 90 이상이면 "A", 80 이상 90 미만이면 "B", 그 외에는 "C" 를 반환한다. sumUpTo(*:) 는 1 부터 n 까지의 합을 반환하되, n 이 0 이하이면 0 을 반환한다. 세 함수 모두 인자가 같으면 항상 같은 값을 돌려야 한다.

@Hint {
double 은 return n * 2 한 줄이면 충분하다.
}

@Hint {
grade 는 if 와 else if 로 90 과 80 의 경계를 큰 쪽부터 검사하면 겹치지 않는다.
}

@Hint {
sumUpTo 는 1...n 범위가 n 이 1 보다 작으면 만들어지지 않아 실행이 중단된다. 반복문에 들어가기 전에 if n <= 0 { return 0 } 으로 먼저 걸러라.
}
}

@Quiz(id: arrow-meaning, answer: returns-int) {
@Question {
func triple(_ n: Int) -> Int 에서 -> Int 가 뜻하는 것은 무엇인가?
}

@Choice(id: returns-int) {
이 함수가 Int 값을 하나 반환한다는 뜻이다.
}

@Choice(id: param-is-int) {
이 함수의 매개변수 n 이 Int 라는 뜻이다.
}

@Choice(id: cast-to-int) {
함수의 결괏값을 Int 로 형변환해서 돌려준다는 뜻이다.
}

@Explanation {
화살표 -> 뒤에는 함수가 돌려주는 값의 타입이 온다. 매개변수의 타입은 괄호 안의 n: Int 처럼 쓰고, 형변환은 함수 선언이 아니라 Int(someDouble) 같은 식으로 한다.
}
}

@Reflection(id: function-reflection) {
@Prompt(id: same-input-same-output) {
square(3) 을 세 번 호출했을 때 세 번 모두 9 가 나왔다. 인자가 같은데 결과가 다르게 나오려면 함수 안에 어떤 것이 있어야 할까?
}

@Prompt(id: void-vs-value) {
greet 처럼 반환값이 없는 함수를 호출한 줄과 square 처럼 값을 돌려주는 함수를 호출한 줄은 코드를 읽는 사람에게 각각 어떤 의도를 알려줄까?
}
}
