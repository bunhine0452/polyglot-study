import ContentKit
import Foundation
import LanguageKit
import LearnCore

@testable import LessonFeature

/// 리포 안의 고정 경로. `Bundle.module` 을 쓰지 않는 이유는 `Package.swift` 에 손대지
/// 않기로 했기 때문이다(`LessonFeatureTests` 에 `resources:` 선언이 없다).
/// `#filePath` 는 컴파일 시점에 박히므로 소스가 있는 개발·CI 환경에서 결정적이다.
nonisolated enum RepoPaths {
    /// `<repo>/` — 이 파일에서 다섯 단계 위.
    static var root: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }

    /// 리포에 커밋된 샘플 팩. **목 데이터를 만들지 않는다** — 화면 테스트가 보는 레슨은
    /// `packtool` 과 앱이 보는 것과 같은 파일이다.
    static var samplePack: URL {
        root.appendingPathComponent("Content/fixtures/polyglot-mvp", isDirectory: true)
    }
}

enum SampleLesson {
    // 이 테스트 타깃의 기본 격리는 `MainActor` 다(`Package.swift` 의 `uiSettings`).
    // `@Test(arguments:)` 는 격리 밖에서 인자를 읽으므로 이 상수들은 nonisolated 여야 한다.
    nonisolated static let swift = LessonID("swift-0001-optional")
    nonisolated static let python = LessonID("py-0001-fstring")
    nonisolated static let sql = LessonID("sql-0001-aggregate")
    nonisolated static let all: [LessonID] = [python, sql, swift]

    nonisolated static func pack() throws -> ContentPack {
        try ContentPack(directory: RepoPaths.samplePack)
    }

    nonisolated static func content(_ id: LessonID) throws -> LessonContent {
        try LessonContent.load(pack: pack(), lessonID: id)
    }

    @MainActor
    static func model(
        _ id: LessonID = swift,
        events: [RunEvent]? = nil,
        onOpenEditor: ((TaskBlock) -> Void)? = nil
    ) throws -> LessonModel {
        LessonModel(
            content: try content(id),
            runFactory: events.map { FakeRunner.factory(yielding: $0) },
            onOpenEditor: onOpenEditor
        )
    }
}

/// 프로세스를 띄우지 않는 러너. **실행 경로의 사건 순서만** 재현한다 — 실제 러너의
/// 계약은 `RunnerKitTests` 가 이미 검증했고, 여기서 다시 태우면 화면 테스트가
/// 툴체인 유무에 매달린다.
enum FakeRunner {
    static func factory(yielding events: [RunEvent])
        -> @Sendable (LanguageID, RunRequest) -> AsyncThrowingStream<RunEvent, any Error>
    {
        { _, _ in
            AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    static func failing(_ error: any Error)
        -> @Sendable (LanguageID, RunRequest) -> AsyncThrowingStream<RunEvent, any Error>
    {
        { _, _ in
            AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    /// stdout 한 덩어리를 내고 0으로 끝나는 실행.
    static func succeeding(stdout: String, durationMilliseconds: Int = 12) -> [RunEvent] {
        [
            .phase(.preparing),
            .phase(.running),
            .standardOutput(Data(stdout.utf8)),
            .finished(RunTermination.exitCode(0, durationMilliseconds: durationMilliseconds)),
        ]
    }
}
