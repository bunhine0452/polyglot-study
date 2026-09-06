public import Foundation

/// 서버가 보낸 알림 하나. `params` 는 원본 바이트다 — 메서드를 아는 쪽이 디코드한다.
public struct LSPNotification: Hashable, Sendable {
    public var method: String
    public var payload: Data

    public init(method: String, payload: Data) {
        self.method = method
        self.payload = payload
    }
}

public enum LSPSessionError: Error, Hashable, Sendable, CustomStringConvertible {
    case notStarted
    case alreadyStarted
    /// 서버가 응답하기 전에 죽었다.
    case serverTerminated
    case decodingFailed(String)

    public var description: String {
        switch self {
        case .notStarted: "세션이 아직 시작되지 않았다."
        case .alreadyStarted: "세션은 한 번만 시작할 수 있다."
        case .serverTerminated: "언어 서버가 응답 전에 종료되었다."
        case .decodingFailed(let reason): "응답을 해석할 수 없다: \(reason)"
        }
    }
}

/// 장수명 양방향 LSP 세션 하나.
///
/// 다루는 것 넷: 요청/응답 상관, 서버발 알림 라우팅, 서버발 요청 응답, 취소.
///
/// ## 동시성 — 이 저장소가 세 번 밟은 함정
///
/// 이 프로젝트는 "예열해서 재사용하려고 공유한 자원에 동시 접근" 버그를 세 번 밟았다
/// (`SwiftTestingGrader` 의 공유 템플릿이 마지막이다). 액터로 감싸는 것만으로는
/// **부족하다** — 액터 메서드 안에서 `await` 하면 그 지점에서 재진입이 허용되고,
/// 두 호출이 서로의 중간 상태를 본다.
///
/// 여기서 그 함정이 나타나는 자리는 둘이다.
///
/// 1. **바이트 인터리빙.** `id 할당 → 프레임 만들기 → await transport.write` 순서로
///    쓰면 `await` 지점에서 다른 호출이 끼어들어 두 메시지의 바이트가 섞일 수 있다.
/// 2. **알림 순서 역전.** `didOpen` 과 `didChange` 는 순서가 곧 의미다. `await` 를
///    사이에 두면 version 2 가 version 1 보다 먼저 나갈 수 있고, 서버는 문서를 잃는다.
///
/// 해법은 락을 더 거는 것이 아니라 **await 를 없애는 것**이다. 나가는 모든 메시지는
/// `AsyncStream.Continuation.yield` 로 큐에 넣는다. `yield` 는 동기 함수라 중단점을
/// 만들지 않고, 큐를 빼는 작성자 태스크는 **하나뿐**이다. 그래서 "`yield` 가 불린 순서
/// = 바이트가 나가는 순서" 가 구조적으로 보장된다.
///
/// ## 격리 경계가 순서를 깨는 자리 — 리뷰에서 잡힌 결함
///
/// 큐를 액터 **안에** 두는 것만으로는 부족하다. `notify` 가 액터 격리 메서드이면
/// **부르는 쪽에 액터 홉이라는 중단점이 생기고**, 홉의 도착 순서는 보장되지 않는다
/// (SE-0306 은 액터의 실행 순서를 FIFO 로 약속하지 않는다).
///
/// 실제로 그렇게 깨졌다. `SwiftLanguageService.updateDocument` 가
/// `documentVersion += 1` 다음 줄에서 `await session.notify(didChange)` 를 부르고
/// 있었고, 키 입력마다 새 `Task` 가 뜨는 화면 배선과 만나 버전 3 이 버전 2 보다 먼저
/// 나갈 수 있었다. 게다가 그 상태는 **스스로 낫지 않는다** — 서비스는 최신 본문을
/// 이미 보냈다고 믿어 다시 보내지 않는다.
///
/// 그래서 `notify` 와 `outbound` 는 **`nonisolated`** 다. 순서가 곧 의미인 알림에서
/// 유일하게 옳은 배치다. 진입 순서 자체는 상위 계층이 동기 구간에서 정한다
/// (`SwiftLanguageService` 의 `editSequence`).
public actor LSPSession {
    private let transport: any LSPTransport

    /// 나가는 메시지 큐. 소비자는 작성자 태스크 **하나**뿐이다.
    private nonisolated let outboundQueue: AsyncStream<Data>
    /// **`nonisolated` 다.** 이게 액터에 갇혀 있으면 `notify` 가 액터 격리 메서드가
    /// 되고, 그러면 이 세션을 쓰는 상위 계층(`SwiftLanguageService`)에서
    /// `documentVersion += 1` 과 `notify(didChange)` 사이에 **액터 홉이라는 중단점**이
    /// 생긴다. 두 편집이 겹치면 버전 3 이 버전 2 보다 먼저 나가고, 서버는 낡은 본문을
    /// 최신으로 붙든다. `AsyncStream.Continuation` 은 `Sendable` 이고 `yield` 는
    /// 스레드 안전하므로 격리가 애초에 필요 없다.
    private nonisolated let outbound: AsyncStream<Data>.Continuation
    private nonisolated let notificationSink: AsyncStream<LSPNotification>.Continuation
    private var pumpTask: Task<Void, Never>?
    private var writerTask: Task<Void, Never>?

    private var nextRequestNumber = 1
    /// 보냈고 아직 결론이 안 난 요청.
    private var inFlight: Set<JSONRPCID> = []
    /// 응답을 기다리는 대기점.
    private var pending: [JSONRPCID: CheckedContinuation<Data, any Error>] = [:]
    /// 등록보다 취소가 **먼저** 도착한 요청. `withTaskCancellationHandler` 의 `onCancel`
    /// 은 액터 밖에서 돌기 때문에 액터 진입 순서가 뒤집힐 수 있다.
    private var cancelledBeforeRegistration: Set<JSONRPCID> = []
    private var isStarted = false
    private var isFinished = false

    /// 테스트가 "서버에 실제로 `$/cancelRequest` 가 나갔는가" 를 보는 통로가 아니다 —
    /// 그건 가짜 통로가 받은 바이트로 본다. 이건 세션 자신의 회계다.
    private(set) var cancelledRequestIDs: [JSONRPCID] = []

    /// 서버발 알림. `textDocument/publishDiagnostics` 가 여기로 온다.
    ///
    /// 스트림은 세션당 하나다. 소비자가 둘이면 알림이 갈린다 — 상위 계층
    /// (`SwiftLanguageService`)이 유일한 소비자다.
    ///
    /// `init` 에서 만든다. `start()` 에서 만들면 시작 전에 이 값을 잡아 둔 소비자가
    /// 영원히 빈 스트림을 듣게 된다.
    public nonisolated let notifications: AsyncStream<LSPNotification>

    public init(transport: any LSPTransport) {
        self.transport = transport
        // 진단은 타이핑할 때마다 온다. 무제한 버퍼는 소비자가 늦으면 메모리를 먹고,
        // 오래된 진단은 어차피 쓸모가 없다.
        let notificationPair = AsyncStream<LSPNotification>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        self.notifications = notificationPair.stream
        self.notificationSink = notificationPair.continuation

        let outboundPair = AsyncStream<Data>.makeStream(bufferingPolicy: .unbounded)
        self.outboundQueue = outboundPair.stream
        self.outbound = outboundPair.continuation
    }

    // MARK: - 수명

    /// 통로를 열고 펌프를 돌린다. `initialize` 는 보내지 않는다 — 그건 상위 계층 일이다.
    public func start() async throws {
        guard !isStarted else { throw LSPSessionError.alreadyStarted }
        isStarted = true

        let incoming = try await transport.open()

        // 작성자는 **하나**다. 이 태스크만 `transport.write` 를 부른다.
        writerTask = Task { [transport, outboundQueue] in
            for await payload in outboundQueue {
                do {
                    try await transport.write([UInt8](LSPFraming.frame(payload)))
                } catch {
                    // 서버가 죽어 파이프가 끊긴 것이다. 읽기 쪽이 곧 EOF 를 보고
                    // 대기 중인 요청을 전부 깨운다.
                    break
                }
            }
        }

        pumpTask = Task { [weak self] in
            var framer = LSPMessageFramer()
            do {
                for try await chunk in incoming {
                    framer.append(chunk)
                    while let payload = try framer.nextMessage() {
                        await self?.receive(payload)
                    }
                }
            } catch {
                // 프레이밍이 깨졌거나 통로가 오류로 끝났다. 어느 쪽이든 세션은 끝이다.
            }
            await self?.serverDidTerminate()
        }
    }

    /// 정상 종료 절차. `shutdown` 요청 → `exit` 알림 → 통로 닫기.
    ///
    /// `shutdown` 응답을 기다리지만 오래 기다리지 않는다 — 서버가 대답하지 않아도
    /// `exit` 과 stdin 닫기로 반드시 끝난다.
    public func shutdown(gracePeriod: Duration = .milliseconds(500)) async {
        guard isStarted, !isFinished else {
            await transport.close()
            // 시작 전에 걸린 요청이 남아 있을 수 있다. 여기서 깨우지 않으면 그 호출자는
            // 영원히 매달린다 — `finish` 가 그것을 푸는 유일한 지점이다.
            finish(resumingPendingWith: LSPSessionError.notStarted)
            return
        }

        let shutdownRequest = Task { [weak self] in
            _ = try? await self?.request(method: LSPMethod.shutdown)
        }
        let timeout = Task {
            try? await Task.sleep(for: gracePeriod)
            shutdownRequest.cancel()
        }
        await shutdownRequest.value
        timeout.cancel()

        notify(method: LSPMethod.exit)
        // 큐에 넣은 `exit` 이 실제로 나갈 시간을 준다. 작성자 태스크는 하나라
        // 여기서 스트림을 먼저 닫으면 `exit` 이 통째로 사라진다.
        outbound.finish()
        await writerTask?.value

        await transport.close()
        finish(resumingPendingWith: LSPSessionError.serverTerminated)
    }

    // MARK: - 보내기

    /// 알림 하나를 큐에 넣는다.
    ///
    /// **`nonisolated` 동기 함수다 — 부르는 쪽에 중단점을 만들지 않는다.** 이것이
    /// 알림 순서 보장의 핵심이다. 액터 격리 메서드였다면 호출마다 액터 홉이 생기고,
    /// 홉의 도착 순서는 보장되지 않는다(SE-0306 은 액터 실행 순서를 FIFO 로
    /// 약속하지 않는다). `didOpen` → `didChange` 처럼 순서가 곧 의미인 알림에서
    /// 그 역전은 서버가 문서를 잃는 것으로 나타난다.
    public nonisolated func notify(method: String, params: some Encodable & Sendable) {
        guard let payload = try? JSONRPCEncoder.notification(method: method, params: params) else {
            return
        }
        outbound.yield(payload)
    }

    public nonisolated func notify(method: String) {
        guard let payload = try? JSONRPCEncoder.notification(method: method) else { return }
        outbound.yield(payload)
    }

    /// 요청 하나를 보내고 응답 본문(봉투 전체)을 기다린다.
    ///
    /// 취소되면 서버에 `$/cancelRequest` 를 보내고 `CancellationError` 로 던진다.
    /// 그 뒤 늦게 도착하는 응답은 조용히 버려진다 — `pending` 에서 이미 빠졌기 때문에
    /// 이어지는 continuation 재개(= 크래시)가 구조적으로 불가능하다.
    public func request(method: String, params: some Encodable & Sendable) async throws -> Data {
        let id = allocateRequestID()
        let payload: Data
        do {
            payload = try JSONRPCEncoder.request(id: id, method: method, params: params)
        } catch {
            discardRequestID(id)
            throw error
        }
        return try await awaitResponse(id: id, payload: payload)
    }

    public func request(method: String) async throws -> Data {
        let id = allocateRequestID()
        let payload: Data
        do {
            payload = try JSONRPCEncoder.request(id: id, method: method)
        } catch {
            discardRequestID(id)
            throw error
        }
        return try await awaitResponse(id: id, payload: payload)
    }

    /// 요청을 보내고 `result` 를 원하는 타입으로 풀어 준다.
    public func request<Value: Decodable & Sendable>(
        method: String,
        params: some Encodable & Sendable,
        returning: Value.Type
    ) async throws -> Value {
        let payload = try await request(method: method, params: params)
        do {
            return try JSONRPCDecoder.result(Value.self, from: payload)
        } catch {
            throw LSPSessionError.decodingFailed("\(error)")
        }
    }

    // MARK: - 내부

    /// id 할당과 in-flight 등록은 **한 번의 동기 구간**이다. 중간에 `await` 가 없어야
    /// 두 호출이 같은 번호를 받거나 서로의 중간 상태를 보지 않는다.
    private func allocateRequestID() -> JSONRPCID {
        let id = JSONRPCID.number(nextRequestNumber)
        nextRequestNumber += 1
        inFlight.insert(id)
        return id
    }

    /// 인코딩이 실패해 보내지도 못한 id 를 회수한다. 안 지우면 `inFlight` 가 영원히
    /// 자란다(매달리지는 않는다 — continuation 이 아직 등록 전이다).
    private func discardRequestID(_ id: JSONRPCID) {
        inFlight.remove(id)
    }

    private func awaitResponse(id: JSONRPCID, payload: Data) async throws -> Data {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // 이 클로저는 액터에 격리돼 **동기적으로** 돈다. 등록과 큐 삽입이
                // 한 덩어리라 그 사이에 취소가 끼어들 수 없다.
                if cancelledBeforeRegistration.remove(id) != nil {
                    inFlight.remove(id)
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard isStarted else {
                    // 작성자 태스크는 `start()` 에서 만들어진다. 그 전에 큐에 넣으면
                    // 아무도 빼 가지 않아 이 요청이 영원히 매달린다.
                    inFlight.remove(id)
                    continuation.resume(throwing: LSPSessionError.notStarted)
                    return
                }
                guard !isFinished else {
                    inFlight.remove(id)
                    continuation.resume(throwing: LSPSessionError.serverTerminated)
                    return
                }
                pending[id] = continuation
                outbound.yield(payload)
            }
        } onCancel: {
            // `onCancel` 은 액터 밖에서 돈다. 액터에 들어가는 순서는 보장되지 않으므로
            // 등록보다 먼저 도착하는 경우를 위쪽 `cancelledBeforeRegistration` 이 받는다.
            Task { await self.cancelRequest(id) }
        }
    }

    /// 취소. **요청이 실제로 나간 경우에만** `$/cancelRequest` 를 보낸다.
    private func cancelRequest(_ id: JSONRPCID) {
        // 이미 결론이 난 요청이면 아무것도 하지 않는다. 이 가드가 없으면 끝난 요청에
        // 취소를 보내고(서버가 모르는 id 다) 유령 id 가 집합에 영원히 쌓인다.
        guard inFlight.contains(id) else { return }

        guard let continuation = pending.removeValue(forKey: id) else {
            // 아직 등록 전이다 = 프레임도 아직 큐에 안 들어갔다. 표시만 남기면
            // 등록하는 쪽이 보내지 않고 즉시 취소로 끝낸다.
            cancelledBeforeRegistration.insert(id)
            return
        }

        inFlight.remove(id)
        if let payload = try? JSONRPCEncoder.notification(
            method: LSPMethod.cancelRequest,
            params: CancelParams(id: id)
        ) {
            outbound.yield(payload)
            cancelledRequestIDs.append(id)
        }
        continuation.resume(throwing: CancellationError())
    }

    private func receive(_ payload: Data) {
        guard let incoming = try? JSONRPCDecoder.classify(payload) else { return }
        switch incoming {
        case .response(let id, let body):
            inFlight.remove(id)
            // `pending` 에 없으면 **취소된 요청의 늦은 응답**이다. 버린다.
            pending.removeValue(forKey: id)?.resume(returning: body)

        case .failure(let id, let error):
            inFlight.remove(id)
            guard let continuation = pending.removeValue(forKey: id) else { return }
            // 서버가 우리 취소를 받아 -32800 으로 답한 것이면, 호출자가 기대하는 것은
            // 서버 오류가 아니라 취소다.
            continuation.resume(throwing: error.isCancellation ? CancellationError() : error)

        case .notification(let method, let body):
            notificationSink.yield(LSPNotification(method: method, payload: body))

        case .serverRequest(let id, let method, _):
            respondToServerRequest(id: id, method: method)
        }
    }

    /// 서버발 요청에 **반드시 답한다.** 답하지 않으면 서버가 그 자리에서 기다린다.
    ///
    /// 우리는 능력을 최소로 광고하므로 여기 오는 것은 거의 없다. 그래도 무응답보다는
    /// 명시적 거절이 낫다 — 알 수 없는 메서드는 `MethodNotFound` 로 돌려보낸다.
    private func respondToServerRequest(id: JSONRPCID, method: String) {
        let payload: Data?
        switch method {
        case LSPMethod.registerCapability,
             LSPMethod.unregisterCapability,
             LSPMethod.workDoneProgressCreate:
            payload = try? JSONRPCEncoder.nullResponse(id: id)
        default:
            payload = try? JSONRPCEncoder.errorResponse(
                id: id,
                error: JSONRPCError(
                    code: JSONRPCError.methodNotFound,
                    message: "이 클라이언트는 \(method) 를 지원하지 않는다."
                )
            )
        }
        if let payload { outbound.yield(payload) }
    }

    /// 펌프가 끝났다. 서버가 죽었거나 **프레이밍이 깨진** 것이다.
    ///
    /// 통로를 여기서 닫는 이유: 서버가 스스로 죽은 경우에는 stdout 이 이미 닫혀 통로가
    /// 알아서 정리되지만, **프레이밍 오류로 우리가 먼저 포기한 경우**에는 서버가 멀쩡히
    /// 살아 있다. 닫지 않으면 그 프로세스가 화면을 떠날 때까지 남는다.
    private func serverDidTerminate() async {
        finish(resumingPendingWith: LSPSessionError.serverTerminated)
        await transport.close()
    }

    /// 대기 중인 모든 요청을 깨우고 스트림을 닫는다. 두 번 불려도 안전하다.
    private func finish(resumingPendingWith error: any Error) {
        guard !isFinished else { return }
        isFinished = true
        let waiting = pending
        pending.removeAll()
        inFlight.removeAll()
        for (_, continuation) in waiting {
            continuation.resume(throwing: error)
        }
        notificationSink.finish()
        outbound.finish()
    }
}
