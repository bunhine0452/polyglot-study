import LearnCore
import SwiftUI
import Testing

@testable import DesignSystem

/// 라우터는 **도메인 열거형을 그대로** 받는다. 예전에는 `ResultPresentation` 이라는
/// 표시용 사본을 받았고, 그 사본이 `GradeResult.Presenter` 와 어긋나지 않는지 확인하는
/// 테스트가 `LessonFeatureTests` 에 따로 있었다. 사본이 사라져 그쪽도 함께 지웠다.
@Suite("프리젠터 라우터 · 네 케이스")
struct PresenterRouterTests {
    @Test("케이스는 넷이고, 라우터가 세 갈래로 접는다")
    func fourCasesThreeRoutes() {
        #expect(GradeResult.Presenter.allCases.count == 4)
        #expect(GradeResult.Presenter.console.route == .console)
        #expect(GradeResult.Presenter.table.route == .table)
        #expect(GradeResult.Presenter.browser.route == .preparing)
        #expect(GradeResult.Presenter.registers.route == .preparing)
        #expect(Set(GradeResult.Presenter.allCases.map(\.route)) == Set(PresenterRoute.allCases))
    }

    @Test("실제 뷰가 있는 둘만 준비중 사유가 없다")
    func onlyPendingCasesCarryReason() {
        for presenter in GradeResult.Presenter.allCases {
            switch presenter.route {
            case .console, .table:
                #expect(presenter.pendingReason == nil, "\(presenter)")
            case .preparing:
                #expect(presenter.pendingReason?.isEmpty == false, "\(presenter)")
            }
        }
    }

    @Test("네 케이스 전부 제목이 있고 서로 다르다")
    func titlesAreDistinct() {
        let titles = GradeResult.Presenter.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }
}

@Suite("결과 슬롯 · 고정 높이 예약")
struct ResultSlotTests {
    @Test("실행 전 예약 높이가 토큰 값이다")
    func emptySlotReservesToken() {
        #expect(ResultSlotMetrics.reservedHeight(lineCount: 0) == Spacing.outputSlotHeight)
    }

    @Test("짧은 실행 뒤에도 높이가 그대로다 — 상단 y 좌표가 움직이지 않는다")
    func shortRunDoesNotResize() {
        let before = ResultSlotMetrics.reservedHeight(lineCount: 0)
        for lineCount in 0...ResultSlotMetrics.reservedLineCount {
            #expect(ResultSlotMetrics.reservedHeight(lineCount: lineCount) == before, "\(lineCount) 줄")
        }
    }

    @Test("예약을 넘으면 아래로만 자란다 — 단조 증가")
    func growsMonotonically() {
        var previous = ResultSlotMetrics.reservedHeight(lineCount: 0)
        for lineCount in 1...40 {
            let height = ResultSlotMetrics.reservedHeight(lineCount: lineCount)
            #expect(height >= previous)
            previous = height
        }
        #expect(ResultSlotMetrics.reservedHeight(lineCount: 40) > Spacing.outputSlotHeight)
    }

    @Test("예약 안에 최소 두 줄은 들어간다")
    func reservesAtLeastTwoLines() {
        #expect(ResultSlotMetrics.reservedLineCount >= 2)
    }

    @Test("두 예약 자리가 서로 다른 축을 잡는다")
    func reservationAxes() {
        #expect(ResultSlotReservation.allCases.count == 2)
        #expect(ResultSlotReservation.lessonOutput.minHeight == Spacing.outputSlotHeight)
        #expect(ResultSlotReservation.lessonOutput.width == nil)
        #expect(ResultSlotReservation.editorPanel.width == Spacing.resultPanelWidth)
        #expect(ResultSlotReservation.editorPanel.minHeight == nil)
    }
}

@Suite("콘솔 트랜스크립트 · 청크 접기")
struct ConsoleTranscriptTests {
    @Test("실행 전에는 비어 있고 상태가 '실행 전' 이다")
    func emptyState() {
        let transcript = ConsoleTranscript.empty
        #expect(transcript.isEmpty)
        #expect(transcript.statusLabel == "실행 전")
    }

    @Test("줄 중간에서 끊긴 청크를 다시 잇는다")
    func splitChunksRejoin() {
        var transcript = ConsoleTranscript()
        transcript.append("hel", stream: .output)
        transcript.append("lo\n", stream: .output)
        #expect(transcript.lines.map(\.text) == ["hello"])
    }

