import LearnCore

/// 개요 하나에 대한 지적.
public struct OutlineIssue: Sendable, Hashable, CustomStringConvertible {
    /// 어디가 문제인지. `lessons[3].objectives` 같은 경로.
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    public var description: String { "\(path): \(message)" }
}

/// 개요 검증. 사람이 리뷰하기 **전에** 기계가 먼저 훑는다 (쟁점 4).
///
/// 여기서 잡는 것은 순수하게 구조적인 결함뿐이다 — 내용이 맞는지는 사람과
/// `packtool validate` 의 실행 게이트가 본다.
public enum OutlineValidator {
    public static func validate(_ outline: TrackOutline) -> [OutlineIssue] {
        var issues: [OutlineIssue] = []

        if outline.schemaVersion != TrackOutline.currentSchemaVersion {
            issues.append(
                OutlineIssue(
                    path: "schemaVersion",
                    message: "지원하지 않는 스키마 버전 \(outline.schemaVersion) "
                        + "(기대: \(TrackOutline.currentSchemaVersion))"
                )
            )
        }
        if !isKebabIdentifier(outline.language.rawValue) {
            issues.append(OutlineIssue(path: "language", message: "언어 ID 가 소문자 kebab 이 아닙니다: \(outline.language.rawValue)"))
        }
        if outline.trackTitle.isBlank {
            issues.append(OutlineIssue(path: "trackTitle", message: "비어 있습니다."))
        }
        if outline.trackSummary.isBlank {
            issues.append(OutlineIssue(path: "trackSummary", message: "비어 있습니다."))
        }
        if outline.generatorModel.isBlank {
            issues.append(OutlineIssue(path: "generatorModel", message: "비어 있습니다."))
        }
        if outline.lessons.isEmpty {
            issues.append(OutlineIssue(path: "lessons", message: "레슨이 하나도 없습니다."))
            return issues
        }

        let prefix = outline.language.rawValue + "."
        var seenIDs: Set<String> = []
        var idToOrdinal: [String: Int] = [:]
        for lesson in outline.lessons { idToOrdinal[lesson.stableID.rawValue] = lesson.ordinal }

        for (index, lesson) in outline.lessons.enumerated() {
            let path = "lessons[\(index)]"
            let id = lesson.stableID.rawValue

            if !id.hasPrefix(prefix) {
                issues.append(OutlineIssue(path: "\(path).stableID", message: "'\(prefix)' 로 시작해야 합니다: \(id)"))
            } else if !isKebabIdentifier(String(id.dropFirst(prefix.count))) {
                issues.append(OutlineIssue(path: "\(path).stableID", message: "슬러그가 소문자 kebab 이 아닙니다: \(id)"))
            }
            if !seenIDs.insert(id).inserted {
                issues.append(OutlineIssue(path: "\(path).stableID", message: "중복된 stableID: \(id)"))
            }
            if lesson.ordinal != index + 1 {
                issues.append(OutlineIssue(path: "\(path).ordinal", message: "순번이 \(index + 1) 이어야 하는데 \(lesson.ordinal) 입니다."))
            }
            if lesson.title.isBlank {
                issues.append(OutlineIssue(path: "\(path).title", message: "비어 있습니다."))
            }
            if lesson.summary.isBlank {
                issues.append(OutlineIssue(path: "\(path).summary", message: "비어 있습니다."))
            }
            if lesson.objectives.isEmpty {
                issues.append(OutlineIssue(path: "\(path).objectives", message: "학습목표가 없습니다."))
            }
            for (objectiveIndex, objective) in lesson.objectives.enumerated() where objective.isBlank {
                issues.append(OutlineIssue(path: "\(path).objectives[\(objectiveIndex)]", message: "비어 있습니다."))
            }
            if lesson.concepts.isEmpty {
                issues.append(OutlineIssue(path: "\(path).concepts", message: "개념 키워드가 없습니다."))
            }
            if !(1...240).contains(lesson.estimatedMinutes) {
                issues.append(OutlineIssue(path: "\(path).estimatedMinutes", message: "1~240 분 밖입니다: \(lesson.estimatedMinutes)"))
            }

            var seenPrerequisites: Set<String> = []
            for (prerequisiteIndex, prerequisite) in lesson.prerequisites.enumerated() {
                let prerequisitePath = "\(path).prerequisites[\(prerequisiteIndex)]"
                let raw = prerequisite.rawValue
                if raw == id {
                    issues.append(OutlineIssue(path: prerequisitePath, message: "자기 자신을 선수로 지목했습니다."))
                    continue
                }
                if !seenPrerequisites.insert(raw).inserted {
                    issues.append(OutlineIssue(path: prerequisitePath, message: "중복된 선수 레슨: \(raw)"))
                }
                guard let ordinal = idToOrdinal[raw] else {
                    issues.append(OutlineIssue(path: prerequisitePath, message: "개요에 없는 레슨입니다: \(raw)"))
                    continue
                }
                if ordinal >= lesson.ordinal {
                    issues.append(OutlineIssue(path: prerequisitePath, message: "뒤에 나오는 레슨입니다(순번 \(ordinal)): \(raw)"))
                }
            }
        }

        return issues
    }

    /// `list-comprehension` 같은 소문자 kebab 인가.
    public static func isKebabIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let segments = value.split(separator: "-", omittingEmptySubsequences: false)
        guard segments.allSatisfy({ !$0.isEmpty }) else { return false }
        return segments.allSatisfy { segment in
            segment.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) }
        }
    }
}

extension String {
    fileprivate var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
