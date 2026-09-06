internal import PackReport

/// 레슨별 실패를 **선언 순서대로** 모으는 그릇.
///
/// `PackValidationReport` 는 레슨 배열 하나뿐이라 "어느 레슨의 것도 아닌 실패"
/// (매니페스트 디코딩 실패, 잠금 위반, 등록되지 않은 자산 파일)를 담을 자리가 없다.
/// 그래서 팩 전체를 가리키는 합성 슬롯 하나를 맨 앞에 둔다 — `stableID` 는
/// ``FailureTable/packLevelStableID`` 로 고정이고, 실제 레슨 id 와 충돌할 수 없는
/// 모양(`<pack>`)이라 `lessongen repair` 가 레슨으로 오해하지 않는다.
struct FailureTable {
    /// 팩 전체 실패가 붙는 합성 레슨 id. slug 규칙(소문자·숫자·하이픈)을 일부러 어겨
    /// 진짜 `stableID` 와 절대 겹치지 않게 했다.
    static let packLevelStableID = "<pack>"

    private struct Slot {
        var language: String
        var title: String
        var failures: [PackValidationReport.Failure] = []
    }

    private var order: [String] = []
    private var slots: [String: Slot] = [:]

    /// 레슨 자리를 잡는다. 실패가 없어도 리포트에 나와야 하므로 미리 선언한다.
    mutating func declare(stableID: String, language: String, title: String) {
        guard slots[stableID] == nil else { return }
        order.append(stableID)
        slots[stableID] = Slot(language: language, title: title)
    }

    mutating func add(_ failure: PackValidationReport.Failure, to stableID: String) {
        if slots[stableID] == nil {
            order.append(stableID)
            slots[stableID] = Slot(language: "-", title: stableID)
        }
        slots[stableID]?.failures.append(failure)
    }

    mutating func addPackLevel(_ failure: PackValidationReport.Failure) {
        if slots[Self.packLevelStableID] == nil {
            // 팩 전체 실패는 항상 맨 앞이다 — 뒤에 오는 레슨 실패의 원인인 경우가 많다.
            order.insert(Self.packLevelStableID, at: 0)
            slots[Self.packLevelStableID] = Slot(language: "-", title: "팩 전체")
        }
        slots[Self.packLevelStableID]?.failures.append(failure)
    }

    func failures(of stableID: String) -> [PackValidationReport.Failure] {
        slots[stableID]?.failures ?? []
    }

    func isClean(_ stableID: String) -> Bool { failures(of: stableID).isEmpty }

    /// 리포트에 실을 결과들. 합성 슬롯은 실패가 있을 때만 남는다.
    func lessonResults() -> [PackValidationReport.LessonResult] {
        order.compactMap { id in
            guard let slot = slots[id] else { return nil }
            if id == Self.packLevelStableID, slot.failures.isEmpty { return nil }
            return PackValidationReport.LessonResult(
                stableID: id,
                language: slot.language,
                title: slot.title,
                failures: slot.failures
            )
        }
    }
}
