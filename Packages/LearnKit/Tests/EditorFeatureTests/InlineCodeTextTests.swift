import Testing

@testable import EditorFeature

@Suite("과제 바 인라인 코드 파싱")
struct InlineCodeTextTests {
    @Test("백틱 쌍을 코드 구간으로 가른다")
    func splitsBacktickPairs() {
        let segments = InlineCodeText.segments(of: "`Counter` 를 값 타입(`struct`)으로 유지하세요.")
        #expect(segments == [
            .init(text: "Counter", isCode: true),
            .init(text: " 를 값 타입(", isCode: false),
            .init(text: "struct", isCode: true),
            .init(text: ")으로 유지하세요.", isCode: false),
        ])
    }

    @Test("백틱이 없으면 평문 한 구간이다")
    func plainTextIsOneSegment() {
        let segments = InlineCodeText.segments(of: "평문만 있는 문장입니다.")
        #expect(segments == [.init(text: "평문만 있는 문장입니다.", isCode: false)])
    }

    @Test("짝이 안 맞는 마지막 백틱은 평문으로 남는다")
    func unmatchedTrailingBacktickStaysPlain() {
        let segments = InlineCodeText.segments(of: "이건 `짝이 없다")
        #expect(segments == [
            .init(text: "이건 ", isCode: false),
            .init(text: "`짝이 없다", isCode: false),
        ])
    }

    @Test("빈 문자열은 구간이 없다")
    func emptyStringHasNoSegments() {
        #expect(InlineCodeText.segments(of: "").isEmpty)
    }
}
