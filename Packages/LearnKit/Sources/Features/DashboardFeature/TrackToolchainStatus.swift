public import DesignSystem
public import LanguageKit

/// 트랙 표 마지막 열의 툴체인 상태.
///
/// ## 감지 결과는 `ModuleAvailability` 그대로 들고 온다
///
/// 예전에는 이 열거형이 `ready`·`missing`·`stub` 을 **다시 적고** 있었다. 감지 결과
/// 타입인 `LanguageKit.ModuleAvailability` 를 `DashboardFeature` 가 볼 수 없었기
/// 때문이다(타깃 의존이 `LearnCore`·`LearnPersistence`·`DesignSystem` 셋뿐이었다).
/// `LanguageKit` 을 붙이면서 그 사본을 걷어냈다 — 이제 포트는 감지 결과를 통째로
/// 실어 나르고, 이 타입이 하는 일은 **두 가지뿐**이다: 아직 감지하지 않은 상태를
/// 표현하는 것과, 표에 찍을 라벨·도트를 고르는 것.
///
/// `LanguageKit` 은 값 타입과 프로토콜만 있는 모듈이다. 감지를 실제로 수행하는
/// `RunnerKit.ToolchainProbe` 는 여전히 여기서 보이지 않는다 — 앱 계층이 재료를 넣는다.
///
/// 목 데이터를 만들지 않는다는 규칙은 그대로다 — 공급자가 없으면 `.unknown` 이고,
/// 화면에는 "확인 중…" 이 나온다. 설치됐다고 지어내지 않는다.
///
/// `nonisolated` 인 이유: 감지 결과는 `@Sendable` 공급자 클로저가 MainActor 밖에서
/// 만들어 건네는 값이다. 모듈 기본 격리가 MainActor 라 표시가 없으면 그 클로저 안에서
/// 케이스를 만들 수 없다.
nonisolated public enum TrackToolchainStatus: Hashable, Sendable {
    /// 아직 감지하지 않았다. 앱이 `ToolchainProbe` 를 붙이기 전의 정직한 상태.
    case unknown
    /// 감지했다. `tool` 은 표에 찍는 실행 파일 이름(`swiftc`·`go`·`java`)이고,
    /// 판정은 `ModuleAvailability` 그대로다.
    ///
    /// 이름을 따로 받는 이유는 `ModuleAvailability` 에 그게 없기 때문이다 — 거기 있는
    /// 것은 경로(`/usr/bin/java`)와 설치 힌트뿐이고, `.missing` 에는 경로조차 없다.
    /// 트랙 표는 좁아서 경로가 아니라 이름을 찍는다.
    case probed(tool: String, ModuleAvailability)

    /// 표에 찍는 모노 문자열. 디자인의 `swiftc 6.3.3` · `go · 미설치` · `java · 스텁 감지`.
    ///
    /// `.unsupported` 는 디자인에 없는 4번째 상태다. 온보딩이 같은 자리에서 내린 판단을
    /// 그대로 따른다 — `.missing` 과 같은 표현으로 접는다(`{#availability-mapping}`,
    /// `OnboardingFeature/ModuleAvailabilityPresentation.swift`).
    public var label: String {
        switch self {
        case .unknown: "확인 중…"
        case let .probed(tool, availability):
            switch availability {
            case let .ready(version, _): "\(tool) \(version)"
            case .missing, .unsupported: "\(tool) · 미설치"
            case .stub: "\(tool) · 스텁 감지"
            }
        }
    }

    /// 8px 상태 도트. "빨강이 보이면 반드시 실패" 규칙을 그대로 따른다.
    public var dot: StatusDot.Style {
        switch self {
        case .unknown: .empty
        case let .probed(_, availability):
            switch availability {
            case .ready: .pass
            case .missing, .unsupported: .empty
            case .stub: .fail
            }
        }
    }
}
