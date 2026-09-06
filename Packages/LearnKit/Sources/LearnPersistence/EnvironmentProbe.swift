internal import GRDB

/// 부팅 시 SQLite 환경을 **실측**한 결과.
///
/// 컴파일 타임에 아는 척할 수 있는 게 하나도 없다. macOS 는 시스템 SQLite 를 OS 업데이트로 갈고,
/// FTS5 는 컴파일 옵션이며, `journal_mode` 는 파일 종류에 따라 달라지고, `foreign_keys` 는
/// 연결마다 켜야 하는 PRAGMA 다. 그래서 셋 다 켠 뒤 **다시 읽어서** 확인한다.
public struct EnvironmentProbe: Hashable, Sendable {
    public var sqliteVersion: String
    /// FTS5 모듈의 소스 id.
    ///
    /// - Note: 플랜에는 `fts5_version()` 이라고 적혀 있지만 **그런 함수는 SQLite 에 없다**
    ///   (3.51.1 에서 `no such function` 으로 확인). FTS5 가 등록하는 스칼라 함수는
    ///   `fts5_source_id()` 하나뿐이라 그것을 쓴다.
    public var fts5SourceID: String
    /// trigram 토크나이저로 실제 가상 테이블을 만들어 보고 얻은 결과.
    /// FTS5 가 있어도 trigram 은 SQLite 3.34 미만에서 없다 — 별도로 확인해야 한다.
    public var trigramTokenizerAvailable: Bool
    /// `wal`(파일) 또는 `memory`(인메모리). 그 밖의 값이면 설정이 먹지 않은 것이다.
    public var journalMode: String
    public var foreignKeysEnabled: Bool

    public var isWriteAheadLogging: Bool { journalMode.lowercased() == "wal" }
}

public enum EnvironmentProbeError: Error, Sendable, Equatable {
    /// FTS5 자체가 없다. 오답 노트 검색이 통째로 불가능하므로 부팅을 중단한다.
    case fts5Unavailable(detail: String)
    /// FTS5 는 있으나 trigram 토크나이저가 없다.
    case trigramTokenizerUnavailable(detail: String)
    /// `PRAGMA foreign_keys` 가 꺼져 있다 — `diagnostic` 의 ON DELETE CASCADE 가 동작하지 않는다.
    case foreignKeysDisabled
    /// 기대한 저널 모드가 아니다.
    case unexpectedJournalMode(actual: String, expected: String)
}

extension EnvironmentProbe {
    /// 진단용 임시 FTS5 테이블 이름. `temp.` 스키마라 파일에 아무 흔적도 남지 않는다.
    private static let probeTable = "learnkit_fts5_probe"

    static func measure(_ db: Database) throws -> EnvironmentProbe {
        let sqliteVersion = try String.fetchOne(db, sql: "SELECT sqlite_version()") ?? "unknown"

        let fts5SourceID: String
        do {
            fts5SourceID = try String.fetchOne(db, sql: "SELECT fts5_source_id()") ?? ""
        } catch {
            throw EnvironmentProbeError.fts5Unavailable(detail: "\(error)")
        }

        // 존재 확인만으로는 부족하다. trigram 은 FTS5 안의 별도 토크나이저이므로 실제로 만들어 본다.
        var trigramAvailable = false
        var trigramFailure = ""
        do {
            try db.execute(sql: """
                CREATE VIRTUAL TABLE temp.\(probeTable) USING fts5(probe, tokenize='trigram')
                """)
            try db.execute(sql: "DROP TABLE temp.\(probeTable)")
            trigramAvailable = true
        } catch {
            trigramFailure = "\(error)"
        }
        guard trigramAvailable else {
            throw EnvironmentProbeError.trigramTokenizerUnavailable(detail: trigramFailure)
        }

        let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode") ?? "unknown"
        let foreignKeys = try Int.fetchOne(db, sql: "PRAGMA foreign_keys") ?? 0

        return EnvironmentProbe(
            sqliteVersion: sqliteVersion,
            fts5SourceID: fts5SourceID,
            trigramTokenizerAvailable: true,
            journalMode: journalMode,
            foreignKeysEnabled: foreignKeys != 0
        )
    }

    /// 실측값이 기대와 맞는지. 어긋나면 **부팅을 중단**한다 — 잘못된 환경에서 계속 굴러가면
    /// 손상이 조용히 누적되고, 그때는 이미 `review_log` 가 쌓인 뒤다.
    func validate(expectedJournalMode: String) throws {
        guard foreignKeysEnabled else { throw EnvironmentProbeError.foreignKeysDisabled }
        guard journalMode.lowercased() == expectedJournalMode.lowercased() else {
            throw EnvironmentProbeError.unexpectedJournalMode(
                actual: journalMode,
                expected: expectedJournalMode
            )
        }
    }
}
