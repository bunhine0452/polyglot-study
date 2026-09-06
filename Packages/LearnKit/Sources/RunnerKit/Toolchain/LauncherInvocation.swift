public import LanguageKit

/// `learn-launcher` 호출 한 건을 argv 로 굳힌다.
///
/// 인자 규약을 문자열 조립 코드 여기저기에 흩지 않고 한 곳에 모아, 계약 테스트가
/// 프로세스를 띄우지 않고도 argv 를 검증할 수 있게 한다.
public struct LauncherInvocation: Sendable, Hashable {
    /// `learn-launcher` 실행 파일 절대경로.
    public var launcherPath: String
    /// 사용자 코드를 실행할 프로그램. `execv` 로 그대로 넘어가므로 절대경로여야 한다.
    public var executablePath: String
    public var arguments: [String]
    public var workingDirectory: String?
    public var limits: ResourceLimits
    /// 런처가 status 라인을 쓸 fd. 부모가 미리 열어 상속시켜야 한다.
    public var statusFileDescriptor: Int32
    /// `RLIMIT_FSIZE` 바이트.
    ///
    /// `ResourceLimits` 에는 디스크 쓰기 상한이 없다 — `outputBytes` 는 stdout/stderr
    /// 상한이라 의미가 다르다. 계약이 넓어지기 전까지는 여기서 기본값을 준다.
    public var fileSizeBytes: Int

    public static let defaultFileSizeBytes = 64 << 20

    public init(
        launcherPath: String,
        executablePath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        limits: ResourceLimits = .lesson,
        statusFileDescriptor: Int32 = 3,
        fileSizeBytes: Int = LauncherInvocation.defaultFileSizeBytes
    ) {
        self.launcherPath = launcherPath
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.limits = limits
        self.statusFileDescriptor = statusFileDescriptor
        self.fileSizeBytes = fileSizeBytes
    }

    /// `launcherPath` 를 제외한 인자 목록 — `Process.arguments` 에 그대로 넣는다.
    public var argumentVector: [String] {
        var argv: [String] = []
        argv.append(contentsOf: ["--cpu", String(max(0, limits.cpuSeconds))])
        argv.append(contentsOf: ["--nproc", String(max(0, limits.maxProcesses))])
        argv.append(contentsOf: ["--fsize", String(max(0, fileSizeBytes))])
        argv.append(contentsOf: ["--wall", String(max(0, limits.wallClockSeconds))])
        argv.append(contentsOf: ["--status-fd", String(statusFileDescriptor)])
        if let workingDirectory {
            argv.append(contentsOf: ["--cwd", workingDirectory])
        }
        argv.append("--")
        argv.append(executablePath)
        argv.append(contentsOf: arguments)
        return argv
    }

    /// 런처까지 포함한 완전한 명령줄. 로그·진단용.
    public var commandLine: [String] { [launcherPath] + argumentVector }
}
