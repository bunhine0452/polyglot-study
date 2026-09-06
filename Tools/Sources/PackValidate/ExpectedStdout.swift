public import Foundation

/// 예제 stdout 을 기대 사이드카와 **바이트 단위로** 대조하기 위한 정규화 규칙.
///
/// ## 규칙 (v1)
///
/// 양쪽(기대 파일의 바이트와 러너가 낸 stdout 바이트)에 **똑같이** 적용한다.
///
/// 1. 맨 앞의 UTF-8 BOM(`EF BB BF`) 하나를 버린다. 편집기가 몰래 넣는 경우가 있고,
///    이것 하나 때문에 첫 줄이 통째로 어긋난 것처럼 보이는 것은 진단을 망친다.
/// 2. 줄바꿈을 LF 로 통일한다 — `CRLF → LF`, 단독 `CR → LF`.
///    (Windows 에서 편집된 기대 파일이 macOS 러너의 출력과 다르다고 보고되면 안 된다.)
/// 3. **후행 개행을 정확히 하나로 만든다.** 끝의 LF 를 전부 벗기고, 남은 내용이 있으면
///    LF 하나를 붙인다. 내용이 없으면 빈 바이트열이다.
///
/// 그리고 **이것이 전부다.** 줄 끝 공백, 줄 사이 빈 줄, 대소문자, 유니코드 정규화 —
/// 어느 것도 건드리지 않는다. `print("a ")` 와 `print("a")` 는 다른 프로그램이고,
/// 게이트가 그 둘을 같다고 하면 게이트가 아니다.
///
/// 3번을 규칙에 넣은 이유는 도구들의 관행이 갈리기 때문이다. 대부분의 편집기와 git 은
/// 텍스트 파일 끝에 개행을 하나 붙이고, `print` 도 개행으로 끝난다. 하지만 생성기가
/// 만든 사이드카에는 없을 수 있다. 여기서 접지 않으면 "보이지 않는 마지막 한 바이트"
/// 때문에 통과해야 할 팩이 떨어지고, 그 진단은 사람에게 읽히지 않는다.
public enum ExpectedStdout {
    /// 정규화된 바이트. 비교는 이 결과끼리 `==` 하나로 끝난다.
    public static func normalize(_ data: Data) -> Data {
        var bytes = Array(data)

        // ① BOM
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            bytes.removeFirst(3)
        }

        // ② 줄바꿈 통일
        var unified: [UInt8] = []
        unified.reserveCapacity(bytes.count)
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == 0x0D {  // CR
                unified.append(0x0A)
                index += 1
                if index < bytes.endIndex, bytes[index] == 0x0A { index += 1 }  // CRLF
                continue
            }
            unified.append(byte)
            index += 1
        }

        // ③ 후행 개행 정확히 하나
        while unified.last == 0x0A { unified.removeLast() }
        if !unified.isEmpty { unified.append(0x0A) }
        return Data(unified)
    }

    public static func normalize(_ text: String) -> Data { normalize(Data(text.utf8)) }

    /// 정규화 후 바이트가 같은가.
    public static func matches(expected: Data, actual: Data) -> Bool {
        normalize(expected) == normalize(actual)
    }

    /// 정규화된 바이트를 줄 배열로. 마지막 LF 뒤의 빈 줄은 세지 않는다.
    public static func lines(_ normalized: Data) -> [String] {
        guard !normalized.isEmpty else { return [] }
        var text = String(decoding: normalized, as: UTF8.self)
        if text.hasSuffix("\n") { text.removeLast() }
        return text.components(separatedBy: "\n")
    }
}
