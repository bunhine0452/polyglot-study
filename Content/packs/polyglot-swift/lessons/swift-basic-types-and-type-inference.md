@Concept(id: basic-types-inference) {
Swift 의 기본 타입 중 이 레슨에서 다룰 넷은 Int(정수), Double(실수), String(문자열), Bool(참/거짓)입니다. 변수를 선언할 때 타입 표기를 생략하면 Swift 컴파일러가 오른쪽 값을 보고 타입을 스스로 정하는데, 이것을 타입 추론이라고 부릅니다. 예를 들어 let a = 3 은 Int 로, let b = 3.0 은 Double 로 추론됩니다. 추론 결과가 어떤 타입인지 궁금할 때는 type(of:) 에 값을 넘겨보면 됩니다. type(of: 3) 은 Int 를, type(of: 3.0) 은 Double 을 돌려주므로 눈으로 직접 확인할 수 있습니다. 주의할 점은 Int 와 Double 을 그대로 더하면 컴파일 오류가 난다는 것입니다. Swift 는 숫자 타입을 자동으로 바꿔주지 않기 때문에, Int 값 x 를 Double 과 더하려면 Double(x) 처럼 직접 변환해 주어야 합니다.
}

@Example(id: type-of-example, language: swift, expected: expected/swift-basic-types-and-type-inference.txt) {
네 가지 기본 타입의 값을 선언하고, type(of:) 로 추론된 타입을 찍어본 뒤, Int 를 Double 로 변환해서 더하는 예제입니다.

```swift
let age = 20
let pi = 3.14
let name = "민수"
let isStudent = true

print(age)
print(type(of: age))
print(pi)
print(type(of: pi))
print(name)
print(type(of: name))
print(isStudent)
print(type(of: isStudent))

let score = 85
let average = 80.5
let adjusted = Double(score) + average
print(adjusted)
```
}

@Blank(id: types-blank, language: swift) {
사과 세 개와 정수로 된 사과 한 개 가격, 실수로 된 오렌지 가격으로 총액을 계산하는 코드입니다. 빈칸을 채워 완성하세요.

```swift
let apples = 3
let orangePrice = 700.0
let applePrice = 500

let total = Double(apples) * orangePrice + Double(applePrice)
print(type(of: ___1___))
print(type(of: apples))
let labeled = "총액: " + ___2___(total)
print(labeled)
```

@Answer(slot: 1) {
`total`
}

@Answer(slot: 2) {
`String`
}
}

@Task(id: add-int-double-task, language: swift, starter: starters/swift-basic-types-and-type-inference.swift, tests: tests/swift-basic-types-and-type-inference.swift, solution: solutions/swift-basic-types-and-type-inference.swift) {
Int 값 하나와 Double 값 하나를 받아서, Int 를 Double 로 변환한 뒤 두 값을 더해 반환하는 함수 addIntAndDouble(_:_:) 를 작성하세요. 입력 조건은 a 가 임의의 Int, b 가 임의의 Double 이고, 반환값은 Double(a) + b 입니다.

@Hint {
Swift 는 Int 와 Double 을 자동으로 섞어주지 않으므로 Double(a) 처럼 직접 변환해야 합니다.
}

@Hint {
변환한 값과 b 를 + 로 더한 결과가 이미 Double 이므로 그대로 return 하면 됩니다.
}

@Hint {
starte 는 fatalError 로 비어 있으니, 함수 몸통만 채우면 됩니다.
}
}

@Quiz(id: mixed-arithmetic-quiz, answer: compile-error) {
@Question {
let n = 5 와 let d = 2.5 가 있을 때 n + d 를 그대로 쓰면 어떻게 되나요?
}

@Choice(id: implicit-conversion) {
n 이 자동으로 Double 로 바뀌어 7.5 가 계산된다
}

@Choice(id: compile-error) {
컴파일 오류가 나고, Double(n) + d 처럼 직접 변환해야 한다
}

@Choice(id: int-result) {
결과가 Int 로 잘려서 7 이 된다
}

@Explanation {
Swift 는 숫자 타입을 암묵적으로 변환하지 않으므로 Int 와 Double 을 그대로 더하면 컴파일 오류입니다. Double(n) 으로 명시적으로 변환한 뒤 더해야 7.5 를 얻습니다.
}
}

@Reflection(id: types-reflection) {
@Prompt(id: inference-observation) {
let a = 10 과 let b = 10.0 을 각각 선언했을 때 type(of:) 의 결과가 서로 달랐나요? 추론 결과를 기억나는 대로 적어보세요.
}

@Prompt(id: conversion-experience) {
Int 와 Double 을 그대로 더해봤다가 오류를 만나본 적이 있나요? 그때 오류 메시지가 무엇을 알려주던지 적어보세요.
}

@Prompt(id: when-annotation) {
타입 추론에 맡기는 것과 let x: Double = 3 처럼 타입을 직접 쓰는 것 중, 어떤 상황에서 직접 쓰는 편이 좋을까요? 본인의 생각을 적어보세요.
}
}
