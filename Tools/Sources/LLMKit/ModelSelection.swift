public import Foundation

/// 생성 파이프라인의 단계.
///
/// 단계를 나누는 기준은 도메인이 아니라 **검증 게이트의 유무**다.
///
/// `packtool validate` 는 코드만 본다 — 예제가 컴파일되는지, solution 이 숨은 테스트를
/// 통과하고 starter 는 실패하는지. 그래서 값싼 모델이 코드를 틀려도 게이트가 잡고
/// `lessongen repair` 가 돌아 수렴한다. **틀림이 비싸지 않다.**
///
/// 개념 설명 산문에는 그런 게이트가 없다. 컴파일되는 코드 옆에 사실이 틀린 한국어
/// 설명이 붙어도 모든 단계를 통과하고 학습자에게 그대로 간다. 학습 앱에서 이것이 가장
/// 나쁜 실패다 — 학습자는 틀린 설명을 검증할 수단이 없기 때문에 배우려던 것을 잘못
/// 배운다. 그래서 산문은 다른(더 좋은) 모델로 보낼 수 있어야 한다.
public enum GenerationStage: String, CaseIterable, Sendable, Hashable {
    /// 트랙 개요. 사람이 눈으로 리뷰하고 커밋한다 — 사람이 게이트다.
    case outline
    /// 레슨의 코드·구조(예제·starter·solution·테스트). `packtool` 이 실행해서 검증한다.
    case lesson
    /// 개념 설명·회고 등 **산문**. 자동 게이트가 없다.
    ///
    /// `lessongen lesson` 이 산문과 코드를 분리 생성하게 되는 날 이 단계가 쓰인다.
    /// 지금은 배선과 로그만 있고 분리 생성은 `{#lessongen-lesson}` 의 일이다.
    case prose
    /// 실패한 레슨 재생성. 실패 원문을 물고 다시 도는 루프라 게이트가 다시 잡는다.
    case repair

    /// 오버라이드 환경변수 이름.
    public var environmentVariableName: String {
        "\(ModelID.environmentVariableName)_\(rawValue.uppercased())"
    }

    /// 이 단계의 산출물을 기계가 검증하는가.
    ///
    /// 모델을 고를 때 읽는 값이다 — 게이트가 없는 단계에 값싼 모델을 꽂는 것은
    /// 검증되지 않은 주장을 학습자에게 그대로 내보내는 것과 같다.
    public var isMachineVerified: Bool {
        switch self {
        case .lesson, .repair: true
        case .outline, .prose: false
        }
    }
}

/// 단계별로 어떤 모델을 쓸지 결정한다.
///
/// 우선순위: **명시 인자 > 단계별 환경변수 > 기본 환경변수**. 어느 단계가 어느 모델로
/// 갔는지는 실행 로그에 남아야 한다 (`{#lessongen-runlog}`) — 나중에 "이 레슨은 어느
/// 모델이 썼나" 를 되짚을 수 있어야 하기 때문이다.
public struct ModelSelection: Sendable, Hashable {
    /// 오버라이드가 없는 단계가 쓸 모델.
    public let base: ModelID
    /// 단계별 오버라이드.
    public let overrides: [GenerationStage: ModelID]

    public init(base: ModelID, overrides: [GenerationStage: ModelID] = [:]) {
        self.base = base
        self.overrides = overrides
    }

    /// 이 단계가 실제로 쓸 모델.
    public func model(for stage: GenerationStage) -> ModelID {
        overrides[stage] ?? base
    }

    /// 이 단계의 모델이 어디서 왔는지. 로그용 — 값이 아니라 출처를 남긴다.
    public func origin(for stage: GenerationStage) -> String {
        overrides[stage] != nil ? stage.environmentVariableName : ModelID.environmentVariableName
    }

    /// 환경에서 조립한다. 기본 모델이 없으면 던진다 (``ModelID/fromEnvironment(_:)`` 참고).
    ///
    /// - Parameter override: `--model` 플래그. 있으면 **기본 모델을** 덮는다. 단계별
    ///   오버라이드는 그대로 살아 있다 — 플래그 하나로 파이프라인 전체를 한 모델로
    ///   눌러 버리면 게이트 없는 단계를 좋은 모델에 보내려던 설정이 조용히 사라진다.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        override: ModelID? = nil
    ) throws(ModelIDError) -> ModelSelection {
        let base: ModelID
        if let override {
            base = override
        } else {
            base = try ModelID.fromEnvironment(environment)
        }
        var overrides: [GenerationStage: ModelID] = [:]
        for stage in GenerationStage.allCases {
            guard let raw = environment[stage.environmentVariableName] else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            overrides[stage] = ModelID(trimmed)
        }
        return ModelSelection(base: base, overrides: overrides)
    }

    /// 실행 로그 한 줄. 단계 → 모델 전량. **비밀값이 없다** — 모델 문자열은 비밀이 아니다.
    public var logLine: String {
        let entries = GenerationStage.allCases.map { stage in
            "\(stage.rawValue)=\(model(for: stage).rawValue)"
        }
        return entries.joined(separator: " ")
    }
}
