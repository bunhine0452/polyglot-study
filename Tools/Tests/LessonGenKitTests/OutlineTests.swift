import LLMKit
import Foundation
import LearnCore
import LessonGenKit
import TestSupport
import Testing

@Suite("트랙 개요 — 스키마·조립·검증")
struct OutlineTests {
    private func makeDraft() throws -> OutlineDraft {
        try JSONDecoder().decode(OutlineDraft.self, from: Data(Fixtures.outlineDraftJSON.utf8))
    }

    // MARK: - 스키마

    @Test("구조화 출력 스키마가 API 요구사항을 만족한다")
    func schemaShape() throws {
        guard case .object(let root) = OutlineDraft.jsonSchema else {
            Issue.record("루트가 객체가 아닙니다.")
            return
        }
        #expect(root["type"] == JSONValue.string("object"))
        #expect(root["additionalProperties"] == JSONValue.bool(false))
        #expect(root["required"] == JSONValue.array(["trackTitle", "trackSummary", "lessons"]))

        guard case .object(let lesson) = OutlineDraft.lessonSchema,
              case .array(let required) = lesson["required"]
        else {
            Issue.record("레슨 스키마가 예상 모양이 아닙니다.")
            return
        }
        #expect(lesson["additionalProperties"] == JSONValue.bool(false))
        // required 가 properties 를 빠짐없이 덮어야 한다.
        guard case .object(let properties) = lesson["properties"] else {
            Issue.record("properties 가 없습니다.")
            return
        }
        let requiredNames = Set(required.compactMap { value -> String? in
            if case .string(let name) = value { return name }
            return nil
        })
        #expect(requiredNames == Set(properties.keys))
    }

