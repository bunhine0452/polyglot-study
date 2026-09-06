public import DesignSystem

/// 트랙 표 마지막 열의 툴체인 상태.
///
/// ## 왜 `ModuleAvailability` 를 그대로 쓰지 않는가
///
/// 그 타입은 `LanguageKit` 에 있고 실제 감지는 `RunnerKit.ToolchainProbe` 가 한다.
/// `DashboardFeature` 타깃의 의존은 `LearnCore` · `LearnPersistence` · `DesignSystem`
/// 셋뿐이라(`Package.swift`, 이 세션의 수정 범위 밖) 두 모듈을 볼 수 없다. 그래서 감지
/// **결과**만 받는 포트를 여기 두고, 앱 계층이 `ModuleAvailability.presentation` 과
/// 같은 자리에서 값을 채워 넣는다.
///
/// 목 데이터를 만들지 않는다는 규칙은 여기서도 같다 — 공급자가 없으면 `.unknown` 이고,
/// 화면에는 "확인 중…" 이 나온다. 설치됐다고 지어내지 않는다.
///
/// `nonisolated` 인 이유: 감지 결과는 `@Sendable` 공급자 클로저가 MainActor 밖에서
/// 만들어 건네는 값이다. 모듈 기본 격리가 MainActor 라 표시가 없으면 그 클로저 안에서
/// 케이스를 만들 수 없다.
nonisolated public enum TrackToolchainStatus: Hashable, Sendable {
    /// 아직 감지하지 않았다. 앱이 `ToolchainProbe` 를 붙이기 전의 정직한 상태.
    case unknown
    /// 실행 파일이 있고 `--version` 이 정상 종료했다.
    case ready(tool: String, version: String)
    /// 실행 파일을 찾지 못했다.
    case missing(tool: String)
    /// 실행 파일은 있지만 실행이 실패한다. 설치된 것으로 오인하기 가장 쉬운 상태다.
    case stub(tool: String)

    /// 표에 찍는 모노 문자열. 디자인의 `swiftc 6.3.3` · `go · 미설치` · `java · 스텁 감지`.
    public var label: String {
        switch self {
        case .unknown: "확인 중…"
        case let .ready(tool, version): "\(tool) \(version)"
        case let .missing(tool): "\(tool) · 미설치"
        case let .stub(tool): "\(tool) · 스텁 감지"
        }
    }

    /// 8px 상태 도트. "빨강이 보이면 반드시 실패" 규칙을 그대로 따른다.
    public var dot: StatusDot.Style {
        switch self {
        case .unknown, .missing: .empty
        case .ready: .pass
        case .stub: .fail
        }
    }
}
