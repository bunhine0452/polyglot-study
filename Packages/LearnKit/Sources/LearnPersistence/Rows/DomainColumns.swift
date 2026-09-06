internal import LearnCore

// LearnCore 도메인 타입 ↔ SQLite 컬럼 값. **이 파일이 유일한 통로다.**
//
// 도메인 표현과 컬럼 표현이 다른 곳이 셋 있고, 셋 다 이유가 있다. 변환을 스토어마다
// 흩뿌리면 같은 열거형이 두 스펠링으로 저장되는 사고가 언젠가 난다.

/// `EpochMillis` 는 `INTEGER` 한 칸이다.
///
/// - Note: 원래 계획은 여기서 `EpochMillis` 에 GRDB 의 `DatabaseValueConvertible` 을
///   붙이는 것이었다. **컴파일이 안 된다.** `EpochMillis` 가 public 이라 준수도 public 이 되고,
///   Swift 6 의 접근 수준 import 규칙(SE-0409)은 public 준수가 참조하는 프로토콜을
///   public 하게 import 하라고 요구한다. 준수의 접근 수준만 낮출 문법은 없고
///   (`internal extension` 은 준수를 선언하는 확장에 못 붙는다), `package import GRDB` 도
///   준수가 여전히 public 이라 통하지 않는다. 남는 길은 `public import GRDB` 뿐인데 그건
///   `{#grdb-pin}` 이 금지하는 바로 그것이다 — GRDB 를 `LearnPersistence` 안에 가두는
///   전제가 무너진다. 그래서 준수 대신 **명시적 변환**을 쓴다. 대가는 행 구조체가
///   `.sqlValue` 를 한 번씩 부르는 것뿐이고, 어차피 행 매핑은 명시적인 게 이 계층의 방침이다.
extension EpochMillis {
    /// 컬럼으로 나가는 값.
    var sqlValue: Int64 { value }

    init(sqlValue: Int64) { self.init(sqlValue) }
}

/// `CardPhase` 는 정수 0..3 이지만 컬럼(`card_state.state`·`review_log.state_before`)은 TEXT 다.
///
/// 도메인이 정수인 것은 벤더 FSRS 의 `CardState` 와 값이 같아야 경계에서 재해석이 없기 때문이고,
/// 컬럼이 TEXT 인 것은 `sqlite3` 덤프를 사람이 읽기 때문이다(`state_before = 2` 보다 `'review'`).
/// 둘 다 맞는 요구라 어느 쪽도 양보시키지 않고 여기서 만난다.
extension CardPhase {
    var sqlText: String {
        switch self {
        case .new: return "new"
        case .learning: return "learning"
        case .review: return "review"
        case .relearning: return "relearning"
        }
    }

    init?(sqlText: String) {
        guard let match = CardPhase.allCases.first(where: { $0.sqlText == sqlText }) else { return nil }
        self = match
    }
}

/// `ReviewLogSource` 의 컬럼 스펠링. `review_log.source` 의 CHECK 리터럴과 1:1 이다.
///
/// `.review` 가 `'scheduled'` 로, `.imported` 가 `'import'` 로 나가는 것은 **출시된 스키마를
/// 따라간 것**이다. 마이그레이션 001 은 불변이고 CHECK 리터럴을 바꾸려면 새 마이그레이션과
/// 데이터 이행이 필요한데 그 값어치가 없다. 도메인 쪽 이름은 읽기 좋은 쪽으로 남긴다.
extension ReviewLogSource {
    var sqlText: String {
        switch self {
        case .review: return "scheduled"
        case .cram: return "cram"
        case .manual: return "manual"
        case .imported: return "import"
        }
    }

    init?(sqlText: String) {
        guard let match = ReviewLogSource.allCases.first(where: { $0.sqlText == sqlText }) else { return nil }
        self = match
    }
}
