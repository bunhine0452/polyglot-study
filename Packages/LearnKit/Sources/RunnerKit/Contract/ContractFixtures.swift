public import Foundation
public import LanguageKit
public import LearnCore

/// 계약 케이스 하나를 특정 언어로 표현한 프로그램.
///
/// 백엔드가 없는 언어의 픽스처도 **데이터로는 존재한다** — 서브프로세스 러너가 붙는 날
/// 카탈로그를 다시 쓰지 않고 그대로 꽂히게 하려는 것이다. 지금은 해당 언어의 러너가
/// 없으니 하네스가 아예 그 픽스처를 꺼내지 않는다.
public struct ContractFixture: Hashable, Sendable {
    public var caseID: ContractCaseID
    public var language: LanguageID
    public var files: [SourceFile]
    public var entryPoint: String?
    public var arguments: [String]
    public var standardInput: Data?
    public var limits: ResourceLimits
    /// 이 픽스처가 대상으로 삼는 읽기 전용 자원. 계약 케이스 대부분은 비어 있고,
    /// 레슨 DB 위에서만 의미가 있는 케이스가 생기면 여기로 온다.
    public var resources: [String: URL]
    public var expectations: [ContractExpectation]

    public init(
        caseID: ContractCaseID,
        language: LanguageID,
        files: [SourceFile],
        entryPoint: String? = nil,
        arguments: [String] = [],
        standardInput: Data? = nil,
        limits: ResourceLimits = .lesson,
        resources: [String: URL] = [:],
        expectations: [ContractExpectation]
    ) {
        self.caseID = caseID
        self.language = language
        self.files = files
        self.entryPoint = entryPoint
        self.arguments = arguments
        self.standardInput = standardInput
        self.limits = limits
        self.resources = resources
        self.expectations = expectations
    }

    public var request: RunRequest {
        RunRequest(
            files: files,
            entryPoint: entryPoint,
            arguments: arguments,
            standardInput: standardInput,
            limits: limits,
            resources: resources
        )
    }
}

/// 언어 × 케이스 → 픽스처.
public struct ContractFixtureCatalog: Sendable {
    private let fixtures: [LanguageID: [ContractCaseID: ContractFixture]]

    public init(_ fixtures: [ContractFixture]) {
        var table: [LanguageID: [ContractCaseID: ContractFixture]] = [:]
        for fixture in fixtures {
            table[fixture.language, default: [:]][fixture.caseID] = fixture
        }
        self.fixtures = table
    }

    public subscript(language: LanguageID, caseID: ContractCaseID) -> ContractFixture? {
        fixtures[language]?[caseID]
    }

    public func fixtures(for language: LanguageID) -> [ContractFixture] {
        (fixtures[language] ?? [:]).values.sorted { $0.caseID.rawValue < $1.caseID.rawValue }
    }

    public var languages: Set<LanguageID> { Set(fixtures.keys) }

    /// 표준 카탈로그. SQL 은 지금 돌아가고, Python·Swift 는 데이터로만 있다.
    public static let standard = ContractFixtureCatalog(sqlFixtures + pythonFixtures + swiftFixtures)
}

// MARK: - SQL (InProcessRunner 로 실제 실행됨)

extension ContractFixtureCatalog {
    static func sql(_ id: ContractCaseID, _ sql: String, limits: ResourceLimits = .lesson, _ expectations: [ContractExpectation]) -> ContractFixture {
        ContractFixture(
            caseID: id,
            language: .sql,
            files: [SourceFile(path: "query.sql", contents: sql)],
            limits: limits,
            expectations: expectations
        )
    }

