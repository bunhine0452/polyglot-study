public import Foundation
public import LanguageKit

/// 워크스페이스 조립이 거부한 이유.
///
/// 전부 **스폰 전에** 판정된다. 사용자 코드가 도는 시점에는 이미 늦다 —
/// `SourceFile.path` 하나가 `../../../.ssh/authorized_keys` 이면 파일을 쓰는 순간 끝난다.
public struct WorkspaceError: Error, Hashable, Sendable, CustomStringConvertible {
    public enum Reason: String, Hashable, Sendable {
        case emptyPath
        case absolutePath
        case homeReference
        case parentReference
        case invalidComponent
        case duplicatePath
        case escapesRoot
        case creationFailed
        case writeFailed

        public var korean: String {
            switch self {
            case .emptyPath: "빈 경로"
            case .absolutePath: "절대경로는 허용되지 않음"
            case .homeReference: "홈 디렉터리(~) 참조는 허용되지 않음"
            case .parentReference: "상위 디렉터리(..) 참조는 허용되지 않음"
            case .invalidComponent: "허용되지 않는 경로 구성요소"
            case .duplicatePath: "중복된 경로"
            case .escapesRoot: "워크스페이스 루트를 벗어남"
            case .creationFailed: "워크스페이스 생성 실패"
            case .writeFailed: "소스 파일 기록 실패"
            }
        }
    }

    public var path: String
    public var reason: Reason
    public var underlying: String?

    public init(path: String, reason: Reason, underlying: String? = nil) {
        self.path = path
        self.reason = reason
        self.underlying = underlying
    }

    public var description: String {
        if let underlying {
            "\(reason.korean): \(path) — \(underlying)"
        } else {
            "\(reason.korean): \(path)"
        }
    }
}

/// `SourceFile.path` 판정 규칙. 순수 함수라 스폰 없이 단위 테스트할 수 있다.
public enum WorkspacePathPolicy {
    /// 상대 경로를 정규화해 돌려준다. 조금이라도 수상하면 던진다 — 조용히 고쳐주지 않는다.
    ///
    /// 정규화가 아니라 **거부**인 이유: `a/../b` 를 `b` 로 고쳐주면 규칙이 두 벌이 되고,
    /// 그중 하나(문자열 정규화)는 심링크 앞에서 무너진다.
    @discardableResult
    public static func normalize(_ path: String) throws -> String {
        guard !path.isEmpty else {
            throw WorkspaceError(path: path, reason: .emptyPath)
        }
        guard !path.utf8.contains(0) else {
            throw WorkspaceError(path: path, reason: .invalidComponent)
        }
        guard !path.hasPrefix("/") else {
            throw WorkspaceError(path: path, reason: .absolutePath)
        }
        guard !path.hasPrefix("~") else {
            throw WorkspaceError(path: path, reason: .homeReference)
        }
        // `file:///etc/passwd` 같은 URL 문자열도 상대 경로가 아니다.
        guard !path.contains("://") else {
            throw WorkspaceError(path: path, reason: .absolutePath)
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        for component in components {
            if component.isEmpty {
                // 빈 칸(`a//b`), 후행 슬래시(`a/`) 둘 다 여기로 온다.
                throw WorkspaceError(path: path, reason: .invalidComponent)
            }
            if component == ".." {
                throw WorkspaceError(path: path, reason: .parentReference)
            }
            if component == "." {
                throw WorkspaceError(path: path, reason: .invalidComponent)
            }
        }
        return components.joined(separator: "/")
    }

    /// 전체 파일 목록을 스폰 전에 검사한다. 하나라도 걸리면 아무것도 만들지 않는다.
    public static func validate(_ files: [SourceFile]) throws {
        // APFS 기본 볼륨은 대소문자를 구분하지 않는다 — `Main.swift` 와 `main.swift` 가
        // 같은 파일이 되어 나중 것이 앞 것을 덮는다. 그건 조용한 오답이므로 미리 막는다.
        var seen: Set<String> = []
        for file in files {
            let normalized = try normalize(file.path)
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else {
                throw WorkspaceError(path: file.path, reason: .duplicatePath)
            }
        }
    }
}

/// 실행 하나가 쓰는 임시 디렉터리.
///
/// 생성은 실패하거나 완전히 성공한다. 정리는 `remove()` 한 번이고 몇 번 불러도 안전하다 —
/// 성공·실패·타임아웃·취소 네 종료 경로가 전부 같은 한 줄을 지나가야 잔여물이 안 남는다.
public struct RunWorkspace: Sendable {
    /// 이 실행 전용 디렉터리. 사용자 파일은 전부 이 밑에 있다.
    public let root: URL
    /// 여러 실행이 공유하는 상위 디렉터리. 테스트가 잔여물을 세는 곳이기도 하다.
    public let container: URL

    public static func defaultContainer() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-run", isDirectory: true)
    }

    public init(files: [SourceFile] = [], container: URL? = nil) throws {
        // ① 스폰 전 판정. 디렉터리를 만들기도 전에 거부한다.
        try WorkspacePathPolicy.validate(files)

        let container = container ?? Self.defaultContainer()
        let root = container.appendingPathComponent("run-\(UUID().uuidString)", isDirectory: true)
        self.container = container
        self.root = root

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: container, withIntermediateDirectories: true)
            try fm.createDirectory(
                at: root,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw WorkspaceError(path: root.path, reason: .creationFailed, underlying: "\(error)")
        }

        do {
            try write(files)
        } catch {
            // 부분 생성된 워크스페이스를 남기지 않는다.
            remove()
            throw error
        }
    }

    /// 상대 경로에 대응하는 절대 URL. 경로 규칙을 통과한 것만 돌려준다.
    public func url(for relativePath: String) throws -> URL {
        let normalized = try WorkspacePathPolicy.normalize(relativePath)
        let url = root.appendingPathComponent(normalized)
        // 이중 방어. 문자열 규칙을 통과해도 실제 경로가 루트 밖이면 거부한다.
        let rootPath = root.standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(rootPath + "/") else {
            throw WorkspaceError(path: relativePath, reason: .escapesRoot)
        }
        return url
    }

    private func write(_ files: [SourceFile]) throws {
        let fm = FileManager.default
        for file in files {
            let url = try url(for: file.path)
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try file.contents.write(to: url, atomically: false, encoding: .utf8)
            } catch {
                throw WorkspaceError(path: file.path, reason: .writeFailed, underlying: "\(error)")
            }
        }
    }

    /// 몇 번 불러도 안전하고 절대 던지지 않는다 — 정리 경로가 던지면 정리가 안 된다.
    public func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    /// 성공·실패·타임아웃·취소 어디로 빠져나가도 `defer` 하나가 정리를 맡는다.
    public static func withWorkspace<T>(
        files: [SourceFile] = [],
        container: URL? = nil,
        _ body: (RunWorkspace) async throws -> T
    ) async throws -> T {
        let workspace = try RunWorkspace(files: files, container: container)
        defer { workspace.remove() }
        return try await body(workspace)
    }

    /// 컨테이너에 남아 있는 실행 디렉터리 수. 누수 회귀 테스트용.
    public static func residentWorkspaceCount(in container: URL) -> Int {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: container.path)) ?? []
        return contents.filter { $0.hasPrefix("run-") }.count
    }
}
