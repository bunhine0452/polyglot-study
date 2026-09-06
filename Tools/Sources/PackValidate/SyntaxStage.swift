internal import ContentKit
internal import LearnCore
internal import Foundation
internal import PackReport

/// 파싱을 통과한 레슨 하나. 실행 게이트는 이것만 받는다.
struct ParsedLesson: Sendable {
    var entry: PackManifest.LessonEntry
    var document: LessonDocument
}

/// 문법 단계 — 디렉티브 파싱과 6블록 순서, 그리고 디렉티브가 가리키는 사이드카의 존재.
///
/// 사이드카 존재 검사가 여기 있는 이유는 순서 때문이다. `@Task(starter: …)` 가 어떤
/// 파일을 가리키는지는 **본문을 파싱해야만** 알 수 있어서 구조 단계에서는 볼 수 없다.
/// 검사의 성격은 구조(참조)이므로 실패는 `.structural` 단계로 보고한다 — 어디서
/// 발견했는가가 아니라 무엇이 깨졌는가로 나누는 것이 리포트 계약의 원칙이다.
enum SyntaxStage {
    static func run(pack: ContentPack, into table: inout FailureTable) -> [ParsedLesson] {
        let registered = Set(pack.manifest.files.map(\.path))
        var parsed: [ParsedLesson] = []

        for entry in pack.manifest.lessons {
            let id = entry.stableID.rawValue
            let source: String
            do {
                source = try pack.lessonSource(entry.stableID)
            } catch {
                table.add(
                    .init(
                        stage: .structural, kind: .brokenReference,
                        summary: "레슨 본문을 읽을 수 없다: \(entry.path)",
                        evidence: "\(error)"),
                    to: id)
                continue
            }

            let document: LessonDocument
            do {
                document = try LessonParser.parseDocument(
                    source: source,
                    stableID: entry.stableID,
                    language: entry.language,
                    path: try? PackRelativePath(validating: entry.path)
                )
            } catch {
                table.add(ParseFailureClassifier.failure(from: error), to: id)
                continue
            }

            checkReferences(
                document, entry: entry, registered: registered, pack: pack, into: &table)
            parsed.append(ParsedLesson(entry: entry, document: document))
        }
        return parsed
    }

    private static func checkReferences(
        _ document: LessonDocument,
        entry: PackManifest.LessonEntry,
        registered: Set<String>,
        pack: ContentPack,
        into table: inout FailureTable
    ) {
        let id = entry.stableID.rawValue
        for path in document.referencedFiles {
            guard registered.contains(path.rawValue) else {
                table.add(
                    .init(
                        stage: .structural, kind: .brokenReference,
                        summary: "레슨이 참조하는 \(path.rawValue) 가 매니페스트 files 에 없다",
                        evidence: "레슨 \(id) 의 디렉티브 인자가 가리키는 경로다"),
                    to: id)
                continue
            }
            let url = pack.url(for: path)
            if !FileManager.default.fileExists(atPath: url.path) {
                table.add(
                    .init(
                        stage: .structural, kind: .brokenReference,
                        summary: "레슨이 참조하는 \(path.rawValue) 가 디스크에 없다",
                        evidence: url.path),
                    to: id)
            }
        }
    }
}
