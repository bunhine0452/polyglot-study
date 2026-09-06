import Foundation
import LLMKit
import TestSupport
import Testing

@Suite(".env 로딩과 우선순위")
struct DotEnvTests {
    /// 이 파일에는 **가짜 값만** 쓴다. 진짜 키는 테스트에 절대 넣지 않는다.
    private let fakeKey = Fixtures.fakeAPIKeyString

    @Test("KEY=VALUE 한 줄을 판다")
    func parsesSimpleLines() {
        let values = DotEnv.parse("OPENROUTER_MODEL=vendor/model-a\nOTHER=2\n")
        #expect(values["OPENROUTER_MODEL"] == "vendor/model-a")
        #expect(values["OTHER"] == "2")
    }

    @Test("주석과 빈 줄은 건너뛴다")
    func skipsCommentsAndBlanks() {
        let values = DotEnv.parse(
            """
            # 이건 주석
              # 들여쓴 주석

            A=1
            """
        )
        #expect(values == ["A": "1"])
    }

    @Test("따옴표를 벗기고 안쪽은 손대지 않는다")
    func stripsQuotes() {
        let values = DotEnv.parse(
            """
            A="값 안의 # 은 주석이 아니다"
            B='작은따옴표'
            C=따옴표없음
            """
        )
        #expect(values["A"] == "값 안의 # 은 주석이 아니다")
        #expect(values["B"] == "작은따옴표")
        #expect(values["C"] == "따옴표없음")
    }

    @Test("export 접두사와 CRLF 를 견딘다")
    func toleratesExportAndCRLF() {
        let values = DotEnv.parse("export OPENROUTER_MODEL=vendor/m\r\nB=2\r\n")
        #expect(values["OPENROUTER_MODEL"] == "vendor/m")
        #expect(values["B"] == "2")
    }

    @Test("값에 = 이 들어 있어도 첫 = 에서만 자른다")
    func splitsOnFirstEquals() {
        #expect(DotEnv.parse("A=b=c=d")["A"] == "b=c=d")
    }

    @Test("등호가 없거나 키가 비면 버린다")
    func ignoresMalformedLines() {
        let values = DotEnv.parse("그냥문장\n=값만있음\nA=1")
        #expect(values == ["A": "1"])
    }

    // MARK: - 우선순위

    @Test("프로세스 환경변수가 .env 를 이긴다")
    func processWins() {
        let source = EnvironmentSource(
            process: ["OPENROUTER_MODEL": "from-env"],
            dotEnv: DotEnv(values: ["OPENROUTER_MODEL": "from-file"])
        )
        #expect(source["OPENROUTER_MODEL"] == "from-env")
        #expect(source.origin(of: "OPENROUTER_MODEL") == "환경변수")
    }

    @Test("환경변수가 없거나 비어 있으면 .env 로 떨어진다")
    func fallsBackToFile() {
        let source = EnvironmentSource(
            process: ["OPENROUTER_MODEL": ""],
            dotEnv: DotEnv(values: ["OPENROUTER_MODEL": "from-file"])
        )
        #expect(source["OPENROUTER_MODEL"] == "from-file")
    }

    @Test("둘 다 없으면 nil 이고 출처도 없다")
    func missingEverywhere() {
        let source = EnvironmentSource(process: [:], dotEnv: .empty)
        #expect(source["OPENROUTER_MODEL"] == nil)
        #expect(source.origin(of: "OPENROUTER_MODEL") == nil)
    }

    @Test("merged 사전도 같은 우선순위를 지킨다")
    func mergedRespectsPriority() {
        let source = EnvironmentSource(
            process: ["A": "env", "B": ""],
            dotEnv: DotEnv(values: ["A": "file", "B": "file", "C": "file"])
        )
        #expect(source.merged["A"] == "env")
        #expect(source.merged["B"] == "file")
        #expect(source.merged["C"] == "file")
    }

    // MARK: - 파일 시스템

    @Test("현재 디렉터리에서 위로 올라가며 첫 .env 를 찾는다")
    func discoversUpward() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dotenv-\(UUID().uuidString)", isDirectory: true)
        let deep = root.appendingPathComponent("a/b/c", isDirectory: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "OPENROUTER_MODEL=vendor/found\n".write(
            to: root.appendingPathComponent(".env"), atomically: true, encoding: .utf8
        )

        let found = DotEnv.discover(startingAt: deep)
        #expect(found.values["OPENROUTER_MODEL"] == "vendor/found")
        #expect(found.sourceURL?.lastPathComponent == ".env")
    }

    @Test("더 가까운 .env 가 이긴다")
    func nearestWins() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dotenv-\(UUID().uuidString)", isDirectory: true)
        let inner = root.appendingPathComponent("inner", isDirectory: true)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "A=outer\n".write(to: root.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        try "A=inner\n".write(to: inner.appendingPathComponent(".env"), atomically: true, encoding: .utf8)

        #expect(DotEnv.discover(startingAt: inner).values["A"] == "inner")
    }

    @Test("못 찾으면 비어 있는 결과이고 던지지 않는다")
    func missingFileIsEmpty() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dotenv-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // 상한을 1로 두어 임시 디렉터리 위쪽을 훑지 않게 한다.
        let found = DotEnv.discover(startingAt: root, limit: 1)
        #expect(found.values.isEmpty)
        #expect(found.sourceURL == nil)
    }

    @Test("명시한 --env-file 이 없으면 던진다 — 조용히 무시하지 않는다")
    func explicitMissingFileThrows() {
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)/.env")
        #expect(throws: (any Error).self) { try DotEnv.load(from: missing) }
    }

    @Test(".env 에서 읽은 키도 APIKey 의 방어를 그대로 받는다")
    func keyFromDotEnvKeepsDefenses() throws {
        let source = EnvironmentSource(process: [:], dotEnv: DotEnv(values: ["OPENROUTER_API_KEY": fakeKey]))
        let key = try APIKey.fromEnvironment(source.merged)
        #expect(key.rawValue == fakeKey)
        // 출처가 파일이어도 문자열화는 여전히 자리표시자다.
        #expect("\(key)" == APIKey.placeholder)
    }
}
