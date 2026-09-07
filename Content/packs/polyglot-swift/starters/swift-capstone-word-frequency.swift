enum AnalyzerError: Error, Equatable {
    case emptyInput
    case invalidLimit
}

struct WordFrequency: Equatable {
    let word: String
    let count: Int
}

protocol FrequencyAnalyzer {
    func analyze(_ text: String, top limit: Int) throws -> [WordFrequency]
}

struct BasicAnalyzer: FrequencyAnalyzer {
    func analyze(_ text: String, top limit: Int) throws -> [WordFrequency] {
        // 1) text 를 소문자로 바꾸고 공백 문자 기준으로 단어 배열을 만든다
        // 2) 단어가 하나도 없으면 AnalyzerError.emptyInput 을 던진다
        // 3) limit 이 1 미만이면 AnalyzerError.invalidLimit 을 던진다
        // 4) 딕셔너리로 빈도를 집계한 뒤 빈도 내림차순, 단어 오름차순으로 정렬하고 상위 limit 개를 반환한다
        fatalError("여기를 구현해라")
    }
}
