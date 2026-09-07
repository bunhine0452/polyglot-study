@Concept(id: word-frequency-analyzer-concept) {
단어 빈도 분석기는 지금까지 배운 개념을 하나로 엮는 종합 프로젝트다. 문자열을 lowercased() 로 소문자로 바꾼 뒤 split 으로 단어 배열로 분해하고, 딕셔너리의 counts[word, default: 0] += 1 패턴으로 빈도를 집계한다. 정렬은 클로저 기준을 두 단계로 나눠, 빈도가 다르면 내림차순으로, 같으면 단어 오름차순으로 순서를 확정한다. 마지막으로 프로토콜이 분석기의 능력을 약속하고, 빈 입력이나 잘못된 개수 같은 계약 위반은 throws 로 오류를 던져 호출하는 쪽에 명확히 알린다.
}

@Example(id: word-frequency-example, language: swift, expected: expected/swift-capstone-word-frequency.txt) {
짧은 문장에서 단어 빈도를 세고, 상위 3개를 정렬 기준 클로저로 뽑아 출력한다. 딕셔너리는 순서가 없으므로 sorted 로 순서를 고정한 뒤 찍는다.

```swift
let text = "the quick brown fox the lazy dog the fox"

var counts: [String: Int] = [:]
for word in text.lowercased().split(separator: " ") {
    counts[String(word), default: 0] += 1
}

let ranked = counts.sorted { left, right in
    if left.value != right.value {
        return left.value > right.value
    }
    return left.key < right.key
}

for (word, count) in ranked.prefix(3) {
    print("\(word): \(count)")
}
```
}

@Blank(id: word-frequency-blank, language: swift) {
빈도 집계와 상위 개수 자르기의 핵심 코드가 비어 있다. 각 빈칸에 알맞은 코드 조각을 골라 채워라.

```swift
func topWords(in text: String, limit: Int) -> [(String, Int)] {
    var counts: [String: Int] = [:]
    for word in text.lowercased().split(separator: " ") {
        counts[String(word), default: 0] ___1___ 1
    }
    let ranked = counts.sorted { left, right in
        if left.value != right.value {
            return left.value ___2___ right.value
        }
        return left.key ___3___ right.key
    }
    return ranked.___4___(limit).map { ($0.key, $0.value) }
}
```

@Answer(slot: 1) {
`+=`
}

@Answer(slot: 2) {
`>`
}

@Answer(slot: 3) {
`<`
}

@Answer(slot: 4) {
`prefix`
}
}

@Task(id: word-frequency-task, language: swift, starter: starters/swift-capstone-word-frequency.swift, tests: tests/swift-capstone-word-frequency.swift, solution: solutions/swift-capstone-word-frequency.swift) {
FrequencyAnalyzer 프로토콜을 채택하는 BasicAnalyzer 를 완성하라. analyze(_:top:) 는 다음 계약을 지켜야 한다. 입력 문장을 소문자로 바꾼 뒤 공백 문자 기준으로 단어를 분해하고, 단어별 개수를 센다. 단어가 하나도 없으면 AnalyzerError.emptyInput 을 던지고, limit 이 1 미만이면 AnalyzerError.invalidLimit 을 던진다. 결과는 빈도 내림차순이며 빈도가 같으면 단어 오름차순으로 정렬한 상위 limit 개다.

@Hint {
split(whereSeparator: { $0.isWhitespace }) 를 쓰면 공백 여러 개나 탭이 섞여도 안전하게 단어를 나눈다.
}

@Hint {
빈도 집계는 counts[word, default: 0] += 1 한 줄이면 충분하다.
}

@Hint {
정렬 기준 클로저에서 빈도가 같을 때의 비교 조건을 빠뜨리면 동률인 단어들의 순서가 뒤섞인다.
}
}

@Quiz(id: word-frequency-quiz, answer: default-zero-then-increment) {
@Question {
counts[word, default: 0] += 1 을 실행했을 때 counts 에 word 라는 키가 아직 없다면 어떻게 되는가?
}

@Choice(id: default-zero-then-increment) {
0 을 기본값으로 키를 새로 만든 뒤 1 을 더해 counts[word] 가 1 이 된다.
}

@Choice(id: runtime-crash) {
키가 없는 옵셔널 서브스크립트이므로 실행 중 강제 언래핑 오류로 프로그램이 멈춘다.
}

@Choice(id: silently-ignored) {
키가 없으면 그 증가는 무시되고 딕셔너리는 변하지 않는다.
}

@Explanation {
default: 가 붙은 서브스크립트는 키가 없을 때 지정한 기본값으로 새 항목을 만들어 주므로, 새 단어도 안전하게 1 로 시작한다. 기본 서브스크립트는 옵셔널을 돌려줄 뿐 크래시하지 않고, 증가가 무시되는 일도 없다.
}
}

@Reflection(id: word-frequency-reflection) {
@Prompt(id: protocol-vs-concrete) {
BasicAnalyzer 를 그냥 구조체로만 쓰지 않고 FrequencyAnalyzer 프로토콜 뒤에 숨긴 이유는 무엇일까? 다른 정렬 규칙을 쓰는 분석기를 추가한다면 프로토콜이 어떻게 도움이 될까?
}

@Prompt(id: error-contract) {
빈 입력일 때 nil 을 반환하는 대신 오류를 던지도록 계약을 정했다. 호출하는 쪽에서는 do-catch 로 어떤 상황을 구분해 처리하게 되는지, 자신이 만든 프로그램에 비유해 설명해 보라.
}
}
