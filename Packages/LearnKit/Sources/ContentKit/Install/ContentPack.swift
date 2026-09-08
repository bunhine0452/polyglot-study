public import LearnCore


public import Foundation

/// 디스크에 있는 팩 하나를 읽는 창구.
///
/// 설치된 팩(`ContentPacks/<id>/<version>/`)이든 리포의 소스 팩(`Content/packs/<id>/`)이든
/// 같은 타입으로 읽는다. `packtool` 과 앱이 같은 코드로 팩을 보게 하려는 것이다 —
/// 검증기가 보는 팩과 앱이 보는 팩이 다르면 게이트는 아무것도 보장하지 못한다.
public struct ContentPack: Sendable {
    public let directory: URL
    public let manifest: PackManifest

    /// 매니페스트를 읽고 ``PackManifest/validate()`` 까지 통과시킨다.
    public init(directory: URL) throws(ContentPackError) {
        let manifestURL = directory.appendingPathComponent(PackLayout.manifestFileName)
        guard let data = FileManager.default.contents(atPath: manifestURL.path) else {
            throw .manifestMissing(directory.path)
        }
        let decoded: PackManifest
        do {
            decoded = try CanonicalJSON.decode(PackManifest.self, from: data)
        } catch {
            throw .manifestUndecodable("\(error)")
        }
        do {
            try decoded.validate()
        } catch {
            throw .manifestInvalid(error)
        }
        self.directory = directory
        self.manifest = decoded
    }

    public func url(for path: PackRelativePath) -> URL {
        directory.appendingPathComponent(path.rawValue)
    }

    public func data(at path: PackRelativePath) throws(ContentPackError) -> Data {
        guard let data = FileManager.default.contents(atPath: url(for: path).path) else {
            throw .fileMissing(path.rawValue)
        }
        return data
    }

    public func text(at path: PackRelativePath) throws(ContentPackError) -> String {
        String(decoding: try data(at: path), as: UTF8.self)
    }

    // MARK: - 레슨

    public func lessonSource(_ id: LessonID) throws(ContentPackError) -> String {
        guard let entry = manifest.lesson(id) else { throw .unknownLesson(id) }
        guard let path = try? PackRelativePath(validating: entry.path) else {
            throw .fileMissing(entry.path)
        }
        return try text(at: path)
    }

    /// 레슨 하나를 파싱한다.
    public func lesson(_ id: LessonID) throws(ContentPackError) -> LessonDocument {
        guard let entry = manifest.lesson(id) else { throw .unknownLesson(id) }
        guard let path = try? PackRelativePath(validating: entry.path) else {
            throw .fileMissing(entry.path)
        }
        let source = try text(at: path)
        do {
            return try LessonParser.parseDocument(
                source: source, stableID: entry.stableID, languages: entry.languages, path: path)
        } catch {
            throw .lessonParse(error)
        }
    }

    /// 모든 레슨을 매니페스트 순서대로 파싱한다.
    public func allLessons() throws(ContentPackError) -> [LessonDocument] {
        var documents: [LessonDocument] = []
        for entry in manifest.lessons {
            documents.append(try lesson(entry.stableID))
        }
        return documents
    }

    // MARK: - 잠금 파일

    public func lock() throws(ContentPackError) -> StableIDLock {
        let url = directory.appendingPathComponent(PackLayout.lockFileName)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw .fileMissing(PackLayout.lockFileName)
        }
        do {
            return try StableIDLock.parse(String(decoding: data, as: UTF8.self))
        } catch {
            throw .lockInvalid(error)
        }
    }

    /// 잠금이 이 매니페스트를 허락하는가.
    public func checkStableIDLock() throws(ContentPackError) {
        let lock = try self.lock()
        do {
            try lock.check(against: manifest)
        } catch {
            throw .lockViolation(error)
        }
    }

    // MARK: - 무결성

    /// `files` 의 모든 항목을 디스크와 대조한다. 크기 → sha256 순서.
    public func verifyChecksums() throws(ContentPackError) {
        for entry in manifest.files {
            let url = directory.appendingPathComponent(entry.path)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            else {
                throw .fileMissing(entry.path)
            }
            let size = (attributes[.size] as? Int) ?? -1
            guard size == entry.bytes else {
                throw .sizeMismatch(path: entry.path, expected: entry.bytes, actual: size)
            }
            guard let digest = try? FileDigest.sha256(ofFileAt: url) else {
                throw .fileMissing(entry.path)
            }
            guard digest == entry.sha256 else {
                throw .checksumMismatch(path: entry.path, expected: entry.sha256, actual: digest)
            }
        }
    }

    /// 모든 레슨을 파싱하고, 레슨이 참조하는 사이드카가 `files` 에 등록돼 있는지 본다.
    ///
    /// 매니페스트 검증은 레슨 **본문**까지 열지 않는다. `@Task(starter: …)` 가 가리키는
    /// 파일이 실제로 팩에 있는지는 본문을 파싱해야만 알 수 있고, 그 검사가 여기다.
    @discardableResult
    public func validateReferences() throws(ContentPackError) -> [LessonDocument] {
        let registered = Set(manifest.files.map(\.path))
        let documents = try allLessons()
        for document in documents {
            for path in document.referencedFiles where !registered.contains(path.rawValue) {
                throw .unregisteredReference(lesson: document.stableID, path: path.rawValue)
            }
        }
        return documents
    }
}

public enum ContentPackError: Error, Hashable, Sendable, CustomStringConvertible {
    case manifestMissing(String)
    case manifestUndecodable(String)
    case manifestInvalid(PackManifestError)
    case fileMissing(String)
    case unknownLesson(LessonID)
    case lessonParse(LessonParseError)
    case lockInvalid(StableIDLockError)
    case lockViolation(StableIDLockError)
    case sizeMismatch(path: String, expected: Int, actual: Int)
    case checksumMismatch(path: String, expected: String, actual: String)
    case unregisteredReference(lesson: LessonID, path: String)

    public var description: String {
        switch self {
        case .manifestMissing(let path): "\(PackLayout.manifestFileName) 이 없다: \(path)"
        case .manifestUndecodable(let detail): "매니페스트를 디코딩할 수 없다: \(detail)"
        case .manifestInvalid(let reason): "\(reason)"
        case .fileMissing(let path): "팩에 \(path) 가 없다"
        case .unknownLesson(let id): "매니페스트에 없는 레슨: \(id.rawValue)"
        case .lessonParse(let error): "\(error)"
        case .lockInvalid(let error): "\(PackLayout.lockFileName): \(error)"
        case .lockViolation(let error): "\(error)"
        case .sizeMismatch(let path, let expected, let actual):
            "\(path) 의 크기가 다르다 — 기대 \(expected)B, 실제 \(actual)B"
        case .checksumMismatch(let path, let expected, let actual):
            "\(path) 의 sha256 이 다르다 — 기대 \(expected), 실제 \(actual)"
        case .unregisteredReference(let lesson, let path):
            "레슨 \(lesson.rawValue) 이 참조하는 \(path) 가 files 에 없다"
        }
    }
}
