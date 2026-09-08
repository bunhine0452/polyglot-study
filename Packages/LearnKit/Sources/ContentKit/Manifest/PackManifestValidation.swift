internal import LearnCore

extension PackManifest {
    /// 디스크를 보지 않고 매니페스트 **자체**의 일관성만 본다.
    ///
    /// 디스크 대조(sha256·존재 여부)를 여기 넣지 않은 이유는 호출 지점이 다르기 때문이다 —
    /// 이 검사는 `lessongen` 이 매니페스트를 굽는 순간에도 돌아야 하고, 그때는 아직
    /// 팩이 디렉터리로 존재하지 않는다. 디스크 검사는 ``PackInstaller`` 가 한다.
    ///
    /// - Throws: ``PackManifestError``. 깨진 방식마다 다른 케이스가 나온다.
    public func validate() throws(PackManifestError) {
        try validateHeader()
        try validateLanguages()
        try validateFiles()
        try validateLessons()
    }

    // MARK: - 헤더

    private func validateHeader() throws(PackManifestError) {
        guard schemaVersion >= 1 else { throw .invalidSchemaVersion(schemaVersion) }
        guard PackManifest.isSlug(packID.rawValue) else { throw .invalidPackID(packID.rawValue) }
        guard !displayName.trimmedForValidation.isEmpty else { throw .emptyDisplayName }

        do {
            _ = try SemanticVersion(parsing: version)
        } catch {
            throw .invalidVersion(field: "version", raw: version, reason: error)
        }
        do {
            _ = try SemanticVersion(parsing: minAppVersion)
        } catch {
            throw .invalidVersion(field: "minAppVersion", raw: minAppVersion, reason: error)
        }

        guard CanonicalJSON.isCanonicalTimestamp(generatedAt) else {
            throw .invalidTimestamp(generatedAt)
        }
    }

    private func validateLanguages() throws(PackManifestError) {
        guard !languages.isEmpty else { throw .emptyLanguages }
        var seen: Set<LanguageID> = []
        for language in languages {
            guard seen.insert(language).inserted else { throw .duplicateLanguage(language) }
        }
    }

    // MARK: - 파일

    private func validateFiles() throws(PackManifestError) {
        var seen: Set<String> = []
        for entry in files {
            let path: PackRelativePath
            do {
                path = try PackRelativePath(validating: entry.path)
            } catch {
                throw .unsafePath(field: "files[].path", raw: entry.path, reason: error)
            }
            guard PackLayout.isRegisterable(path) else { throw .fileOutsideLayout(entry.path) }
            guard seen.insert(path.rawValue).inserted else { throw .duplicateFilePath(entry.path) }
            guard PackManifest.isSHA256Hex(entry.sha256) else {
                throw .invalidChecksum(path: entry.path, raw: entry.sha256)
            }
            guard entry.bytes >= 0 else {
                throw .negativeFileSize(path: entry.path, bytes: entry.bytes)
            }
        }
    }

    // MARK: - 레슨