    static let sqlFixtures: [ContractFixture] = [
        // 진짜 무한 재귀 CTE. 선형 재귀라 큐가 안 쌓여서 메모리는 3MB 대로 묶인다 —
        // 즉 OOM 이 아니라 **시간**으로만 죽는다. 타임아웃을 재는 데 이보다 나은 게 없다.
        sql(
            .timeout,
            """
            WITH RECURSIVE spin(x) AS (
                SELECT 1 UNION ALL SELECT x + 1 FROM spin
            )
            SELECT count(*) FROM spin;
            """,
            limits: ResourceLimits(wallClockSeconds: 1, cpuSeconds: 1),
            [.fails(.wallClockExceeded), .completesWithin(milliseconds: 6_000)]
        ),
        // 끝은 있지만 8e9 행짜리 3중 조인. 유한한데 사실상 무한인 케이스.
        sql(
            .infiniteLoop,
            """
            WITH RECURSIVE n(i) AS (
                SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 2000
            )
            SELECT count(*) FROM n a, n b, n c;
            """,
            limits: ResourceLimits(wallClockSeconds: 2, cpuSeconds: 2),
            [.fails(.wallClockExceeded), .completesWithin(milliseconds: 8_000)]
        ),
        sql(
            .outputFlood,
            """
            WITH RECURSIVE gen(i) AS (
                SELECT 1 UNION ALL SELECT i + 1 FROM gen WHERE i < 40000
            )
            SELECT i, hex(randomblob(48)) FROM gen;
            """,
            limits: ResourceLimits(wallClockSeconds: 20, outputBytes: 1 << 20),
            [.truncatesOutput, .finishes(.succeeded)]
        ),
        sql(
            .hugeSingleLine,
            "SELECT hex(zeroblob(120000)) AS blob_hex;",
            limits: ResourceLimits(wallClockSeconds: 20),
            [.emitsLine(atLeastBytes: 240_000), .finishes(.succeeded)]
        ),
        // CAST(blob AS TEXT) 는 바이트를 검증 없이 재해석한다. 0xFF 0xFE 는 UTF-8 이 아니다.
        sql(
            .nonUTF8Output,
            "SELECT CAST(x'FFFE' AS TEXT) AS raw;",
            // 같은 실행이 바이트 스트림과 구조화된 표 **둘 다** 내야 한다.
            // 표 통로가 조용히 끊겨도 stdout 만 보면 눈치채지 못하므로 여기서 함께 잰다.
            [.emitsNonUTF8Output, .emitsResultSet(rows: 1, columns: 1), .finishes(.succeeded)]
        ),
        sql(
            .cancellation,
            """
            WITH RECURSIVE spin(x) AS (
                SELECT 1 UNION ALL SELECT x + 1 FROM spin
            )
            SELECT count(*) FROM spin;
            """,
            limits: ResourceLimits(wallClockSeconds: 60, cpuSeconds: 60),
            [.cancelsWithin(milliseconds: 5_000)]
        ),
        // 존재하지 않는 테이블 → 실패 종료 + 위치가 찍힌 진단.
        // 인프로세스에는 종료 코드가 없으므로 코드는 따지지 않는다 — 같은 픽스처를
        // 서브프로세스 백엔드가 재사용할 때는 코드가 채워져 와도 통과한다.
        sql(
            .exitCode,
            "SELECT 1;\nSELECT * FROM table_that_does_not_exist;",
            [.finishes(.failed(code: nil)), .emitsErrorDiagnostic(containing: "table_that_does_not_exist")]
        ),
    ]
}

// MARK: - Python / Swift (데이터 전용 — 백엔드가 붙으면 그대로 쓰인다)

extension ContractFixtureCatalog {
    static func fixture(
        _ id: ContractCaseID,
        _ language: LanguageID,
        path: String,
        _ source: String,
        limits: ResourceLimits = .lesson,
        standardInput: Data? = nil,
        _ expectations: [ContractExpectation]
    ) -> ContractFixture {
        ContractFixture(
            caseID: id,
            language: language,
            files: [SourceFile(path: path, contents: source)],
            standardInput: standardInput,
            limits: limits,
            expectations: expectations
        )
    }

