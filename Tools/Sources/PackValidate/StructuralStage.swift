internal import ContentKit
internal import LearnCore
internal import Foundation
internal import PackReport

/// 구조 단계 — 매니페스트 디코딩·잠금 위반·디스크와의 양방향 대조.
///
/// **툴체인을 전혀 쓰지 않는다.** python 도 swiftc 도 없는 머신에서 그대로 돈다.
///
/// 파일 대조를 ``ContentPack/verifyChecksums()`` 로 하지 않는 이유는 하나다 —
/// 그쪽은 첫 불일치에서 던진다. 게이트는 "무엇이 어떻게 깨졌는지"를 한 번에 전부
/// 내놓아야 `lessongen repair` 가 한 번의 왕복으로 고칠 수 있다. 그래서 디스크를 한 번
/// 훑어 전부 비교한다. 훑는 방식은 설치기와 같은 ``PackManifestBuilder/scanFiles(in:)``
/// 이다 — 검증기가 보는 팩과 설치기가 보는 팩이 다르면 게이트는 아무것도 보장하지 못한다.
enum StructuralStage {
    static func run(pack: ContentPack, into table: inout FailureTable) {
        checkLock(pack: pack, into: &table)
        compareFiles(pack: pack, into: &table)
    }

    // MARK: - stableids.lock

    private static func checkLock(pack: ContentPack, into table: inout FailureTable) {
        do {
            try pack.checkStableIDLock()
        } catch {
            table.addPackLevel(
                PackValidationReport.Failure(
                    stage: .structural,
                    kind: .brokenReference,
                    summary: "\(PackLayout.lockFileName) 위반",
                    evidence: "\(error)"
                ))
        }
    }

    // MARK: - 디스크 ↔ 매니페스트

    private static func compareFiles(pack: ContentPack, into table: inout FailureTable) {
        let scanned: [PackManifest.FileEntry]
        do {
            scanned = try PackManifestBuilder.scanFiles(in: pack.directory)
        } catch {
            table.addPackLevel(
                PackValidationReport.Failure(
                    stage: .structural,
                    kind: .brokenReference,
                    summary: "팩 디렉터리를 훑을 수 없다",
                    evidence: "\(error)"
                ))
            return
        }

        let onDisk = Dictionary(scanned.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let declared = pack.manifest.fileIndex()

        for entry in pack.manifest.files.sorted(by: { $0.path < $1.path }) {
            guard let actual = onDisk[entry.path] else {
                add(
                    .init(
                        stage: .structural, kind: .brokenReference,
                        summary: "매니페스트에 등록된 \(entry.path) 가 디스크에 없다",
                        evidence: "files[].path = \(entry.path)"),
                    for: entry.path, pack: pack, into: &table)
                continue
            }
            // 크기 먼저다 — 해시가 다르면 크기도 다른 경우가 대부분이고, 크기 불일치가
            // 사람에게 훨씬 읽기 쉬운 진단이다.
            if actual.bytes != entry.bytes {
                add(
                    .init(
                        stage: .structural, kind: .brokenReference,
                        summary: "\(entry.path) 의 크기가 매니페스트와 다르다",
                        evidence: "기대 \(entry.bytes)B, 실제 \(actual.bytes)B"),
                    for: entry.path, pack: pack, into: &table)
                continue
            }
            if actual.sha256 != entry.sha256 {
                add(
                    .init(
                        stage: .structural, kind: .brokenReference,
                        summary: "\(entry.path) 의 sha256 이 매니페스트와 다르다",
                        evidence: "기대 \(entry.sha256)\n실제 \(actual.sha256)"),
                    for: entry.path, pack: pack, into: &table)
            }
        }

        for entry in scanned where declared[entry.path] == nil {
            add(
                .init(
                    stage: .structural, kind: .brokenReference,
                    summary: "디스크의 \(entry.path) 가 매니페스트 files 에 없다",
                    evidence: "sha256 \(entry.sha256), \(entry.bytes)B — files 에 등록하거나 팩에서 빼라"),
                for: entry.path, pack: pack, into: &table)
        }
    }

    /// 파일 하나의 실패를 **그 파일을 소유한 레슨**에 붙인다.
    ///
    /// 레슨 본문 파일은 매니페스트가 소유자를 알려 준다. 사이드카(starters·tests·
    /// solutions·expected)의 소유자는 레슨 본문을 파싱해야 알 수 있고 구조 단계는 아직
    /// 파싱하지 않았으므로, 그런 파일은 팩 전체 슬롯으로 간다.
    private static func add(
        _ failure: PackValidationReport.Failure,
        for path: String,
        pack: ContentPack,
        into table: inout FailureTable
    ) {
        if let owner = pack.manifest.lessons.first(where: { $0.path == path }) {
            table.add(failure, to: owner.stableID.rawValue)
        } else {
            table.addPackLevel(failure)
        }
    }
}
