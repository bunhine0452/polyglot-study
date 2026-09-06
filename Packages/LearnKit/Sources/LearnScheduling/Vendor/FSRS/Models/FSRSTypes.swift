//
//  FSRSTypes.swift
//
//  Created by nkq on 10/13/24.
//

import Foundation

struct IPreview: Sendable {
    var recordLog: RecordLog

    init(recordLog: RecordLog) {
        self.recordLog = recordLog
    }

    subscript(rating: Rating) -> RecordLogItem? {
        get {
            recordLog[rating]
        }
        set {
            recordLog[rating] = newValue
        }
    }
}

protocol IScheduler {
    var preview: IPreview { get throws }
    func review(_ g: Rating) throws -> RecordLogItem
}

// ─── learnkit local modification ─────────────────────────────────────────────
// `RescheduleOptions` and `IReschedule` were removed together with
// `Scheduler/FSRSReschedule.swift` and `FSRS.reschedule(...)`. Nothing in the
// V6-only surface references them. See Vendor/FSRS/VENDORING.md.
// ─────────────────────────────────────────────────────────────────────────────
