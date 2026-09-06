internal import Foundation
internal import Darwin

/// 프로세스 그룹을 확실히 회수한다.
///
/// 런처가 정상 종료하면 스스로 `killpg` 하지만, 런처 자신이 SIGKILL 을 맞으면 그럴
/// 기회가 없다 — 취소 teardown 의 마지막 단계가 정확히 그 경우다. 그래서 부모도
/// 같은 일을 한 번 더 한다. `killpg` 는 멱등이므로 겹쳐도 해가 없다.
enum ProcessGroupReaper {
    /// 그룹을 죽이고 사라질 때까지 짧게 기다린다.
    ///
    /// - Returns: 상한 안에 그룹이 비었으면 `true`.
    @discardableResult
    static func reap(processGroup group: Int32, within limit: Duration = .seconds(2)) -> Bool {
        guard group > 0, group != getpgrp() else { return true }
        killpg(group, SIGKILL)
        return waitForVanish(processGroup: group, within: limit)
    }

    /// SIGKILL 회수에는 약간의 지연이 있다 — 보낸 직후의 단언은 항상 경쟁이다.
    static func waitForVanish(processGroup group: Int32, within limit: Duration) -> Bool {
        guard group > 0 else { return true }
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if ProcessGroupMemory.members(ofProcessGroup: group).isEmpty { return true }
            Thread.sleep(forTimeInterval: 0.005)
        }
        return ProcessGroupMemory.members(ofProcessGroup: group).isEmpty
    }

    /// 취소 핸들러에서 부르는 동기 경로. 기다리지 않고 신호만 던진다.
    static func kill(processGroup group: Int32) {
        guard group > 0, group != getpgrp() else { return }
        killpg(group, SIGKILL)
    }
}

/// 자식 프로세스가 이미 끝났는지 한 번에 판정한다.
///
/// `kill(pid, 0)` 으로는 알 수 없다 — 좀비도 시그널 대상으로는 살아 있다.
/// `PROC_PIDTBSDINFO` 의 상태값만이 "끝났지만 아직 회수되지 않았다"를 구별한다.
enum ChildProcessState {
    /// `<sys/proc.h>` 의 `SZOMB`. 헤더가 Swift 로 모듈화되지 않아 값을 직접 쓴다.
    private static let zombie: UInt32 = 5

    /// 종료했거나(좀비) 이미 사라졌으면 `true`.
    static func hasExited(_ pid: Int32) -> Bool {
        guard pid > 0 else { return true }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let read = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        // 조회 자체가 실패하면 프로세스가 이미 없다고 본다. 오탐의 대가는
        // "런처를 한 번 더 깨운다"뿐이라 안전한 쪽으로 기운다.
        guard read == size else { return true }
        return info.pbi_status == zombie
    }
}
