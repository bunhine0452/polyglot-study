import Foundation

/// 고의로 망가뜨린 팩 열 가지.
///
/// 정상 팩 하나를 복사한 뒤 한 곳씩 깨뜨린다. 완료 기준은
/// **열 가지가 서로 다른 메시지로 실패하는 것**이다
/// (`StructuralStageTests.brokenFixturesFailWithDistinctMessages`).
enum BrokenPack: String, CaseIterable, Sendable {
    /// `manifest.json` 이 아예 없다.
    case manifestMissing
    /// `manifest.json` 이 JSON 이 아니다.
    case manifestUndecodable
    /// 두 레슨의 `stableID` 가 같다.
    case duplicateLessonID
    /// `files[].path` 가 팩 밖을 가리킨다.
    case pathEscape
    /// `files` 에 등록된 파일이 디스크에 없다.
    case registeredFileMissing
    /// 매니페스트의 `bytes` 가 실제와 다르다.
    case sizeMismatch
    /// 내용이 바뀌어 sha256 이 어긋난다 (크기는 같다).
    case checksumMismatch
    /// 레슨이 참조하는 사이드카가 `files` 에도 디스크에도 없다.
    case unregisteredReference
    /// 디렉티브 문법이 깨졌다 (한 줄 중괄호 본문).
    case malformedDirective
    /// `stableids.lock` 이 개명을 기록하고 있다.
    case lockRename

    /// 임시 디렉터리에 깨진 팩을 만든다. 호출자가 ``PackEditor/discard()`` 로 지운다.
    func materialize() throws -> PackEditor {
        let pack = try PackEditor.copyOfValidPack(label: rawValue)
        switch self {
        case .manifestMissing:
            try pack.delete("manifest.json")

        case .manifestUndecodable:
            try pack.corrupt("manifest.json", with: "{ \"schemaVersion\": ")

        case .duplicateLessonID:
            try pack.editManifest { manifest in
                guard var lessons = manifest["lessons"] as? [[String: Any]], lessons.count >= 2
                else { return }
                lessons[1]["stableID"] = lessons[0]["stableID"]
                manifest["lessons"] = lessons
            }

        case .pathEscape:
            try pack.editManifest { manifest in
                guard var files = manifest["files"] as? [[String: Any]], !files.isEmpty else { return }
                files[0]["path"] = "../escape.md"
                manifest["files"] = files
            }

        case .registeredFileMissing:
            try pack.delete("starters/fx-0001-echo.py")

        case .sizeMismatch:
            try pack.editManifest { manifest in
                PackEditor.mutateFileEntry(&manifest, path: "expected/fx-0001-echo-run.txt") {
                    $0["bytes"] = (($0["bytes"] as? Int) ?? 0) + 7
                }
            }

        case .checksumMismatch:
            // 크기는 그대로 두고 내용만 바꾼다 — 크기가 아니라 해시로 잡혀야 한다.
            try pack.corrupt("expected/fx-0001-echo-run.txt", with: "hello fixturX\n")

        case .unregisteredReference:
            try pack.delete("tests/fx-0001-echo.py")
            try pack.editManifest { manifest in
                guard let files = manifest["files"] as? [[String: Any]] else { return }
                manifest["files"] = files.filter {
                    ($0["path"] as? String) != "tests/fx-0001-echo.py"
                }
            }

        case .malformedDirective:
            let original = try pack.text(at: "lessons/fx-0001-echo.md")
            try pack.replace(
                "lessons/fx-0001-echo.md",
                with: "@Concept(id: stray) { 한 줄 본문 }\n\n" + original)

        case .lockRename:
            let original = try pack.text(at: "stableids.lock")
            try pack.replace(
                "stableids.lock",
                with: original.replacingOccurrences(
                    of: "fx-0001-echo\t", with: "fx-0001-renamed\t"))
        }
        return pack
    }
}
