internal import Foundation
public import LanguageKit

/// Python 트랙의 실행 준비.
///
/// 인자는 `-I -B <entry>` 로 고정한다.
///   - `-I` (격리 모드) 는 `-E`(`PYTHON*` 환경변수 무시) + `-s`(사용자 site-packages
///     제외) + `-P`(스크립트 디렉터리를 `sys.path` 에 넣지 않음) 를 한꺼번에 켠다.
///     사용자가 홈에 깔아 둔 패키지가 레슨 결과를 바꾸면 채점이 재현되지 않는다.
///   - `-B` 는 `__pycache__` 를 만들지 않는다. 워크스페이스는 실행마다 새로 생기므로
///     캐시는 이득이 없고 쓰기만 늘린다(`RLIMIT_FSIZE` 예산도 축낸다).
///
/// - Note: `-P` 의 대가로 **워크스페이스 안의 형제 모듈을 import 할 수 없다.**
///   단일 파일 레슨에는 문제가 없고, 여러 파일이 필요한 채점 경로는 하네스가
///   `sys.path` 를 직접 손봐서 푼다(`PythonUnittestHarness`).
public struct PythonProgram: SubprocessProgram {
    /// nil 이면 `LanguageToolchain` 이 버전 정책으로 고른다.
    public var interpreterPath: String?
    /// `RunRequest.entryPoint` 가 없을 때 쓸 파일.
    public var defaultEntryPoint: String
    /// 진입점 앞에 끼울 인터프리터 인자.
    public var interpreterArguments: [String]

    public init(
        interpreterPath: String? = nil,
        defaultEntryPoint: String = "main.py",
        interpreterArguments: [String] = ["-I", "-B"]
    ) {
        self.interpreterPath = interpreterPath
        self.defaultEntryPoint = defaultEntryPoint
        self.interpreterArguments = interpreterArguments
    }

    /// stdin 이 붙는다 — `input()` 실습이 Python 트랙의 첫 레슨이다.
    public var capabilities: RunnerCapabilities { [.standardInput] }

    public func prepare(
        request: RunRequest,
        workspace: RunWorkspace,
        emit: @Sendable (RunEvent) -> Void
    ) async throws -> SubprocessPreparation {
        let entry = try Self.entryPoint(for: request, fallback: defaultEntryPoint)
        let interpreter = try await resolveInterpreter()
        return .run(SubprocessInvocation(
            executablePath: interpreter,
            arguments: interpreterArguments + [entry] + request.arguments
        ))
    }

    func resolveInterpreter() async throws -> String {
        if let interpreterPath {
            guard FileManager.default.isExecutableFile(atPath: interpreterPath) else {
                throw RunFailure.toolchainMissing(hint: "python3 가 \(interpreterPath) 에 없다.")
            }
            return interpreterPath
        }
        return try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.python)
    }

    /// 진입점은 **요청 안에 실재해야 한다**. 없는 파일을 인터프리터에 넘기면
    /// "파일이 없다"는 런타임 오류가 사용자 코드의 오류처럼 보인다.
    static func entryPoint(for request: RunRequest, fallback: String) throws -> String {
        if let entryPoint = request.entryPoint {
            guard request.files.contains(where: { $0.path == entryPoint }) else {
                throw RunFailure.backend("진입점 파일을 찾을 수 없음: \(entryPoint)")
            }
            return entryPoint
        }
        if request.files.contains(where: { $0.path == fallback }) { return fallback }
        guard let first = request.files.first(where: { $0.path.hasSuffix(".py") }) else {
            throw RunFailure.backend("실행할 .py 파일이 없습니다")
        }
        return first.path
    }
}
