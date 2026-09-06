public import Foundation

/// 모델 식별자.
///
/// **비밀이 아니다 — 오히려 로그에 반드시 남아야 한다.** 어떤 모델이 무엇을 만들었는지
/// 모르면 생성물을 재현할 수도, 회귀를 짚을 수도 없다 (`{#lessongen-runlog}`).
/// 그래서 ``APIKey`` 와 정반대로 `Codable` 이고 `description` 이 값을 그대로 돌려준다.
public struct ModelID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    /// 모델을 담는 환경변수.
    public static let environmentVariableName = "OPENROUTER_MODEL"

    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public var description: String { rawValue }
}

extension ModelID {
    /// 환경변수(또는 `.env`)에서 읽는다.
    ///
    /// **기본값을 두지 않는다.** 근거 셋:
    ///
    /// 1. OpenRouter 는 모델 수백 종을 같은 엔드포인트 뒤에 세워 두고, 구조화 출력
    ///    (`response_format: json_schema`) 지원 여부가 **모델·업스트림 공급자마다 다르다.**
    ///    우리가 고른 기본값이 그 기능을 안 갖고 있으면 파이프라인 한참 뒤에서
    ///    깨진다 — 실패 지점이 원인에서 멀어진다.
    /// 2. 모델마다 가격이 두 자릿수 배로 다르다. 조용한 기본값은 조용한 청구서다.
    /// 3. 요청에서 모델을 아예 빼면 라우터가 알아서 고른다. 그건 실행마다 다른 모델이
    ///    답할 수 있다는 뜻이고, 재현 로그의 전제를 무너뜨린다.
    ///
    /// 그래서 없으면 **던진다.** CLI 는 `--model` 플래그로 덮을 수 있다 — 모델 문자열은
    /// 비밀이 아니므로 키와 달리 플래그로 받아도 된다.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws(ModelIDError) -> ModelID {
        guard let raw = environment[environmentVariableName] else { throw .notSet }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        return ModelID(trimmed)
    }
}

public enum ModelIDError: Error, Sendable, Hashable {
    case notSet
    case empty
}

extension ModelIDError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notSet:
            """
            \(ModelID.environmentVariableName) 가 설정되어 있지 않습니다.

              export \(ModelID.environmentVariableName)="vendor/model-name"

            기본 모델을 두지 않는 것은 의도입니다 — 모델마다 구조화 출력 지원과 가격이
            달라서, 조용히 고른 모델은 조용한 실패이거나 조용한 청구서입니다.
            --model 플래그로도 지정할 수 있습니다.
            """
        case .empty:
            "\(ModelID.environmentVariableName) 가 비어 있습니다."
        }
    }
}
