internal import Darwin

/// 프로세스 그룹의 실제 메모리 사용량을 재고, 넘으면 그룹째 죽인다.
///
/// - Important: macOS 는 `RLIMIT_AS` / `RLIMIT_DATA` 를 **지원하지 않는다** — 설정하면
///   `EINVAL`. 따라서 메모리 상한은 rlimit 으로 걸 수 없고, 이 폴링이 유일한 길이다.
///   `learn-launcher` 에 `--memory` 플래그가 없는 것도 그래서다.
///
/// 그룹 전체를 세는 이유: 사용자 코드가 워커를 fork 하면 개별 프로세스는 상한 아래인데
/// 합계는 기가바이트일 수 있다. `proc_listpids(PROC_PGRP_ONLY, ...)` 로 열거해 합산한다.
public enum ProcessGroupMemory {
    /// 프로세스 그룹의 구성원 pid.
    ///
    /// 그룹이 비었으면 빈 배열. 손자가 스스로 `setsid` 해 나간 경우는 잡지 못한다 —
    /// 그건 `RLIMIT_NPROC` 과 `sandbox-exec` 이 막을 몫이다.
    public static func members(ofProcessGroup group: Int32) -> [Int32] {
        guard group > 0 else { return [] }

        // NULL 질의는 **필터를 무시하고 시스템 전체 프로세스 수**를 돌려준다(실측 확인).
        // 즉 상한 추정으로만 쓰고, 실제 개수는 버퍼를 받아 세야 한다.
        var capacity = Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0))
        if capacity <= 0 { capacity = 4096 * MemoryLayout<pid_t>.size }
        capacity *= 2

        let count = capacity / MemoryLayout<pid_t>.size
        var buffer = [pid_t](repeating: 0, count: max(count, 16))
        let bytes = buffer.withUnsafeMutableBufferPointer { pointer -> Int32 in
            proc_listpids(
                UInt32(PROC_PGRP_ONLY),
                UInt32(bitPattern: group),
                pointer.baseAddress,
                Int32(pointer.count * MemoryLayout<pid_t>.size)
            )
        }
        guard bytes > 0 else { return [] }
        let entries = Int(bytes) / MemoryLayout<pid_t>.size
        return buffer.prefix(entries).filter { $0 != 0 }
    }

    /// 한 프로세스의 `ri_phys_footprint` — 커널이 메모리 압박 판정에 쓰는 바로 그 값이다.
    /// RSS 와 달리 compressed·IOKit 매핑까지 포함해 실제 부담에 가깝다.
    public static func physicalFootprintBytes(ofProcess pid: Int32) -> UInt64? {
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard result == 0 else { return nil }
        return usage.ri_phys_footprint
    }

    /// 그룹 전체 합계. 죽은 프로세스는 조용히 건너뛴다.
    public static func physicalFootprintBytes(ofProcessGroup group: Int32) -> UInt64 {
        members(ofProcessGroup: group).reduce(into: UInt64(0)) { total, pid in
            total &+= (physicalFootprintBytes(ofProcess: pid) ?? 0)
        }
    }
}

/// 실행 하나에 붙어 메모리 상한을 강제하는 감시자.
public struct MemoryLimitEnforcer: Sendable {
    public var limitBytes: UInt64
    public var interval: Duration

    /// - Parameters:
    ///   - megabytes: `ResourceLimits.memoryMegabytes`.
    ///   - interval: 폴링 주기. 100ms 면 512MB 상한에서 초과분이 수십 MB 안쪽이다.
    public init(megabytes: Int, interval: Duration = .milliseconds(100)) {
        self.limitBytes = UInt64(max(0, megabytes)) * 1024 * 1024
        self.interval = interval
    }

    public init(limitBytes: UInt64, interval: Duration = .milliseconds(100)) {
        self.limitBytes = limitBytes
        self.interval = interval
    }

    /// 그룹을 감시한다.
    ///
    /// - Returns: 상한 초과로 **죽였으면** `true`. 그룹이 스스로 사라졌거나 태스크가
    ///   취소되면 `false`. 호출자는 이 값으로 `RunFailure.memoryExceeded` 를 결정한다 —
    ///   런처는 `SIGNAL 9` 만 보고하므로 폴러만이 사인을 안다.
    @discardableResult
    public func watch(processGroup group: Int32) async -> Bool {
        guard limitBytes > 0, group > 0 else { return false }
        while !Task.isCancelled {
            let members = ProcessGroupMemory.members(ofProcessGroup: group)
            if members.isEmpty { return false }

            var total: UInt64 = 0
            for pid in members {
                total &+= (ProcessGroupMemory.physicalFootprintBytes(ofProcess: pid) ?? 0)
            }
            if total > limitBytes {
                killpg(group, SIGKILL)
                return true
            }
            do {
                try await Task.sleep(for: interval)
            } catch {
                return false
            }
        }
        return false
    }
}
