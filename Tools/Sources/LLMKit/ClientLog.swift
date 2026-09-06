import Foundation

/// 클라이언트가 한 줄씩 뱉는 진행 로그의 목적지.
///
/// 공급자는 무엇을 받든 ``RedactingLog`` 로 감싸서 들고 있으므로,
/// 이 프로토콜을 구현한 쪽이 무엇을 하든 비밀값은 먼저 지워진다.
public protocol ClientLogSink: Sendable {
    func write(_ line: String)
}

/// 아무 데도 쓰지 않는다. 기본값.
public struct DiscardLog: ClientLogSink {
    public init() {}
    public func write(_ line: String) {}
}

/// stderr 로 내보낸다. stdout 은 생성 결과 전용으로 비워 둔다.
public struct StandardErrorLog: ClientLogSink {
    public init() {}
    public func write(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}

/// 어떤 sink 든 감싸서 비밀값을 지운 뒤 넘긴다.
///
/// 이 타입이 "로그에 키가 0건" 을 구조로 보장하는 지점이다 — 공급자가 자기 sink 를
/// 이걸로만 들고 있으므로 우회 경로가 없다.
public struct RedactingLog: ClientLogSink {
    private let redactor: Redactor
    private let inner: any ClientLogSink

    public init(redactor: Redactor, inner: any ClientLogSink) {
        self.redactor = redactor
        self.inner = inner
    }

    public func write(_ line: String) {
        inner.write(redactor.redact(line))
    }
}
