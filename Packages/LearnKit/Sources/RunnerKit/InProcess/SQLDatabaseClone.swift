public import Foundation
internal import Darwin
internal import LanguageKit

/// 매 실행마다 원본 `.db` 를 워크스페이스로 복제한다.
///
/// APFS 에서 `copyfile(COPYFILE_CLONE)` 은 블록을 공유하는 copy-on-write 사본을 만든다 —
/// 200MB 짜리 SQL Murder Mystery DB 라도 복제 비용이 사실상 0이다. 클론이 불가능한
/// 파일시스템(FAT, 다른 볼륨)에서는 커널이 알아서 일반 복사로 떨어진다.
///
/// **원본은 절대 열지 않는다.** 읽기 전용으로 열어도 SQLite 는 -shm 을 만들거나 hot journal 을
/// 롤백하면서 원본을 건드릴 수 있고, 그 순간 mtime 불변 보장이 깨진다.
public enum SQLDatabaseClone {
    /// WAL 모드 DB 를 클론할 때 같이 따라가야 하는 사이드카들.
    ///
    /// `-shm` 은 일부러 뺐다 — 공유 메모리 인덱스는 다른 프로세스의 상태를 담고 있어서
    /// 그대로 복사하면 오히려 엉킨다. SQLite 가 워크스페이스 안에서 새로 만든다.
    static let sidecarSuffixes = ["-wal", "-journal"]

    @discardableResult
    public static func clone(source: URL, into directory: URL, named name: String) throws -> URL {
        let destination = directory.appendingPathComponent(name)
        try cloneFile(from: source, to: destination)

        for suffix in sidecarSuffixes {
            let sidecarSource = URL(fileURLWithPath: source.path + suffix)
            guard FileManager.default.fileExists(atPath: sidecarSource.path) else { continue }
            let sidecarDestination = URL(fileURLWithPath: destination.path + suffix)
            // 사이드카 실패는 치명적이지 않다 — 본체만 있어도 대개 열린다.
            try? cloneFile(from: sidecarSource, to: sidecarDestination)
        }
        return destination
    }

    private static func cloneFile(from source: URL, to destination: URL) throws {
        // COPYFILE_CLONE = EXCL|ACL|STAT|XATTR|DATA|NOFOLLOW_SRC + 가능하면 clonefile.
        let flags = copyfile_flags_t(COPYFILE_CLONE)
        let result = source.withUnsafeFileSystemRepresentation { sourcePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath in
                copyfile(sourcePath, destinationPath, nil, flags)
            }
        }
        guard result == 0 else {
            let message = String(cString: strerror(errno))
            throw RunFailure.backend("DB 복제 실패 (\(source.lastPathComponent)): \(message)")
        }
        // 원본이 0444 여도 클론은 우리 것이다. 읽기 전용으로 열더라도 SQLite 가
        // 임시 파일을 만들 수 있어야 하므로 소유자 쓰기 권한을 준다.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }
}
