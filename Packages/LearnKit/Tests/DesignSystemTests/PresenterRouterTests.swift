import SwiftUI
import Testing

@testable import DesignSystem

@Suite("프리젠터 라우터 · 네 케이스")
struct PresenterRouterTests {
    @Test("케이스는 넷이고, 라우터가 세 갈래로 접는다")
    func fourCasesThreeRoutes() {
        #expect(ResultPresentation.allCases.count == 4)
        #expect(ResultPresentation.console.route == .console)
        #expect(ResultPresentation.table.route == .table)
        #expect(ResultPresentation.browser.route == .preparing)
        #expect(ResultPresentation.registers.route == .preparing)
        #expect(Set(ResultPresentation.allCases.map(\.route)) == Set(PresenterRoute.allCases))
    }

    @Test("실제 뷰가 있는 둘만 준비중 사유가 없다")
    func onlyPendingCasesCarryReason() {
        for presentation in ResultPresentation.allCases {
            switch presentation.route {
            case .console, .table:
                #expect(presentation.pendingReason == nil, "\(presentation)")
            case .preparing:
                #expect(presentation.pendingReason?.isEmpty == false, "\(presentation)")
            }
        }
    }

    @Test("네 케이스 전부 제목이 있고 서로 다르다")
    func titlesAreDistinct() {
        let titles = ResultPresentation.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }

    @Test("rawValue 가 LearnCore 의 Presenter 와 같은 철자다 — 옮겨 담기의 근거")
    func rawValuesMatchDomainSpelling() {
        // LearnCore 를 import 하지 않는다(디자인 시스템은 도메인을 모른다). 대신 철자를
        // 고정해 두고, 실제 대응은 LessonFeature 쪽 테스트가 `allCases` 로 확인한다.
        #expect(ResultPresentation.allCases.map(\.rawValue) == ["console", "table", "browser", "registers"])
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

@Suite("결과 표 · 표시 모델")
struct ResultTableTests {
    @Test("빈 표는 비어 있다")
    func emptyTable() {
        #expect(ResultTable.empty.isEmpty)
        #expect(!ResultTable.empty.hasDifferences)
    }

    @Test("표식이 있는 행 하나면 차이가 있다")
    func differencesAreDetected() {
        let table = ResultTable(
            columns: [.init(name: "n")],
            rows: [
                .init(id: 0, cells: [.init(text: "1")]),
                .init(id: 1, cells: [.init(text: "2")], mark: .missing),
            ]
        )
        #expect(table.hasDifferences)
        #expect(table.rowCount == 2)
        #expect(table.columnCount == 1)
    }
}
