internal import LanguageKit
internal import Subprocess
internal import Darwin

/// 한 번의 서브프로세스 실행에서 종료 사인이 될 만한 것 전부.
///
/// 이 타입이 존재하는 이유는 **같은 SIGKILL 이 세 가지 뜻을 갖기 때문**이다.
///   - 벽시계 초과 → 런처가 `TIMEOUT` 을 남기고 `killpg`
///   - 메모리 초과 → 부모의 폴러가 `killpg` (런처는 `SIGNAL 9` 만 본다)
///   - 사용자 취소 → teardown 이 런처를 죽이고 런처가 그룹을 데려간다
/// 종료 상태만 보면 셋이 구별되지 않는다. 사인은 세 갈래 정보를 합쳐야 나온다.
struct SubprocessRunOutcome: Sendable {
    /// `--status-fd` 에서 읽은 것.
    var launcher: LauncherOutcome
    /// 런처 프로세스 자신의 종료 상태. status 라인이 비었을 때의 폴백.
    var launcherTermination: TerminationStatus?
    /// 메모리 폴러가 그룹을 죽였는가.
    var memoryKilled = false
    /// 소비자가 스트림을 취소했는가.
    var cancelled = false
    var durationMilliseconds = 0

    /// 사인을 `RunFailure` 또는 `RunTermination` 으로 접는다.
    ///
    /// - Throws: 자원 상한 위반·취소·백엔드 오류.
    func resolve(limits: ResourceLimits, executablePath: String) throws -> RunTermination {
        if cancelled { throw RunFailure.cancelled }

        // 런처가 exec 에 실패했다면 그건 상한 문제가 아니라 툴체인 문제다.
        // 사용자 코드는 시작조차 못 했으므로 학습자에게 줄 조언이 완전히 다르다.
        if let failure = launcher.launcherFailure, failure.stage == "exec" {
            switch failure.errorNumber {
            case ENOENT, EACCES, ENOEXEC:
                throw RunFailure.toolchainMissing(
                    hint: "\(executablePath) 를 실행할 수 없다 (errno \(failure.errorNumber))."
                )
            default:
                break
            }
        }

        if let failure = launcher.failure(limits: limits, memoryKilled: memoryKilled) {
            throw failure
        }

        if let termination = launcher.termination {
            return Self.termination(from: termination, durationMilliseconds: durationMilliseconds)
        }

        // status fd 가 비었다 — 런처가 status 라인을 쓰기 전에 사라졌다는 뜻이다.
        // 런처 자신의 종료 상태로 최대한 복구한다.
        guard let launcherTermination else {
            throw RunFailure.backend("런처가 종료 사인을 남기지 않았다")
        }
        switch launcherTermination {
        case .exited(let code):
            // 125 는 런처 자신의 실패 전용 코드다. 여기 왔다는 것은 `ERR` 라인조차
            // 못 썼다는 뜻이라 사용자 코드의 종료 코드로 넘겨서는 안 된다.
            if code == 125 {
                throw RunFailure.backend("런처가 사인 없이 125 로 종료했다")
            }
            return .exitCode(code, durationMilliseconds: durationMilliseconds)
        case .signaled(let number):
            if number == SIGXCPU { throw RunFailure.cpuExceeded(seconds: limits.cpuSeconds) }
            if number == SIGXFSZ { throw RunFailure.fileSizeExceeded(bytes: limits.fileSizeBytes) }
            return RunTermination(
                status: .failed(code: 128 &+ number),
                durationMilliseconds: durationMilliseconds
            )
        }
    }

    /// 시그널 종료는 셸 관례대로 `128 + signo` 로 접는다.
    ///
    /// `RunTermination` 이 종료 코드를 `Int32?` 로 둔 것은 "코드가 없는 백엔드"를 위한
    /// 것이지 "코드를 모르겠다"가 아니다. 시그널로 죽은 프로세스에는 관례적 코드가
    /// 있으므로 그걸 쓴다 — 계약 스위트가 `SIGSEGV` 와 `exit(139)` 를 같게 본다.
    private static func termination(
        from termination: LauncherTermination,
        durationMilliseconds: Int
    ) -> RunTermination {
        switch termination {
        case .exited(let code):
            return .exitCode(code, durationMilliseconds: durationMilliseconds)
        case .signalled(let number):
            return RunTermination(
                status: .failed(code: 128 &+ number),
                durationMilliseconds: durationMilliseconds
            )
        }
    }
}

extension RunFailure {
    /// `SubprocessError` 는 `RunFailure.backend` 로만 새어 나간다.
    ///
    /// 계약이 아는 실패는 여섯 가지뿐이고 swift-subprocess 의 내부 오류 코드는 그중
    /// 어디에도 속하지 않는다. 그대로 노출하면 UI 가 백엔드 라이브러리의 열거형을
    /// 분기하게 되고, 백엔드를 갈아끼우는 순간 그 분기가 전부 죽는다.
    static func fromBackend(_ error: any Error, executablePath: String) -> RunFailure {
        if let failure = error as? RunFailure { return failure }
        if error is CancellationError { return .cancelled }
        if let subprocessError = error as? SubprocessError {
            if subprocessError.code == .executableNotFound {
                return .toolchainMissing(hint: "\(executablePath) 를 찾을 수 없다.")
            }
            return .backend("subprocess: \(subprocessError)")
        }
        return .backend("\(error)")
    }
}