    static let pythonFixtures: [ContractFixture] = [
        fixture(.timeout, .python, path: "main.py", "import time\ntime.sleep(120)\n",
                limits: ResourceLimits(wallClockSeconds: 2),
                [.fails(.wallClockExceeded)]),
        fixture(.infiniteLoop, .python, path: "main.py", "while True:\n    pass\n",
                limits: ResourceLimits(wallClockSeconds: 2, cpuSeconds: 1),
                [.fails(.wallClockExceeded)]),
        fixture(.outputFlood, .python, path: "main.py",
                "import sys\nfor _ in range(200000):\n    sys.stdout.write('x' * 128 + '\\n')\n",
                [.truncatesOutput]),
        fixture(.hugeSingleLine, .python, path: "main.py",
                "import sys\nsys.stdout.write('y' * 300000)\n",
                [.emitsLine(atLeastBytes: 300_000)]),
        fixture(.nonUTF8Output, .python, path: "main.py",
                "import sys\nsys.stdout.buffer.write(b'\\xff\\xfe\\x00\\xc3')\n",
                [.emitsNonUTF8Output]),
        fixture(.cancellation, .python, path: "main.py", "import time\ntime.sleep(120)\n",
                limits: ResourceLimits(wallClockSeconds: 60),
                [.cancelsWithin(milliseconds: 5_000)]),
        fixture(.exitCode, .python, path: "main.py", "import sys\nsys.exit(42)\n",
                [.finishes(.failed(code: 42))]),
        fixture(.standardInput, .python, path: "main.py",
                "print(input().upper())\n",
                standardInput: Data("hello\n".utf8),
                [.stdoutContains("HELLO"), .finishes(.succeeded)]),
        // 런처의 setsid + killpg 를 재는 케이스. 인프로세스에는 의미가 없다.
        fixture(.forkBomb, .python, path: "main.py",
                "import os\nwhile True:\n    os.fork()\n",
                limits: ResourceLimits(wallClockSeconds: 3, maxProcesses: 8),
                [.completesWithin(milliseconds: 10_000)]),
        fixture(.grandchildProcess, .python, path: "main.py",
                "import subprocess\nsubprocess.Popen(['sh', '-c', 'sleep 300'])\nprint('spawned')\n",
                limits: ResourceLimits(wallClockSeconds: 3),
                [.completesWithin(milliseconds: 10_000)]),
        // 벽시계는 넉넉히 주고 CPU 만 조인다 — 이래야 "멈춘 코드"가 아니라
        // "느린 코드"로 분류되는지가 실제로 갈린다.
        fixture(.cpuExhaustion, .python, path: "main.py",
                "x = 0\nwhile True:\n    x += 1\n",
                limits: ResourceLimits(wallClockSeconds: 60, cpuSeconds: 1),
                [.fails(.cpuExceeded), .completesWithin(milliseconds: 20_000)]),
        fixture(.memoryExhaustion, .python, path: "main.py",
                "blocks = []\nwhile True:\n    blocks.append(bytearray(8 * 1024 * 1024))\n",
                limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30, memoryMegabytes: 64),
                [.fails(.memoryExceeded), .completesWithin(milliseconds: 30_000)]),
        fixture(.fileSizeFlood, .python, path: "main.py",
                "with open('big.bin', 'wb') as f:\n    while True:\n        f.write(b'x' * (1 << 20))\n",
                limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30, fileSizeBytes: 1 << 20),
                [.fails(.fileSizeExceeded), .completesWithin(milliseconds: 30_000)]),
    ]

    static let swiftFixtures: [ContractFixture] = [
        fixture(.timeout, .swift, path: "main.swift", "Thread.sleep(forTimeInterval: 120)\n",
                limits: ResourceLimits(wallClockSeconds: 2),
                [.fails(.wallClockExceeded)]),
        fixture(.infiniteLoop, .swift, path: "main.swift", "while true {}\n",
                limits: ResourceLimits(wallClockSeconds: 2, cpuSeconds: 1),
                [.fails(.wallClockExceeded)]),
        fixture(.outputFlood, .swift, path: "main.swift",
                "for _ in 0..<200_000 { print(String(repeating: \"x\", count: 128)) }\n",
                [.truncatesOutput]),
        fixture(.hugeSingleLine, .swift, path: "main.swift",
                "print(String(repeating: \"y\", count: 300_000))\n",
                [.emitsLine(atLeastBytes: 300_000)]),
        fixture(.nonUTF8Output, .swift, path: "main.swift",
                "FileHandle.standardOutput.write(Data([0xFF, 0xFE, 0x00, 0xC3]))\n",
                [.emitsNonUTF8Output]),
        fixture(.cancellation, .swift, path: "main.swift", "Thread.sleep(forTimeInterval: 120)\n",
                limits: ResourceLimits(wallClockSeconds: 60),
                [.cancelsWithin(milliseconds: 5_000)]),
        fixture(.exitCode, .swift, path: "main.swift", "exit(42)\n",
                [.finishes(.failed(code: 42))]),
        fixture(.standardInput, .swift, path: "main.swift",
                "print(readLine()!.uppercased())\n",
                standardInput: Data("hello\n".utf8),
                [.stdoutContains("HELLO"), .finishes(.succeeded)]),
        // 런처가 프로세스 그룹째 회수하는지. Process 로 띄운 손자는 부모가 죽어도 남는다.
        fixture(.grandchildProcess, .swift, path: "main.swift",
                "import Foundation\nlet p = Process()\np.executableURL = URL(fileURLWithPath: \"/bin/sh\")\np.arguments = [\"-c\", \"sleep 300\"]\ntry p.run()\nprint(\"spawned\")\n",
                limits: ResourceLimits(wallClockSeconds: 3),
                [.completesWithin(milliseconds: 20_000)]),
        fixture(.cpuExhaustion, .swift, path: "main.swift",
                "var x = 0\nwhile true { x &+= 1 }\n",
                limits: ResourceLimits(wallClockSeconds: 60, cpuSeconds: 1),
                [.fails(.cpuExceeded), .completesWithin(milliseconds: 20_000)]),
        fixture(.memoryExhaustion, .swift, path: "main.swift",
                "import Foundation\nvar blocks: [Data] = []\nwhile true { blocks.append(Data(count: 8 << 20)) }\n",
                limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30, memoryMegabytes: 64),
                [.fails(.memoryExceeded), .completesWithin(milliseconds: 30_000)]),
        fixture(.fileSizeFlood, .swift, path: "main.swift",
                """
                import Foundation
                FileManager.default.createFile(atPath: "big.bin", contents: nil)
                let handle = FileHandle(forWritingAtPath: "big.bin")!
                let block = Data(count: 1 << 20)
                while true { handle.write(block) }
                """,
                limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30, fileSizeBytes: 1 << 20),
                [.fails(.fileSizeExceeded), .completesWithin(milliseconds: 30_000)]),
    ]
}
