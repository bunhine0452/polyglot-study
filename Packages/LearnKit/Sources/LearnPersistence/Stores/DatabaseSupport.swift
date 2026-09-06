internal import GRDB
internal import LearnCore

/// GRDB 실패를 도메인 실패로 옮긴다.
///
/// `DatabaseError` 가 스토어 밖으로 나가면 UI 가 SQLite 결과코드를 해석하게 되고, 그때부터
/// 백엔드 교체가 불가능해진다. 원문은 `message` 에 실어 디버깅 경로만 남긴다.
func mapDatabaseError(_ error: any Error) -> any Error {
    if let error = error as? StoreError { return error }
    guard let dbError = error as? DatabaseError else { return error }

    let message = dbError.message ?? "\(dbError)"

    // review_log 의 append-only 트리거는 RAISE(ABORT) 라 SQLITE_CONSTRAINT_TRIGGER 로 올라온다.
    if dbError.extendedResultCode == .SQLITE_CONSTRAINT_TRIGGER,
       message.contains("append-only") {
        let operation = message.contains("UPDATE") ? "UPDATE" : "DELETE"
        return StoreError.appendOnlyViolation(table: "review_log", operation: operation)
    }
    if dbError.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY {
        return StoreError.notFound(entity: "foreign key", id: message)
    }
    if dbError.resultCode == .SQLITE_CONSTRAINT {
        return StoreError.constraint(message: message)
    }
    return StoreError.storage(message: message)
}

extension DatabaseWriter {
    /// 쓰기 + 에러 변환. 스토어가 매번 do/catch 를 반복하지 않게.
    func writeMapped<T: Sendable>(_ body: @Sendable (Database) throws -> T) async throws -> T {
        do {
            return try await write(body)
        } catch {
            throw mapDatabaseError(error)
        }
    }
}

extension DatabaseReader {
    func readMapped<T: Sendable>(_ body: @Sendable (Database) throws -> T) async throws -> T {
        do {
            return try await read(body)
        } catch {
            throw mapDatabaseError(error)
        }
    }
}

/// `ValueObservation` 을 `AsyncSequence` 로 노출한다.
///
/// GRDB 가 이미 `values(in:)` 로 `AsyncValueObservation` 을 주지만, 그 타입이 시그니처에 나오면
/// GRDB 가 `LearnCore` 프로토콜까지 새어 나온다. 그래서 여기서 한 겹 감싸 표준
/// `AsyncThrowingStream` 으로 바꾼다. 비용은 continuation 하나뿐이고, 관찰의 실제 일
/// (트랜잭션 추적, 초기값 전달, 병합)은 전부 GRDB 가 한다.
///
/// 구독이 끊기면 `onTermination` 이 태스크를 취소하고, 취소가 GRDB 관찰을 정리한다.
///
/// `removeDuplicates()` 를 거는 이유: GRDB 는 **관찰 대상 테이블이 바뀔 때마다** 발화한다.
/// "python 트랙의 due 개수" 를 보고 있는데 sql 카드 하나가 갱신되면 같은 값이 한 번 더 온다.
/// 그대로 두면 UI 가 이유 없이 다시 그려지고, 페이크 구현과 발화 횟수도 달라진다.
func makeObservationStream<Value: Sendable & Equatable>(
    reader: any DatabaseReader,
    fetch: @escaping @Sendable (Database) throws -> Value
) -> AsyncThrowingStream<Value, any Error> {
    let observation = ValueObservation.tracking(fetch).removeDuplicates()
    return AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for try await value in observation.values(in: reader) {
                    continuation.yield(value)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: mapDatabaseError(error))
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
