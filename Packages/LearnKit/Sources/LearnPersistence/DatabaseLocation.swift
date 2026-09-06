public import struct Foundation.URL
public import class Foundation.FileManager

/// DB 파일이 있어야 할 곳, 그리고 **있으면 안 되는 곳**.
///
/// SQLite 는 파일 락(WAL 의 `-shm` 공유 메모리 포함)으로 동시성을 지킨다. 그런데 iCloud Drive·
/// Dropbox·Google Drive·OneDrive 같은 동기 폴더는 파일을 뒤에서 evict 하고, 복사하고, 다른 기기의
/// 사본으로 덮어쓴다. 락 규약이 통하지 않는 파일시스템 위에서 SQLite 는 **조용히** 손상된다.
/// 그래서 경로 정책을 코드로 못박고 테스트로 지킨다.
public enum DatabaseLocation {
    /// Application Support 하위 디렉터리 이름.
    public static let directoryName = "LearnKit"
    /// 파일 이름. `-wal` / `-shm` 형제 파일이 같은 디렉터리에 생긴다.
    public static let fileName = "learn.sqlite"

    public enum LocationError: Error, Sendable, Equatable {
        /// 동기 폴더 안이다. `reason` 은 사용자에게 그대로 보여줄 수 있는 한 줄.
        case syncedFolder(path: String, reason: String)
        /// Application Support 를 찾지 못했다.
        case applicationSupportUnavailable
    }

    /// 기본 DB 경로 — `~/Library/Application Support/LearnKit/learn.sqlite`.
    ///
    /// 디렉터리는 만들지 않는다. 만드는 것은 `LearnDatabase.open(at:)` 의 일이다.
    public static func defaultURL() throws -> URL {
        let fileManager = FileManager.default
        guard let base = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            throw LocationError.applicationSupportUnavailable
        }
        let url = base
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        try validate(url)
        return url
    }

    /// 경로가 동기 폴더 안이면 던진다.
    public static func validate(_ url: URL) throws {
        let path = url.standardizedFileURL.path
        if let reason = syncRejectionReason(forPath: path) {
            throw LocationError.syncedFolder(path: path, reason: reason)
        }
    }

    /// 순수 문자열 판정 — 디스크를 만지지 않으므로 테스트가 가짜 경로로 전수 검증할 수 있다.
    ///
    /// 완전하지 않다는 걸 알고 쓴다. 사용자가 iCloud "데스크탑 및 문서" 동기화를 켜면
    /// `~/Documents` 도 동기 폴더가 되지만 경로만 봐서는 구별되지 않는다. 그래서 이 함수는
    /// **기본 경로를 지키는 가드**이지 임의 경로의 안전 증명이 아니다.
    public static func syncRejectionReason(forPath path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)

        // iCloud Drive. 앱 컨테이너든 CloudDocs 든 전부 여기 아래에 있다.
        if components.contains("Mobile Documents") || components.contains("com~apple~CloudDocs") {
            return "iCloud Drive 안에는 SQLite 파일을 둘 수 없다 (파일 evict 로 WAL 락이 깨진다)"
        }
        // macOS 12+ 의 File Provider 마운트 지점 — Dropbox·OneDrive·Google Drive 가 전부 여기로 온다.
        if components.contains("CloudStorage") {
            return "Library/CloudStorage 는 서드파티 동기 클라이언트의 마운트 지점이다"
        }
        for component in components {
            let lowered = component.lowercased()
            if lowered == "dropbox" || lowered.hasPrefix("dropbox ") {
                return "Dropbox 폴더 안에는 SQLite 파일을 둘 수 없다"
            }
            if lowered == "onedrive" || lowered.hasPrefix("onedrive-") || lowered.hasPrefix("onedrive ") {
                return "OneDrive 폴더 안에는 SQLite 파일을 둘 수 없다"
            }
            if lowered == "google drive" || lowered == "googledrive" || lowered == "my drive" {
                return "Google Drive 폴더 안에는 SQLite 파일을 둘 수 없다"
            }
            if lowered == "sync.com" || lowered == "pcloud drive" || lowered == "box sync" {
                return "서드파티 동기 폴더 안에는 SQLite 파일을 둘 수 없다"
            }
        }
        return nil
    }
}