    @Test("스트림이 바뀌면 줄을 잇지 않는다")
    func differentStreamsDoNotMerge() {
        var transcript = ConsoleTranscript()
        transcript.append("out", stream: .output)
        transcript.append("err", stream: .error)
        #expect(transcript.lines.count == 2)
        #expect(transcript.lines[0].stream == .output)
        #expect(transcript.lines[1].stream == .error)
    }

    @Test("꼬리 개행이 빈 줄을 만들지 않는다")
    func trailingNewlineDoesNotAddBlankLine() {
        var transcript = ConsoleTranscript()
        transcript.append("a\nb\n", stream: .output)
        #expect(transcript.lines.map(\.text) == ["a", "b"])
    }

    @Test("CRLF 를 한 줄로 뭉치지 않는다")
    func crlfSplits() {
        var transcript = ConsoleTranscript()
        transcript.append("a\r\nb\r\n", stream: .output)
        #expect(transcript.lines.map(\.text) == ["a", "b"])
    }

    @Test("줄 id 가 겹치지 않는다 — ForEach 가 행을 잃지 않게")
    func lineIDsAreUnique() {
        var transcript = ConsoleTranscript()
        transcript.append("a\nb\n", stream: .output)
        transcript.append("c\n", stream: .error)
        transcript.appendNote("메모")
        #expect(Set(transcript.lines.map(\.id)).count == transcript.lines.count)
    }

    @Test("절단은 한 번만 표시된다")
    func truncationIsIdempotent() {
        var transcript = ConsoleTranscript()
        transcript.markTruncated()
        transcript.markTruncated()
        #expect(transcript.isTruncated)
        #expect(transcript.lines.count(where: { $0.stream == .note }) == 1)
    }

    @Test("stdout 만 모아 기대 출력과 대조한다")
    func standardOutputTextExcludesStderr() {
        var transcript = ConsoleTranscript()
        transcript.append("결과\n", stream: .output)
        transcript.append("경고\n", stream: .error)
        #expect(transcript.standardOutputText == "결과")
    }

    @Test("상태 라벨이 실행 전·중·종료를 구별한다")
    func statusLabels() {
        var transcript = ConsoleTranscript()
        #expect(transcript.statusLabel == "실행 전")
        transcript.isRunning = true
        #expect(transcript.statusLabel == "실행 중")
        transcript.isRunning = false
        transcript.exitCode = 0
        #expect(transcript.statusLabel == "종료 0")
        transcript.exitCode = 2
        #expect(transcript.statusLabel == "종료 2")
    }
}

/// 표 프리젠터가 `LearnCore.ResultSet` 을 **그대로** 받는다는 것을 고정한다.
///
/// 예전 `DesignSystem.ResultTable` 미러는 지웠다. 그 타입에 있던 diff 표식
/// (`Mark`·`isMismatch`)은 채우는 코드가 없어 한 번도 그려진 적이 없다 — 함께 지웠고,
/// 경위는 `ResultPresenterView.TablePresenterView` 주석에 있다.
@Suite("결과 표 · 도메인 값을 그대로 그린다")
struct TablePresenterTests {
    static func status(_ resultSet: ResultSet, transcript: ConsoleTranscript = .empty) -> String {
        TablePresenterView(resultSet: resultSet, transcript: transcript).status
    }

    @Test("실행 전에는 열이 없고 '실행 전' 이라고 말한다")
    func emptyResultSet() {
        #expect(Self.status(ResultSet(columns: [])) == "실행 전")
    }

    @Test("실행 중에는 결과가 있어도 '실행 중' 이 이긴다")
    func runningWins() {
        var transcript = ConsoleTranscript()
        transcript.isRunning = true
        #expect(Self.status(ResultSet(columns: [.init(name: "n")]), transcript: transcript) == "실행 중")
    }

    @Test("행·열 수와 절단 표시가 결과셋에서 바로 나온다")
    func dimensionsComeFromResultSet() {
        let resultSet = ResultSet(
            columns: [.init(name: "n")], rows: [[.integer(1)], [.integer(2)]])
        #expect(Self.status(resultSet) == "2 행 · 1 열")

        var truncated = resultSet
        truncated.isTruncated = true
        #expect(Self.status(truncated) == "2 행 · 1 열 · 잘림")
    }

    @Test("셀 문자열과 NULL 판정이 도메인 값에서 나온다 — 옮겨 담지 않는다")
    func cellsRenderFromDomainValues() {
        let row: [ResultSet.Value] = [.text("paper"), .integer(2), .null]
        #expect(row.map(\.displayText) == ["paper", "2", "NULL"])
        #expect(row.map(\.isNull) == [false, false, true])
    }
}
