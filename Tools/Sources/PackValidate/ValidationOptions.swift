public import Foundation
public import LanguageKit

/// `packtool validate` 한 번의 설정.
public struct ValidationOptions: Sendable {
    /// 실행 게이트를 태울지. 끄면 `stagesRun` 에서 `.execution` 이 빠진다.
    public var runExecution: Bool

    /// 툴체인이 없을 때 실행 게이트를 **건너뛴다**.
    ///
    /// 기본이 `false` 인 것이 이 게이트의 핵심 규약이다. 툴체인이 없다고 조용히 통과시키면
    /// "실행 게이트가 돌지 않은 clean" 이 만들어지고, CI 는 그걸 통과로 읽는다. 켜더라도
    /// 건너뛴 사실은 `stagesRun` 에서 `.execution` 을 빼는 것으로 리포트에 남는다.
    public var allowMissingToolchain: Bool

    /// 동시에 태울 블록 수. Swift 과제 채점은 이것과 무관하게 직렬화된다
    /// (SwiftPM 템플릿 하나를 공유하기 때문 — ``SwiftTemplateLocation`` 참조).
    public var maxConcurrency: Int

    /// 사용자 코드에 거는 상한.
    ///
    /// `outputBytes` 를 기본값(1MB)보다 낮춰 잡은 이유는 리포트 때문이다. 실패 증거에는
    /// 러너 원문이 **요약 없이** 실려야 하는데, 상한이 1MB 면 리포트 하나가 메가바이트가
    /// 된다. 러너 층에서 자르면 `RunEvent.truncated` 가 함께 오므로 "잘렸다"는 사실이
    /// 증거에 남는다 — 우리가 몰래 요약하는 것과 다르다.
    public var limits: ResourceLimits

    /// Swift 과제 채점이 쓸 SwiftPM 템플릿 디렉터리. nil 이면 팩 경로에서 유도한다.
    public var swiftTemplateDirectory: URL?

    /// 리포트의 `validatedAt`. nil 이면 지금.
    public var validatedAt: Int64?

    public init(
        runExecution: Bool = true,
        allowMissingToolchain: Bool = false,
        maxConcurrency: Int = ValidationOptions.defaultConcurrency,
        limits: ResourceLimits = ValidationOptions.defaultLimits,
        swiftTemplateDirectory: URL? = nil,
        validatedAt: Int64? = nil
    ) {
        self.runExecution = runExecution
        self.allowMissingToolchain = allowMissingToolchain
        self.maxConcurrency = max(1, maxConcurrency)
        self.limits = limits
        self.swiftTemplateDirectory = swiftTemplateDirectory
        self.validatedAt = validatedAt
    }

    /// 코어 절반. `swiftc` 가 도는 동안에도 머신이 다른 일을 할 수 있어야 한다.
    public static var defaultConcurrency: Int {
        max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
    }

    public static let defaultLimits = ResourceLimits(outputBytes: 256 << 10)
}
