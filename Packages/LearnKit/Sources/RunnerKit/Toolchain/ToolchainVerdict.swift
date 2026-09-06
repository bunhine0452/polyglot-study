public import LanguageKit
internal import Foundation

/// 후보 하나를 실제로 실행해 본 결과.
public struct ToolCandidateResult: Sendable, Hashable {
    public enum Verdict: Sendable, Hashable {
        /// 종료코드 0 + 버전 정규식 매치 + 스텁 문구 없음.
        case ready(version: ToolVersion)
        /// 동작은 하지만 최소 버전 미달.
        case belowMinimum(version: ToolVersion)
        /// 파일은 있으나 동작하지 않는다 (`/usr/bin/java`, CLT 미설치 shim).
        case stub(reason: String)
        /// 실행은 됐으나 버전을 못 읽었거나 실패했다.
        case failed(reason: String)
        /// 활성 개발자 디렉터리가 없어 **일부러 실행하지 않았다** — CLT 다이얼로그 회피.
        case skippedWithoutDeveloperDirectory
    }

    public var path: String
    /// 심링크를 푼 실제 경로. 캐시 키와 중복 제거에 쓴다.
    public var resolvedPath: String
    public var verdict: Verdict
    /// 어디서 발견했는가. 진단 로그용.
    public var origin: ToolCandidateOrigin

    public init(path: String, resolvedPath: String, verdict: Verdict, origin: ToolCandidateOrigin) {
        self.path = path
        self.resolvedPath = resolvedPath
        self.verdict = verdict
        self.origin = origin
    }

    public var readyVersion: ToolVersion? {
        if case let .ready(version) = verdict { return version }
        return nil
    }
}

public enum ToolCandidateOrigin: Sendable, Hashable {
    /// 수확된 PATH 의 몇 번째 항목인가.
    case searchPath(index: Int)
    case conventional
    case specDirectory
    case xcrun
}

/// 순수 판정 규칙. 프로세스를 띄우지 않으므로 테스트가 전 케이스를 고정할 수 있다.
public enum ToolchainVerdict {
    /// 버전 문자열 추출. 첫 매치의 **첫 번째 non-nil 캡처 그룹**(없으면 매치 전체).
    public static func extractVersion(pattern: String, from output: String) -> ToolVersion? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return nil
        }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, options: [], range: range) else { return nil }

        var text: String?
        if match.numberOfRanges > 1 {
            for index in 1..<match.numberOfRanges {
                let captured = match.range(at: index)
                if captured.location != NSNotFound, let swiftRange = Range(captured, in: output) {
                    text = String(output[swiftRange])
                    break
                }
            }
        }
        if text == nil, let whole = Range(match.range, in: output) {
            text = String(output[whole])
        }
        guard let text else { return nil }
        return ToolVersion(text)
    }

    /// 판정 규칙 (`{#availability-mapping}`):
    /// **종료코드 0 + 버전 정규식 매치 + 스텁 문구 비매치**만 `.ready`.
    public static func classify(spec: ToolSpec, result: BoundedCommandResult) -> ToolCandidateResult.Verdict {
        if let failure = result.launchFailure {
            return .failed(reason: "실행 실패: \(failure)")
        }
        let output = result.combinedOutput
        // 스텁 판정이 종료코드보다 먼저다. 스텁은 0 을 내는 경우도 있다.
        for marker in spec.stubMarkers where output.localizedCaseInsensitiveContains(marker) {
            return .stub(reason: firstLine(of: output) ?? marker)
        }
        if result.timedOut {
            return .failed(reason: "버전 질의가 시간 안에 끝나지 않았다")
        }
        if let signal = result.terminatingSignal {
            return .failed(reason: "시그널 \(signal) 로 종료")
        }
        guard result.exitCode == 0 else {
            return .failed(reason: "종료코드 \(result.exitCode): \(firstLine(of: output) ?? "출력 없음")")
        }
        guard let version = extractVersion(pattern: spec.versionPattern, from: output) else {
            return .failed(reason: "버전을 읽지 못했다: \(firstLine(of: output) ?? "출력 없음")")
        }
        if let minimum = spec.minimumVersion, version < minimum {
            return .belowMinimum(version: version)
        }
        return .ready(version: version)
    }

    /// 후보 전체에서 **버전 정책**으로 하나를 고른다 — PATH 순서가 아니다.
    ///
    /// 이 머신에서 `python3` 를 PATH 순서로 고르면 `/usr/bin/python3`(3.9.6)가 나오지만,
    /// 실제로 써야 하는 것은 conda 의 3.13 이다. 최소 버전 이상 중 **최고 버전**,
    /// 동률이면 먼저 발견된 것.
    public static func select(spec: ToolSpec, candidates: [ToolCandidateResult]) -> ModuleAvailability {
        var best: ToolCandidateResult?
        for candidate in candidates {
            guard let version = candidate.readyVersion else { continue }
            guard let current = best?.readyVersion else {
                best = candidate
                continue
            }
            if current < version { best = candidate }
        }
        if let best, let version = best.readyVersion {
            return .ready(version: version.raw, executablePath: best.path)
        }

        // 동작은 하는데 너무 낡았다 — 설치 안내가 아니라 업그레이드 안내가 필요하다.
        var newestBelow: (ToolVersion, String)?
        for candidate in candidates {
            guard case let .belowMinimum(version) = candidate.verdict else { continue }
            if newestBelow == nil || newestBelow!.0 < version {
                newestBelow = (version, candidate.path)
            }
        }
        if let newestBelow, let minimum = spec.minimumVersion {
            return .unsupported(
                reason: "\(spec.displayName) \(newestBelow.0.raw) 은 최소 요구 \(minimum.raw) 미만이다 (\(newestBelow.1)). \(spec.installHint)"
            )
        }

        if let stub = candidates.first(where: { if case .stub = $0.verdict { return true } else { return false } }) {
            let reason: String
            if case let .stub(text) = stub.verdict { reason = text } else { reason = "동작하지 않는 스텁" }
            return .stub(path: stub.path, reason: reason)
        }
        if let skipped = candidates.first(where: { $0.verdict == .skippedWithoutDeveloperDirectory }) {
            return .stub(
                path: skipped.path,
                reason: "활성 개발자 디렉터리가 없어 실행하지 않았다. xcode-select --install 후 다시 확인한다."
            )
        }
        if let failed = candidates.first(where: { if case .failed = $0.verdict { return true } else { return false } }) {
            let reason: String
            if case let .failed(text) = failed.verdict { reason = text } else { reason = "실행 실패" }
            return .stub(path: failed.path, reason: reason)
        }
        return .missing(installHint: spec.installHint)
    }

    static func firstLine(of text: String) -> String? {
        text.split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
