public import struct Foundation.Data
public import struct Foundation.Date

/// 매니페스트의 **정규 바이트** 규칙. 같은 값이면 언제 어디서 구워도 같은 바이트가 나온다.
///
/// 규칙을 물리화하는 이유는 서명 때문이다. 나중에 `packtool sign` 이 붙으면 서명 대상은
/// "매니페스트가 표현하는 값"이 아니라 **바이트열**이다. 인코더 설정이 조금만 흔들려도
/// 서명이 통째로 무효가 되므로, 인코더를 부르는 자리를 여기 하나로 모은다.
///
/// - 키는 UTF-8 사전순으로 정렬한다.
/// - 들여쓰기는 2칸, 줄바꿈은 LF, 파일 끝에 개행 하나.
/// - `/` 를 이스케이프하지 않는다 — 값의 대부분이 경로라 가독성 차이가 크다.
/// - 타임스탬프는 **호출자가 넣는 입력**이다. 인코딩 시점에 `Date()` 를 읽는 코드는 여기 없다.
///   팩 매니페스트의 `generatedAt` 은 git commit date 에서 온다.
public enum CanonicalJSON {
    /// 정규 바이트로 인코딩한다. 결과는 항상 LF 로 끝난다.
    public static func encode(_ value: some Encodable) throws -> Data {
        try CanonicalCoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try CanonicalCoder.decode(type, from: data)
    }

    /// 정규 바이트를 문자열로. 로그와 테스트 실패 메시지용.
    public static func string(_ value: some Encodable) throws -> String {
        String(decoding: try encode(value), as: UTF8.self)
    }

    // MARK: - 타임스탬프

    /// `2026-09-06T12:34:56Z` — UTC, 초 정밀도, 오프셋 표기 없음.
    ///
    /// 소수점 이하와 `+09:00` 표기를 뺀 이유는 같은 순간을 여러 문자열로 쓸 수 있게
    /// 되면 정규 바이트가 아니게 되기 때문이다.
    public static func canonicalTimestamp(_ date: Date) -> String {
        CanonicalCoder.timestamp(date)
    }

    /// 문자열이 정규 타임스탬프인지. 파싱이 아니라 형식 검사다 — 매니페스트 검증이
    /// 알아야 하는 것은 "이 문자열이 정규형인가" 하나뿐이다.
    public static func isCanonicalTimestamp(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        guard bytes.count == 20 else { return false }
        let digitPositions = [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18]
        for index in digitPositions where !(bytes[index] >= 0x30 && bytes[index] <= 0x39) {
            return false
        }
        guard bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") else { return false }
        guard bytes[10] == UInt8(ascii: "T") else { return false }
        guard bytes[13] == UInt8(ascii: ":"), bytes[16] == UInt8(ascii: ":") else { return false }
        guard bytes[19] == UInt8(ascii: "Z") else { return false }

        func number(_ range: Range<Int>) -> Int {
            bytes[range].reduce(0) { $0 * 10 + Int($1 - 0x30) }
        }
        let month = number(5..<7)
        let day = number(8..<10)
        let hour = number(11..<13)
        let minute = number(14..<16)
        let second = number(17..<19)
        guard (1...12).contains(month), (1...31).contains(day) else { return false }
        // 윤초는 받지 않는다. 팩 생성 시각이 윤초일 확률보다 파서가 달라질 위험이 크다.
        return hour <= 23 && minute <= 59 && second <= 59
    }
}
