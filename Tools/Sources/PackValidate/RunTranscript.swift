internal import Foundation
internal import LanguageKit
internal import LearnCore

/// 실행 한 번이 남긴 것 전부. **요약하지 않는다** — 그대로 증거가 된다.
struct RunTranscript: Sendable {
    var stdout = Data()
    var stderr = Data()
    var diagnostics: [Diagnostic] = []
    var termination: RunTermination?
    var failure: RunFailure?
    /// 러너가 `ResourceLimits.outputBytes` 에서 잘랐다.
    var truncated = false

    var succeeded: Bool { failure == nil && (termination?.succeeded ?? false) }

    /// 리포트에 실을 러너 원문.
    ///
    /// 잘림은 **우리가** 요약한 것이 아니라 러너가 상한에서 자른 것이고, 그 사실이
    /// 증거에 명시된다. 우리가 몰래 줄이는 경로는 여기 없다.
    var evidence: String {
        var parts: [String] = []
        if let failure {
            parts.append("[실행 실패] \(Self.describe(failure))")
        }
        if let termination {
            let code = termination.exitCode.map(String.init) ?? "없음(인프로세스)"
            parts.append("[종료] 성공=\(termination.succeeded) 코드=\(code) \(termination.durationMilliseconds)ms")
        }
        if truncated {
            parts.append("[잘림] 러너가 outputBytes 상한에서 출력을 잘랐다")
        }
        if !diagnostics.isEmpty {
            let lines = diagnostics.map { diagnostic -> String in
                let position = diagnostic.line.map { ":\($0)" } ?? ""
                return "\(diagnostic.file ?? "?")\(position): \(diagnostic.severity.rawValue): \(diagnostic.message)"
            }
            parts.append("[진단]\n" + lines.joined(separator: "\n"))
        }
        parts.append("[stdout \(stdout.count)B]\n" + String(decoding: stdout, as: UTF8.self))
        parts.append("[stderr \(stderr.count)B]\n" + String(decoding: stderr, as: UTF8.self))
        return parts.joined(separator: "\n")
    }

    static func describe(_ failure: RunFailure) -> String {
        switch failure {
        case .toolchainMissing(let hint): "툴체인 없음 — \(hint)"
        case .wallClockExceeded(let seconds): "\(seconds)초 안에 끝나지 않았다"
        case .cpuExceeded(let seconds): "CPU \(seconds)초를 다 썼다"
        case .memoryExceeded(let megabytes): "메모리 \(megabytes)MB 초과"
        case .fileSizeExceeded(let bytes): "파일 크기 \(bytes)바이트 초과"
        case .cancelled: "취소됨"
        case .backend(let message): "실행기 오류 — \(message)"
        }
    }

    /// `CodeRunner` 스트림 하나를 통째로 받아 적는다.
    static func collect(_ stream: AsyncThrowingStream<RunEvent, any Error>) async -> RunTranscript {
        var transcript = RunTranscript()
        do {
            for try await event in stream {
                switch event {
                case .standardOutput(let data): transcript.stdout.append(data)
                case .standardError(let data): transcript.stderr.append(data)
                case .diagnostic(let diagnostic): transcript.diagnostics.append(diagnostic)
                case .truncated: transcript.truncated = true
                case .finished(let termination): transcript.termination = termination
                case .phase, .resultSet: continue
                }
            }
        } catch let error as RunFailure {
            transcript.failure = error
        } catch {
            transcript.failure = .backend("\(error)")
        }
        return transcript
    }
}
