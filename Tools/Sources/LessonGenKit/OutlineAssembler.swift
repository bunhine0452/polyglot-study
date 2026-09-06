public import LearnCore

/// 모델의 초안을 최종 산출물로 옮긴다. 순수 함수다.
public enum OutlineAssembler {
    public static func assemble(
        draft: OutlineDraft,
        language: LanguageID,
        generatorModel: String
    ) throws(OutlineAssemblyError) -> TrackOutline {
        var seen: Set<String> = []
        for lesson in draft.lessons {
            guard !seen.contains(lesson.slug) else { throw .duplicateSlug(lesson.slug) }
            seen.insert(lesson.slug)
        }

        // 앞선 레슨만 선수로 인정한다. 뒤를 가리키면 여기서 걸린다.
        var available: Set<String> = []
        var lessons: [LessonOutline] = []
        lessons.reserveCapacity(draft.lessons.count)

        for (index, lesson) in draft.lessons.enumerated() {
            var prerequisites: [LessonID] = []
            for slug in lesson.prerequisiteSlugs {
                guard seen.contains(slug) else {
                    throw .unknownPrerequisite(lesson: lesson.slug, prerequisite: slug)
                }
                guard available.contains(slug) else {
                    throw .forwardPrerequisite(lesson: lesson.slug, prerequisite: slug)
                }
                prerequisites.append(stableID(language: language, slug: slug))
            }
            lessons.append(
                LessonOutline(
                    stableID: stableID(language: language, slug: lesson.slug),
                    ordinal: index + 1,
                    title: lesson.title,
                    summary: lesson.summary,
                    objectives: lesson.objectives,
                    prerequisites: prerequisites,
                    concepts: lesson.concepts,
                    estimatedMinutes: lesson.estimatedMinutes
                )
            )
            available.insert(lesson.slug)
        }

        return TrackOutline(
            language: language,
            trackTitle: draft.trackTitle,
            trackSummary: draft.trackSummary,
            generatorModel: generatorModel,
            lessons: lessons
        )
    }

    /// `<language>.<slug>`.
    public static func stableID(language: LanguageID, slug: String) -> LessonID {
        LessonID("\(language.rawValue).\(slug)")
    }
}

public enum OutlineAssemblyError: Error, Sendable, Hashable {
    case duplicateSlug(String)
    case unknownPrerequisite(lesson: String, prerequisite: String)
    case forwardPrerequisite(lesson: String, prerequisite: String)
}

extension OutlineAssemblyError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .duplicateSlug(let slug):
            "slug 가 중복됩니다: \(slug)"
        case .unknownPrerequisite(let lesson, let prerequisite):
            "레슨 '\(lesson)' 의 선수 레슨 '\(prerequisite)' 가 개요에 없습니다."
        case .forwardPrerequisite(let lesson, let prerequisite):
            "레슨 '\(lesson)' 이 뒤에 나오는 '\(prerequisite)' 를 선수로 지목했습니다."
        }
    }
}