    private func validateLessons() throws(PackManifestError) {
        guard !lessons.isEmpty else { throw .emptyLessons }

        let registered = Set(files.compactMap { try? PackRelativePath(validating: $0.path).rawValue })
        let languageSet = Set(languages)
        var seenIDs: Set<LessonID> = []
        var seenOrders: Set<String> = []

        for lesson in lessons {
            guard PackManifest.isSlug(lesson.stableID.rawValue) else {
                throw .invalidStableID(lesson.stableID.rawValue)
            }
            guard seenIDs.insert(lesson.stableID).inserted else {
                throw .duplicateLessonID(lesson.stableID)
            }
            // 레슨이 선언한 언어는 **전부** 팩의 languages 안에 있어야 한다. 하나라도
            // 밖이면 그 언어를 고른 학습자가 실행기 없는 화면을 보게 된다.
            for language in lesson.languages where !languageSet.contains(language) {
                throw .unknownLanguage(language, lesson: lesson.stableID)
            }

            let path: PackRelativePath
            do {
                path = try PackRelativePath(validating: lesson.path)
            } catch {
                throw .unsafePath(field: "lessons[].path", raw: lesson.path, reason: error)
            }
            guard path.topLevelDirectory == PackLayout.lessonsDirectory else {
                throw .lessonPathOutsideLessonsDirectory(
                    lesson: lesson.stableID, path: lesson.path)
            }
            guard registered.contains(path.rawValue) else {
                throw .unregisteredFile(path: lesson.path, referencedBy: lesson.stableID)
            }

            // 순번은 **언어마다** 1부터다. 여러 언어를 담은 레슨은 그 언어들의 목록에
            // 모두 끼므로 각각에서 순번이 겹치지 않아야 한다.
            for language in lesson.languages {
                let orderKey = "\(language.rawValue)#\(lesson.order)"
                guard seenOrders.insert(orderKey).inserted else {
                    throw .duplicateOrder(language: language, order: lesson.order)
                }
            }
        }

        for lesson in lessons {
            for prerequisite in lesson.prerequisites where !seenIDs.contains(prerequisite) {
                throw .unknownPrerequisite(lesson: lesson.stableID, prerequisite: prerequisite)
            }
        }
    }

    // MARK: - 문법

    /// `packID` 와 `stableID` 에 허용되는 형태. 소문자·숫자·하이픈만이고 하이픈으로
    /// 시작·끝날 수 없다. 파일 이름·URL 조각·SQL 리터럴 어디에 놓여도 이스케이프가
    /// 필요 없어야 하기 때문이다.
    static func isSlug(_ raw: String) -> Bool {
        guard (1...64).contains(raw.count) else { return false }
        guard raw.first != "-", raw.last != "-" else { return false }
        return raw.allSatisfy { character in
            character.isASCII
                && ((character.isLowercase && character.isLetter) || character.isNumber
                    || character == "-")
        }
    }

    static func isSHA256Hex(_ raw: String) -> Bool {
        raw.count == 64
            && raw.allSatisfy { $0.isASCII && ($0.isNumber || ("a"..."f").contains($0)) }
    }
}

extension PackManifest {
    /// `schemaVersion` 과 `minAppVersion` 게이트.
    ///
    /// ``validate()`` 와 나눈 이유는 판정 주체가 다르기 때문이다 — 매니페스트가 옳은지는
    /// 팩만 보면 알지만, 열 수 있는지는 **앱 버전을 알아야** 안다. 같은 팩이 오늘은
    /// 거부되고 앱을 올리면 통과한다.
    public func checkCompatibility(
        appVersion: SemanticVersion,
        supportedSchemaVersion: Int = PackManifest.currentSchemaVersion,
        minimumSupportedSchemaVersion: Int = 1
    ) throws(PackCompatibilityError) {
        if schemaVersion > supportedSchemaVersion {
            throw .schemaTooNew(
                packSchema: schemaVersion, supported: supportedSchemaVersion, packID: packID)
        }
        if schemaVersion < minimumSupportedSchemaVersion {
            throw .schemaTooOld(
                packSchema: schemaVersion, supported: minimumSupportedSchemaVersion, packID: packID)
        }
        // semver 가 깨진 매니페스트는 `validate()` 가 이미 거부한다. 여기서는 파싱에
        // 실패하면 게이트를 통과시키지 않고 "앱이 낡았다"로 보수적으로 판정한다.
        guard let required = parsedMinAppVersion else {
            throw .appTooOld(
                required: SemanticVersion(major: .max, minor: 0, patch: 0),
                current: appVersion, packID: packID)
        }
        if appVersion < required {
            throw .appTooOld(required: required, current: appVersion, packID: packID)
        }
    }
}

extension String {
    fileprivate var trimmedForValidation: String {
        var text = Substring(self)
        while let first = text.first, first.isWhitespace { text = text.dropFirst() }
        while let last = text.last, last.isWhitespace { text = text.dropLast() }
        return String(text)
    }
}
