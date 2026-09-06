public import LanguageKit

/// 상태 표시 모양. 디자인의 3가지 표현이다 — `.unsupported` 는 `.emptySquare` 로 접혀
/// 들어가므로 4번째 케이스가 없다.
public enum StatusGlyph: Equatable, Sendable {
    /// 녹색 채움 사각 — `.ready`.
    case filledPass
    /// 적색 채움 사각 — `.stub`.
    case filledFail
    /// 1px 빈 사각 — `.missing`, 그리고 접어 넣은 `.unsupported`.
    case emptySquare
}

/// 한 행을 어떻게 그릴지. `ModuleAvailability` 4케이스가 이 타입 하나로 매핑된다.
public struct RowPresentation: Equatable, Sendable {
    public var glyph: StatusGlyph
    /// 상태 열에 보여줄 짧은 라벨 ("설치됨"/"미설치"/"스텁 감지").
    public var statusLabel: String
    /// "확인 결과" 열의 본문.
    public var detailText: String
    /// 있으면 "설치 명령" 열에 복사 버튼을 그린다. `nil` 이면 버튼이 없다.
    public var copyableCommand: String?

    public init(glyph: StatusGlyph, statusLabel: String, detailText: String, copyableCommand: String?) {
        self.glyph = glyph
        self.statusLabel = statusLabel
        self.detailText = detailText
        self.copyableCommand = copyableCommand
    }
}

extension ModuleAvailability {
    /// 판정 → 화면 표현.
    ///
    /// `switch` 에 `default` 를 두지 않는다 — `ModuleAvailability` 에 케이스가 늘면
    /// 여기서 컴파일이 깨져야 한다.
    ///
    /// `.unsupported` 는 디자인에 없는 4번째 상태라 `.missing` 과 같은 빈 사각으로 접되,
    /// `copyableCommand` 는 주지 않는다 — 최소 버전 미달은 "설치" 가 아니라 "업그레이드"
    /// 문제이고, 이 케이스는 애초에 업그레이드 명령을 들고 있지 않다(`{#availability-mapping}`).
    public var presentation: RowPresentation {
        switch self {
        case let .ready(version, executablePath):
            RowPresentation(
                glyph: .filledPass,
                statusLabel: "설치됨",
                detailText: "\(version) · \(executablePath)",
                copyableCommand: nil
            )
        case let .missing(installHint):
            RowPresentation(
                glyph: .emptySquare,
                statusLabel: "미설치",
                detailText: "설치된 실행 파일을 찾지 못했습니다.",
                copyableCommand: installHint
            )
        case let .stub(path, reason):
            RowPresentation(
                glyph: .filledFail,
                statusLabel: "스텁 감지",
                detailText: "\(path) 는 있지만 실행하면 실패합니다 · \(reason)",
                copyableCommand: nil
            )
        case let .unsupported(path, version, minimum):
            RowPresentation(
                glyph: .emptySquare,
                statusLabel: "미설치",
                detailText: "\(path) 는 \(version) 이라 최소 요구 버전 \(minimum) 에 못 미칩니다.",
                copyableCommand: nil
            )
        }
    }
}
