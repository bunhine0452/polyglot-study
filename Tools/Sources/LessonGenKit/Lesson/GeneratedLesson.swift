public import ContentKit
public import LearnCore

/// 디스크에 놓일 준비가 끝난 레슨 하나.
///
/// 마크다운과 사이드카 넷이 **한 값**으로 묶여 있는 것이 요점이다. 레슨 본문만 쓰고
/// `tests/` 를 빠뜨리면 매니페스트가 없는 파일을 가리키게 되고, 그 사실은 설치할 때에야
/// 드러난다. 묶어 두면 부분적으로 쓰이는 경로가 없다.
public struct GeneratedLesson: Hashable, Sendable {
    public var stableID: LessonID
    public var language: LessonLanguage
    public var title: String
    public var order: Int
    public var objectives: [String]
    public var prerequisites: [LessonID]
    public var paths: LessonPaths
    /// 디렉티브 마크다운. 이미 `LessonParser` 를 통과한 것이다.
    public var markdown: String
    public var expectedStdout: String
    public var starterCode: String
    public var testsCode: String
    public var solutionCode: String
    /// 실제로 답한 모델. 요청한 모델이 아니다 — 라우터가 갈아탈 수 있다.
    public var generatorModel: String
    /// 응답이 말한 업스트림. 같은 모델도 업스트림이 다르면 결과가 달라진다(fp4/fp8).
    public var upstreamProvider: String?

    public init(
        stableID: LessonID,
        language: LessonLanguage,
        title: String,
        order: Int,
        objectives: [String],
        prerequisites: [LessonID],
        paths: LessonPaths,
        markdown: String,
        expectedStdout: String,
        starterCode: String,
        testsCode: String,
        solutionCode: String,
        generatorModel: String,
        upstreamProvider: String? = nil
    ) {
        self.stableID = stableID
        self.language = language
        self.title = title
        self.order = order
        self.objectives = objectives
        self.prerequisites = prerequisites
        self.paths = paths
        self.markdown = markdown
        self.expectedStdout = expectedStdout
        self.starterCode = starterCode
        self.testsCode = testsCode
        self.solutionCode = solutionCode
        self.generatorModel = generatorModel
        self.upstreamProvider = upstreamProvider
    }

    /// 팩에 놓일 파일 다섯. 경로 사전순.
    public var files: [(path: PackRelativePath, contents: String)] {
        [
            (paths.lesson, markdown),
            (paths.expected, expectedStdout),
            (paths.starter, starterCode),
            (paths.tests, testsCode),
            (paths.solution, solutionCode),
        ].sorted { $0.0 < $1.0 }
    }

    public var manifestEntry: PackManifest.LessonEntry {
        PackManifest.LessonEntry(
            stableID: stableID,
            language: language.id,
            title: title,
            order: order,
            path: paths.lesson.rawValue,
            objectives: objectives,
            prerequisites: prerequisites)
    }

    public var lockEntry: StableIDLock.Entry {
        StableIDLock.Entry(
            stableID: stableID, language: language.id, path: paths.lesson.rawValue)
    }
}

/// 개요 한 칸 + 모델 초안 → ``GeneratedLesson``.
public enum LessonAssembler {
    /// - Parameters:
    ///   - outline: 개요의 레슨 칸. 제목·순번·학습목표·선수 레슨이 여기서 온다 —
    ///     모델에게 다시 물어보지 않는다. 사람이 리뷰해 커밋한 값이기 때문이다.
    public static func assemble(
        draft: LessonContentDraft,
        outline: LessonOutline,
        language: LessonLanguage,
        generatorModel: String,
        upstreamProvider: String? = nil
    ) throws -> GeneratedLesson {
        let stableID = PackLessonID.fromOutline(outline.stableID)
        guard PackLessonID.isPackSlug(stableID.rawValue) else {
            throw LessonAssemblyError.invalidStableID(stableID.rawValue)
        }
        let paths = try LessonPaths(stableID: stableID, language: language)
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: stableID, language: language, paths: paths)

        return GeneratedLesson(
            stableID: stableID,
            language: language,
            title: outline.title,
            order: outline.ordinal,
            objectives: outline.objectives,
            prerequisites: outline.prerequisites.map(PackLessonID.fromOutline),
            paths: paths,
            markdown: markdown,
            // 기대 stdout 은 **바이트로** 대조되므로 줄 끝 공백을 떼고 개행 하나로 끝낸다.
            // 정규화 지점이 하나여야 러너와 사이드카가 어긋나지 않는다.
            expectedStdout: DirectiveWriter.normalizeLineEndings(draft.example.expectedStdout)
                .trimmedTrailingNewlines() + "\n",
            starterCode: try DirectiveWriter.normalizedCode(
                draft.task.starterCode, context: "starter"),
            testsCode: try DirectiveWriter.normalizedCode(draft.task.testsCode, context: "tests"),
            solutionCode: try DirectiveWriter.normalizedCode(
                draft.task.solutionCode, context: "solution"),
            generatorModel: generatorModel,
            upstreamProvider: upstreamProvider)
    }
}

public enum LessonAssemblyError: Error, Hashable, Sendable, CustomStringConvertible {
    case invalidStableID(String)

    public var description: String {
        switch self {
        case .invalidStableID(let raw):
            "팩 매니페스트가 받을 수 없는 stableID 입니다: \(raw) (소문자·숫자·하이픈만)"
        }
    }
}
