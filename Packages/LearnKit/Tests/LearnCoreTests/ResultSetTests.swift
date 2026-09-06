import Foundation
import Testing
@testable import LearnCore

@Suite("ResultSet — 언어 중립 결과 표")
struct ResultSetTests {

    @Test("빈 결과셋도 열 목록은 유지한다 — 0행과 '결과 없음'은 다르다")
    func emptyRowsKeepColumns() {
        let set = ResultSet(columns: [.init(name: "id"), .init(name: "name")])
        #expect(set.rowCount == 0)
        #expect(set.columnCount == 2)
        #expect(!set.isTruncated)
    }

    @Test("절단 여부는 결과셋 자신이 들고 다닌다")
    func truncationTravelsWithTheData() {
        let full = ResultSet(columns: [.init(name: "n")], rows: [[.integer(1)]])
        let cut = ResultSet(columns: [.init(name: "n")], rows: [[.integer(1)]], isTruncated: true)
        // 같은 행을 담아도 잘린 것과 아닌 것은 다른 값이다 — UI 가 "더 있음"을 그려야 한다.
        #expect(full != cut)
        #expect(cut.isTruncated)
    }

    @Test("저장 클래스 5종이 서로 다른 값으로 구분된다")
    func storageClassesAreDistinct() {
        let values: [ResultSet.Value] = [
            .null, .integer(0), .real(0.0), .text(""), .text("0"), .blob(Data()),
        ]
        #expect(Set(values).count == 6)
    }

    @Test("displayText 는 BLOB 을 hex 리터럴로 보여준다")
    func blobDisplaysAsHexLiteral() {
        #expect(ResultSet.Value.blob(Data([0x00, 0x0F, 0xFF])).displayText == "x'000FFF'")
        #expect(ResultSet.Value.null.displayText == "NULL")
        #expect(ResultSet.Value.text("Ada").displayText == "Ada")
        #expect(ResultSet.Value.integer(-7).displayText == "-7")
    }

    @Test("outputBytes 는 BLOB 을 바이트 그대로 낸다 — 여기서 hex 로 바꾸면 비UTF8 계약이 깨진다")
    func outputBytesPreserveRawBlob() {
        let raw = Data([0xFF, 0xFE, 0x00])
        #expect(ResultSet.Value.blob(raw).outputBytes == raw)
        #expect(String(data: ResultSet.Value.blob(raw).outputBytes, encoding: .utf8) == nil)
        #expect(ResultSet.Value.text("가").outputBytes == Data("가".utf8))
    }

    @Test("isNull 은 NULL 만 참이다 — 빈 문자열도 0 도 아니다")
    func isNullIsStrict() {
        #expect(ResultSet.Value.null.isNull)
        #expect(!ResultSet.Value.text("").isNull)
        #expect(!ResultSet.Value.integer(0).isNull)
        #expect(!ResultSet.Value.blob(Data()).isNull)
    }
}
