import Testing
import Foundation
@testable import RunnerKit

@Suite("로그인 PATH 수확")
struct ToolchainPathHarvestTests {
    /// 이 머신의 실제 증상. p10k 가 rc 에서 경고를 뱉고 instant prompt 가 stdout 까지 쓴다.
    static let noisyOutput = """
        [WARNING]: Console output during zsh initialization detected.
        gitstatus: failed to initialize
        \(LoginPathHarvester.beginSentinel)/opt/homebrew/bin:/usr/bin:/bin\(LoginPathHarvester.endSentinel)
        p10k: instant prompt disabled
        """

    @Test("rc 소음 한가운데서도 센티널 사이만 정확히 뽑는다")
    func extractsBetweenSentinels() {
        #expect(LoginPathHarvester.extractPath(from: Self.noisyOutput) == "/opt/homebrew/bin:/usr/bin:/bin")
    }

    @Test("센티널이 없으면 nil — 마지막 줄 휴리스틱으로 대체하지 않는다")
    func requiresSentinels() {
        #expect(LoginPathHarvester.extractPath(from: "/usr/bin:/bin") == nil)
        #expect(LoginPathHarvester.extractPath(from: "") == nil)
        #expect(LoginPathHarvester.extractPath(from: LoginPathHarvester.beginSentinel + "/usr/bin") == nil)
    }

    @Test("빈 PATH 도 nil 이 아니라 빈 문자열로 구분된다")
    func emptyPathIsDistinctFromMissing() {
        let output = LoginPathHarvester.beginSentinel + LoginPathHarvester.endSentinel
        #expect(LoginPathHarvester.extractPath(from: output) == "")
    }

    @Test("PATH 를 콜론으로 쪼개고 빈 항목은 버린다")
    func splitsPathVariable() {
        #expect(LoginPathHarvester.directories(fromPathVariable: "/a::/b:") == ["/a", "/b"])
    }

    @Test("관례 경로에 툴체인이 실제로 사는 디렉터리들이 들어 있다")
    func conventionalDirectoriesCoverToolchains() {
        let directories = LoginPathHarvester.conventionalDirectories()
        for expected in ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"] {
            #expect(directories.contains(expected), "관례 경로에 \(expected) 가 없다")
        }
        #expect(directories.contains { $0.hasSuffix("/.cargo/bin") })
        #expect(directories.contains { $0.hasSuffix("/miniconda3/bin") })
        #expect(directories.contains { $0.hasSuffix("/.local/bin") })
        #expect(directories.contains { $0.hasSuffix("/shims") })
    }

    @Test("실제 로그인 셸에서 수확한다", .timeLimit(.minutes(1)))
    func harvestsFromRealLoginShell() async {
        let harvest = await LoginPathHarvester.harvest()
        // 성공하든 폴백하든 최소한 /usr/bin 은 나와야 한다.
        #expect(harvest.directories.contains("/usr/bin"))
        #expect(!harvest.directories.isEmpty)
        // 중복 없음.
        #expect(Set(harvest.directories).count == harvest.directories.count)
        // 존재하지 않는 디렉터리는 걸러진다.
        for directory in harvest.directories {
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
    }

    @Test("셸이 없으면 3초 안에 관례 경로로 떨어진다", .timeLimit(.minutes(1)))
    func fallsBackWhenShellMissing() async {
        let clock = ContinuousClock()
        let start = clock.now
        let harvest = await LoginPathHarvester.harvest(shell: "/nonexistent/shell", timeout: .seconds(3))
        let elapsed = start.duration(to: clock.now)

        #expect(harvest.usedFallback)
        #expect(harvest.rawPath == nil)
        #expect(harvest.directories.contains("/usr/bin"))
        #expect(elapsed < .seconds(3))
    }
}
