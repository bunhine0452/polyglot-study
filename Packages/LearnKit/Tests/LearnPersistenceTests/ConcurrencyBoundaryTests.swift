import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// `{#repo-impl}` `{#no-actor-wrapping}` — Swift 6 DB 접근 경계를 소스 수준에서 강제한다.
///
/// 이 스위트는 동작이 아니라 **코드 모양**을 본다. 그래서 값이 있다 — GRDB 타입이 클로저 밖으로
/// 새는 것은 컴파일은 되지만 런타임에 "database is closed" 나 데이터 경합으로 나타나고,
/// 그때는 원인 파악이 몇 시간짜리다.
@Suite("DB 접근 경계")
struct ConcurrencyBoundaryTests {
    @Test("리포지토리를 actor 로 감싸지 않는다")
    func repositoriesAreNotActors() throws {
        var offenders: [String] = []
        for file in try SourceTree.swiftFiles(under: "Sources/LearnPersistence") {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for line in contents.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue } // 주석은 actor 를 언급해도 된다
                if trimmed.hasPrefix("actor ") || trimmed.contains(" actor ") {
                    offenders.append("\(file.lastPathComponent): \(trimmed)")
                }
            }
        }
        #expect(offenders.isEmpty, """
            GRDB 7 의 writer 는 이미 Sendable 이고 접근을 스스로 직렬화한다.
            actor 로 감싸면 홉만 늘고 재진입 위험이 생긴다: \(offenders)
            """)
    }

    @Test("Database·Row·Statement 를 반환하는 시그니처가 없다")
    func noGRDBTypesEscapeClosures() throws {
        // 반환 타입 자리에 GRDB 커서/핸들 타입이 나오면 그 값은 read/write 클로저 밖으로 나간다.
        // `DatabaseMigrator` 처럼 이름이 겹치되 핸들이 아닌 값 타입까지 잡지 않도록 토큰 단위로 본다.
        let forbiddenReturnTypes: Set<String> = [
            "Row", "[Row]", "Row?",
            "Database", "Database?",
            "Statement", "[Statement]",
            "RowCursor", "DatabaseCursor",
        ]
        var offenders: [String] = []
        for file in try SourceTree.swiftFiles(under: "Sources/LearnPersistence") {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for line in contents.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                guard trimmed.contains("func ") else { continue }
                // 클로저 파라미터 타입(`(Database) throws -> T`)은 괜찮다 — 반환이 아니다.
                // 마지막 `->` 뒤의 첫 토큰이 실제 반환 타입이다.
                guard let returnClause = trimmed.components(separatedBy: "->").last,
                      let token = returnClause
                          .trimmingCharacters(in: .whitespaces)
                          .split(separator: " ").first
                else { continue }
                let returnType = token.replacingOccurrences(of: "{", with: "")
                if forbiddenReturnTypes.contains(returnType) {
                    offenders.append("\(file.lastPathComponent): \(trimmed)")
                }
            }
        }
        #expect(offenders.isEmpty, "GRDB 핸들이 클로저 밖으로 나간다: \(offenders)")
    }

    @Test("LearnCore 프로토콜 시그니처에 GRDB 타입 이름이 없다")
    func protocolSignaturesAreGRDBFree() throws {
        let file = SourceTree.packageRoot
            .appendingPathComponent("Sources/LearnCore/Persistence/StoreProtocols.swift")
        let contents = try String(contentsOf: file, encoding: .utf8)
        for name in ["DatabaseWriter", "DatabaseReader", "ValueObservation", "PersistenceContainer"] {
            #expect(!contents.contains(name), "\(name) 이 코어 계약에 새어 있다")
        }
        // 관찰 API 는 표준 AsyncSequence 로 나간다.
        #expect(contents.contains("AsyncThrowingStream"))
    }

    @Test("영속화 DTO 6종이 전부 값 타입이고 Sendable 이다")
    func sixDTOsAreSendableValueTypes() {
        // 컴파일이 곧 증명이다 — Sendable 이 아니면 이 배열이 만들어지지 않는다.
        let dtos: [any Sendable] = [
            Fixture.reviewEntry(),
            SchedulerParameterSet.inMemoryDefault,
            Fixture.cardState(),
            Fixture.submission(),
            Fixture.note(title: "t", body: "b"),
            LessonProgress(packID: PackID("p"), lessonID: LessonID("l"), languageID: .python),
        ]
        #expect(dtos.count == 6)
    }

    /// GRDB writer 하나에 동시에 접근해도 직렬화된다 — actor 없이도.
    @Test("동시 쓰기가 유실 없이 직렬화된다", arguments: DatabaseFlavor.allCases)
    func concurrentWritesAreSerialized(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.reviewLogStore

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                group.addTask {
                    try await store.append(
                        Fixture.reviewEntry(card: "card-\(index % 4)", at: Int64(index))
                    )
                }
            }
            try await group.waitForAll()
        }

        #expect(try await store.count() == 40)
        // id 가 하나도 겹치지 않아야 한다 (AUTOINCREMENT 단조성).
        let all = try await store.entries(after: nil, limit: 100)
        #expect(Set(all.compactMap(\.id)).count == 40)
    }

    @Test("동시 읽기·쓰기가 섞여도 일관된 값을 본다", arguments: DatabaseFlavor.allCases)
    func concurrentReadsAndWritesStayConsistent(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let log = harness.database.reviewLogStore
        let cards = harness.database.cardStateStore

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask { try await log.append(Fixture.reviewEntry(at: Int64(index))) }
                group.addTask { _ = try await cards.dueCards(
                    languageID: .python, dueAtOrBefore: .max, limit: 10
                ) }
            }
            try await group.waitForAll()
        }
        #expect(try await log.count() == 20)
    }
}
