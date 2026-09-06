public import Foundation

/// `packtool validate` 의 산출물이자 `lessongen repair` 의 입력. **두 실행 파일이 공유하는
/// 유일한 계약**이라 별도 타깃에 둔다.
///
/// 리포트가 존재하는 이유는 하나다 — AI 가 생성한 레슨을 사람이 아니라 **기계가** 검증하고,
/// 실패했을 때 그 원문을 다시 모델에게 돌려주기 위해서다. 그래서 "무엇이 실패했나" 만으로는
/// 부족하고 **러너가 실제로 뱉은 것**이 그대로 실려야 한다.
public struct PackValidationReport: Hashable, Sendable, Codable {
    /// 이 스키마 자체의 버전. `lessongen` 이 모르는 버전을 만나면 조용히 오해하지 않고 멈춘다.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var packID: String
    public var packVersion: String
    /// 검증을 돌린 시각(epoch ms UTC).
    public var validatedAt: Int64
    /// 어느 단계까지 실제로 돌았는가. 툴체인이 없어 실행 게이트를 건너뛰었으면 여기 남는다.
    public var stagesRun: [Stage]
    public var lessons: [LessonResult]

    public init(
        schemaVersion: Int = PackValidationReport.currentSchemaVersion,
        packID: String,
        packVersion: String,
        validatedAt: Int64,
        stagesRun: [Stage],
        lessons: [LessonResult]
    ) {
        self.schemaVersion = schemaVersion
        self.packID = packID
        self.packVersion = packVersion
        self.validatedAt = validatedAt
        self.stagesRun = stagesRun
        self.lessons = lessons
    }

    /// 검증 단계. 뒤로 갈수록 비싸고, 앞 단계가 실패하면 뒤는 돌지 않는다.
    public enum Stage: String, Hashable, Sendable, Codable, CaseIterable {
        /// 매니페스트 디코딩·sha256 대조·참조 파일 존재.
        case structural
        /// 디렉티브 파싱과 6블록 순서.
        case syntax
        /// 정답 키가 실제 선택지에 있는가 같은 의미 검사.
        case semantic
        /// 실제 `CodeRunner` 로 예제·과제를 돌린다. **툴체인이 필요한 유일한 단계.**
        case execution
    }

    public var isClean: Bool { lessons.allSatisfy(\.failures.isEmpty) }
    public var failedLessons: [LessonResult] { lessons.filter { !$0.failures.isEmpty } }

    /// 실행 게이트가 실제로 돌았는가. 안 돌았으면 "통과" 를 통과로 읽으면 안 된다.
    public var executionStageRan: Bool { stagesRun.contains(.execution) }
}

extension PackValidationReport {
    public struct LessonResult: Hashable, Sendable, Codable {
        /// 콘텐츠가 갱신돼도 바뀌지 않는 식별자. `lessongen repair` 가 이걸로 재생성 대상을 찾는다.
        public var stableID: String
        public var language: String
        public var title: String
        public var failures: [Failure]

        public init(stableID: String, language: String, title: String, failures: [Failure]) {
            self.stableID = stableID
            self.language = language
            self.title = title
            self.failures = failures
        }
    }

    public struct Failure: Hashable, Sendable, Codable {
        public var stage: Stage
        public var kind: Kind
        /// 어느 블록에서. 레슨 전체 문제면 nil.
        public var blockID: String?
        /// 사람이 읽는 한 줄.
        public var summary: String
        /// **러너·파서가 실제로 뱉은 것.** 요약하지 말고 그대로 실어라 — 이걸 모델에게
        /// 돌려주는 것이 `lessongen repair` 의 전부다.
        public var evidence: String?
        /// 소스 위치를 알면. 디렉티브 파싱 실패가 여기 온다.
        public var line: Int?
        public var column: Int?

        public init(
            stage: Stage,
            kind: Kind,
            blockID: String? = nil,
            summary: String,
            evidence: String? = nil,
            line: Int? = nil,
            column: Int? = nil
        ) {
            self.stage = stage
            self.kind = kind
            self.blockID = blockID
            self.summary = summary
            self.evidence = evidence
            self.line = line
            self.column = column
        }

        /// 실패의 종류. `lessongen repair` 가 프롬프트를 고르는 기준이라 **모델이 무엇을
        /// 고쳐야 하는지**로 나눈다 — 어느 코드가 던졌는지가 아니라.
        public enum Kind: String, Hashable, Sendable, Codable, CaseIterable {
            /// 매니페스트·파일 참조가 어긋남.
            case brokenReference
            /// 디렉티브 문법이 깨짐.
            case malformedDirective
            /// 6블록 순서·구성 위반.
            case blockStructure
            /// 퀴즈 정답 키가 선택지에 없는 등 의미 오류.
            case inconsistentAnswer
            /// 예제가 컴파일·실행되지 않음.
            case exampleFailedToRun
            /// 예제 출력이 기대 사이드카와 다름.
            case exampleOutputMismatch
            /// 과제 정답이 숨은 테스트를 통과하지 못함.
            case solutionFailsTests
            /// **starter 가 이미 숨은 테스트를 통과한다** — 과제가 무의미하다는 뜻이고,
            /// 값싼 모델이 가장 자주 만드는 실패다.
            case starterAlreadyPasses
        }
    }
}

extension PackValidationReport {
    /// 정규 JSON. 키 정렬과 들여쓰기를 고정해 두 번 쓴 결과가 바이트 동일하게 한다 —
    /// CI 가 리포트를 diff 로 비교할 수 있어야 한다.
    public func canonicalJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> PackValidationReport {
        let report = try JSONDecoder().decode(PackValidationReport.self, from: data)
        guard report.schemaVersion == currentSchemaVersion else {
            throw ReportError.unsupportedSchemaVersion(
                found: report.schemaVersion,
                supported: currentSchemaVersion
            )
        }
        return report
    }
}

public enum ReportError: Error, Hashable, Sendable, CustomStringConvertible {
    case unsupportedSchemaVersion(found: Int, supported: Int)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            "리포트 스키마 v\(found) 를 읽을 수 없습니다. 이 도구는 v\(supported) 를 압니다."
        }
    }
}
