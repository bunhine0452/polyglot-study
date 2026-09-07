@Concept(id: swift-string-interpolation) {
문자열 보간은 문자열 안에 백슬래시와 괄호를 이용해 \(표현식) 형태로 값을 끼워 넣는 문법이다. 괄호 안에는 변수뿐 아니라 age + 1 같은 연산식도 올 수 있고, 문자열을 만드는 시점에 그 식이 평가된 결과가 문자열에 들어간다. String 은 count 프로퍼티로 글자 수를 알 수 있고, uppercased() 메서드는 모든 글자를 대문자로 바꾼 새 문자열을 돌려준다. 이 기능들을 조합하면 여러 값을 한 문장으로 묶은 결과를 print 로 바로 확인할 수 있다.
}

@Example(id: interpolation-demo, language: swift, expected: expected/swift-string-interpolation.txt) {
변수와 연산식을 보간해 문장을 만들고, count 와 uppercased() 의 결과도 함께 출력해 본다.

```swift
let name = "민수"
let age = 20
let word = "swift"

print("이름: \(name), 나이: \(age)")
print("내년 나이: \(age + 1)")
print("글자 수: \(word.count)")
print("대문자: \(word.uppercased())")
print("\(name)는 \(word.count)글자짜리 언어를 배워요.")
```
}

@Blank(id: fill-interpolation, language: swift) {
보간식과 String 기능을 써서 문장을 완성하는 코드입니다. 빈칸을 채워 실행하면 두 줄이 출력됩니다.

```swift
let city = "seoul"
let message = "도시: \(___1___), 글자 수: \(city.___2___)"
print(message)
print(message.___3___)
```

@Answer(slot: 1) {
`city`
}

@Answer(slot: 2) {
`count`
}

@Answer(slot: 3) {
`uppercased()`
}
}

@Task(id: greet-and-shout, language: swift, starter: starters/swift-string-interpolation.swift, tests: tests/swift-string-interpolation.swift, solution: solutions/swift-string-interpolation.swift) {
두 함수를 완성하세요. greet(name:age:) 는 이름과 나이를 받아 "안녕하세요, (이름)님! 나이는 (나이)살이에요." 형태의 문자열을 반환합니다. shout(_:) 는 문자열을 받아 대문자로 바꾼 뒤 "(대문자 결과)! 글자 수는 (글자 수)자예요." 형태의 문자열을 반환합니다. 두 함수 모두 문자열 보간을 사용하고, 글자 수는 count 로 세세요. 빈 문자열도 처리할 수 있어야 합니다.

@Hint {
문자열 안에서 값을 넣을 자리에 \(이름) 형태로 감싸 보세요.
}

@Hint {
shout 함수에서는 보간식 안에서 text.uppercased() 와 text.count 를 바로 평가할 수 있습니다.
}

@Hint {
빈 문자열의 count 는 0이고 uppercased() 는 빈 문자열 그대로입니다 — 특별한 분기가 필요 없습니다.
}
}

@Quiz(id: interpolation-quiz, answer: evaluated-six) {
@Question {
다음 코드를 실행하면 출력되는 것은?

let n = 3
print("결과: \(n * 2)")
}

@Choice(id: literal-backslash) {
결과: \(n * 2) 이 문자 그대로 출력된다.
}

@Choice(id: evaluated-six) {
결과: 6 이 출력된다.
}

@Choice(id: expression-text) {
결과: n * 2 이 출력된다.
}

@Explanation {
보간식 \(n * 2) 는 문자열을 만드는 시점에 식을 평가하므로 n * 2 의 결과인 6이 문자열에 들어간다. 백슬래시가 문자 그대로 남거나 식 텍스트가 그대로 나오지 않는다.
}
}

@Reflection(id: interpolation-reflection) {
@Prompt(id: concat-vs-interpolation) {
문자열을 + 로 이어 붙이는 것과 보간 \(...) 를 쓰는 것을 비교해 보세요. 숫자와 문자열을 섞어 한 문장을 만들 때 어느 쪽이 더 편하고, 그 이유는 무엇인가요?
}

@Prompt(id: uppercased-original) {
uppercased() 를 호출한 뒤 원래 문자열 변수를 다시 출력해 보면 어떤 값이 나올까요? 메서드가 원본을 바꾸는지, 새 문자열을 돌려주는지 실행으로 확인해 보세요.
}

@Prompt(id: count-thinking) {
count 를 보간식 안에서 쓸 때와 밖에서 변수에 담아 쓸 때의 차이가 있을까요? 여러 번 같은 글자 수를 문장에 넣어야 한다면 어떻게 코드를 구성하겠나요?
}
}