    @Test("스키마가 Swift 초안 타입과 실제로 맞는다")
    func schemaMatchesDraftType() throws {
        // 스키마의 필드명이 Codable 키와 어긋나면 여기서 잡힌다.
        let draft = try makeDraft()
        guard case .object(let lesson) = OutlineDraft.lessonSchema,
              case .object(let properties) = lesson["properties"]
        else {
            Issue.record("레슨 스키마가 예상 모양이 아닙니다.")
            return
        }
        let encoded = try JSONEncoder().encode(draft.lessons[0])
        let json = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(json.keys) == Set(properties.keys))
    }

    // MARK: - 조립

    @Test("stableID 는 언어 접두사와 슬러그로 조립되고 순번을 담지 않는다")
    func assemblesStableIDs() throws {
        let outline = try OutlineAssembler.assemble(
            draft: makeDraft(),
            language: .python,
            generatorModel: Fixtures.testModel
        )
        #expect(outline.lessons.map(\.stableID.rawValue) == ["python.hello-stdout", "python.list-comprehension"])
        #expect(outline.lessons.map(\.ordinal) == [1, 2])
        #expect(outline.lessons[1].prerequisites == [LessonID("python.hello-stdout")])
        #expect(outline.lessons[0].prerequisites.isEmpty)
        #expect(outline.language == .python)
        #expect(outline.generatorModel == Fixtures.testModel)
        #expect(outline.schemaVersion == TrackOutline.currentSchemaVersion)
        // 순번이 ID 에 들어가면 레슨을 끼워 넣을 때마다 진도가 고아가 된다.
        #expect(outline.lessons.allSatisfy { !$0.stableID.rawValue.contains("\($0.ordinal)") })
    }

    @Test("모델이 뒤를 가리키는 선수 레슨을 내놓으면 조립에서 걸린다")
    func rejectsForwardPrerequisite() throws {
        var draft = try makeDraft()
        draft.lessons[0].prerequisiteSlugs = ["list-comprehension"]
        #expect(throws: OutlineAssemblyError.forwardPrerequisite(
            lesson: "hello-stdout", prerequisite: "list-comprehension"
        )) {
            try OutlineAssembler.assemble(draft: draft, language: .python, generatorModel: "m")
        }
    }

    @Test("없는 선수 레슨과 중복 슬러그도 조립에서 걸린다")
    func rejectsBadSlugs() throws {
        var missing = try makeDraft()
        missing.lessons[1].prerequisiteSlugs = ["없는-레슨"]
        #expect(throws: OutlineAssemblyError.unknownPrerequisite(
            lesson: "list-comprehension", prerequisite: "없는-레슨"
        )) {
            try OutlineAssembler.assemble(draft: missing, language: .python, generatorModel: "m")
        }

        var duplicate = try makeDraft()
        duplicate.lessons[1].slug = "hello-stdout"
        #expect(throws: OutlineAssemblyError.duplicateSlug("hello-stdout")) {
            try OutlineAssembler.assemble(draft: duplicate, language: .python, generatorModel: "m")
        }
    }

    // MARK: - 검증

    @Test("정상 개요에는 지적이 없다")
    func validOutlineHasNoIssues() throws {
        let outline = try OutlineAssembler.assemble(
            draft: makeDraft(), language: .python, generatorModel: "claude-opus-5"
        )
        #expect(OutlineValidator.validate(outline).isEmpty)
    }

    @Test("stableID 접두사가 틀리면 잡는다")
    func catchesWrongPrefix() throws {
        var outline = try OutlineAssembler.assemble(
            draft: makeDraft(), language: .python, generatorModel: "m"
        )
        outline.lessons[0].stableID = LessonID("ruby.hello-stdout")
        let issues = OutlineValidator.validate(outline)
        #expect(issues.contains { $0.path == "lessons[0].stableID" })
    }

    @Test("순번 어긋남·중복 ID·빈 학습목표·자기참조를 각각 잡는다")
    func catchesStructuralDefects() throws {
        var outline = try OutlineAssembler.assemble(
            draft: makeDraft(), language: .python, generatorModel: "m"
        )
        outline.lessons[1].ordinal = 5
        outline.lessons[1].objectives = []
        outline.lessons[0].stableID = outline.lessons[1].stableID
        outline.lessons[0].prerequisites = [outline.lessons[0].stableID]

        let paths = Set(OutlineValidator.validate(outline).map(\.path))
        #expect(paths.contains("lessons[1].ordinal"))
        #expect(paths.contains("lessons[1].objectives"))
        #expect(paths.contains("lessons[1].stableID"))
        #expect(paths.contains("lessons[0].prerequisites[0]"))
    }

    @Test("레슨이 없으면 그것만 지적하고 멈춘다")
    func emptyLessons() {
        let outline = TrackOutline(
            language: .swift,
            trackTitle: "제목",
            trackSummary: "요약",
            generatorModel: "m",
            lessons: []
        )
        let issues = OutlineValidator.validate(outline)
        #expect(issues.count == 1)
        #expect(issues[0].path == "lessons")
    }

    @Test("슬러그 판정")
    func kebabIdentifier() {
        #expect(OutlineValidator.isKebabIdentifier("list-comprehension"))
        #expect(OutlineValidator.isKebabIdentifier("python3"))
        #expect(!OutlineValidator.isKebabIdentifier(""))
        #expect(!OutlineValidator.isKebabIdentifier("List-Comprehension"))
        #expect(!OutlineValidator.isKebabIdentifier("list--comprehension"))
        #expect(!OutlineValidator.isKebabIdentifier("-list"))
        #expect(!OutlineValidator.isKebabIdentifier("list_comprehension"))
        #expect(!OutlineValidator.isKebabIdentifier("리스트"))
    }

    // MARK: - 파일

    @Test("파일 이름과 인코딩이 결정적이다")
    func fileEncoding() throws {
        let outline = try OutlineAssembler.assemble(
            draft: makeDraft(), language: .python, generatorModel: "claude-opus-5"
        )
        #expect(OutlineFile.fileName(for: .python) == "python.outline.json")

        let first = try OutlineFile.encode(outline)
        for _ in 0..<10 {
            #expect(try OutlineFile.encode(outline) == first)
        }
        #expect(first.last == 0x0A)
        // 시각이 들어가면 매번 diff 가 생긴다 — 들어가지 않는다.
        let text = String(decoding: first, as: UTF8.self)
        #expect(!text.contains("generatedAt"))
        #expect(!text.contains("timestamp"))
        // 왕복.
        #expect(try OutlineFile.decode(first) == outline)
    }

    @Test("디렉터리를 만들고 tracks/<lang>.outline.json 을 쓴다")
    func writesFile() throws {
        let outline = try OutlineAssembler.assemble(
            draft: makeDraft(), language: .python, generatorModel: "claude-opus-5"
        )
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("outline-test-\(UUID().uuidString)/tracks", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let written = try OutlineFile.write(outline, toDirectory: directory)
        #expect(written.lastPathComponent == "python.outline.json")
        #expect(try OutlineFile.decode(Data(contentsOf: written)) == outline)
    }
}
