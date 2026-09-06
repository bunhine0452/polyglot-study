internal import Foundation

/// 서버와의 바이트 통로. 프레이밍도 JSON-RPC 도 모른다.
///
/// 이 경계가 있는 이유는 하나다: **세션 전체를 프로세스 없이 테스트하기 위해서**다.
/// 요청/응답 상관, 서버발 알림 라우팅, `$/cancelRequest` 는 전부 여기 위에서 돌아가고,
/// 테스트는 바이트를 직접 밀어 넣는 가짜 통로를 끼운다.
public protocol LSPTransport: Sendable {
    /// 서버를 띄우고 stdout 바이트 스트림을 연다. 세션당 **정확히 한 번** 불린다.
    /// 스트림이 끝나면 서버가 죽은 것이다.
    func open() async throws -> AsyncThrowingStream<[UInt8], any Error>

    /// 프레임 하나를 stdin 에 쓴다.
    ///
    /// **호출 순서가 바이트 순서다.** 세션이 단일 작성자 태스크로 직렬화해서 부르므로
    /// 구현이 내부에서 다시 잠글 필요는 없다.
    func write(_ bytes: [UInt8]) async throws

    /// stdin 을 닫아 서버에게 EOF 를 보이고, 유예 뒤 프로세스를 거둔다.
    func close() async
}

public enum LSPTransportError: Error, Hashable, Sendable, CustomStringConvertible {
    /// `xcrun --find sourcekit-lsp` 가 실패했다. 이 머신에는 Swift 지원이 없다.
    case serverUnavailable(String)
    case launchFailed(String)
    case alreadyOpened
    case closed

    public var description: String {
        switch self {
        case .serverUnavailable(let reason): "sourcekit-lsp 를 찾을 수 없다: \(reason)"
        case .launchFailed(let reason): "sourcekit-lsp 를 띄우지 못했다: \(reason)"
        case .alreadyOpened: "이미 열린 통로다."
        case .closed: "통로가 닫혔다."
        }
    }
}
