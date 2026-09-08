public import LearnCore

/// 연습장 파일 하나.
///
/// 레슨의 과제와 달리 **이름이 학습자의 것**이다. 그래서 `id` 를 따로 두지 않고 이름을
/// 신원으로 쓴다 — 이름을 바꾸면 다른 파일이 되는 것이 맞다(디스크에서도 그렇다).
public struct ScratchFile: Hashable, Sendable, Identifiable {
    public var name: String
    public var contents: String

    public var id: String { name }

    public init(name: String, contents: String) {
        self.name = name
        self.contents = contents
    }
}

/// 연습장이 지원하는 언어. **실행기와 채점기가 있는 것만** 있다.
///
/// `LanguageID` 를 그대로 쓰지 않고 좁히는 이유는 화면이 언어마다 다른 사실을 알아야
/// 하기 때문이다 — 기본 파일 이름, 새 파일의 확장자, 시작 코드, 그리고 무엇보다
/// **진입점 규칙**. rustc 는 크레이트 루트 하나만 받고, C++ 는 모든 `.cpp` 를 링크하며,
/// SQL 은 질의 하나다. 이 차이를 화면이 모르면 "왜 안 도는지" 를 학습자가 떠안는다.
public enum ScratchLanguage: String, Sendable, CaseIterable, Identifiable, Hashable {
    case python
    case swift
    case sql
    case rust
    case cpp

    public var id: String { rawValue }

    public var languageID: LanguageID {
        switch self {
        case .python: .python
        case .swift: .swift
        case .sql: .sql
        case .rust: .rust
        case .cpp: .cpp
        }
    }

    public var displayName: String {
        switch self {
        case .python: "Python"
        case .swift: "Swift"
        case .sql: "SQL"
        case .rust: "Rust"
        case .cpp: "C++"
        }
    }

    public var fileExtension: String {
        switch self {
        case .python: "py"
        case .swift: "swift"
        case .sql: "sql"
        case .rust: "rs"
        case .cpp: "cpp"
        }
    }

    /// 실행의 진입점이 되는 파일. 이 이름은 **바꿀 수 없다** — 지우거나 이름을 바꾸면
    /// 실행할 것이 없어진다.
    public var entryFileName: String {
        switch self {
        case .python: "main.py"
        case .swift: "main.swift"
        case .sql: "query.sql"
        case .rust: "main.rs"
        case .cpp: "main.cpp"
        }
    }

    /// 파일을 여럿 두는 것이 의미가 있는가.
    ///
    /// SQL 은 질의 하나를 돌리므로 파일이 여럿이어도 첫 파일만 실행된다 — 그러면 화면이
    /// 거짓말을 하므로 아예 하나로 묶는다. 나머지 넷은 실행기가 여러 파일을 받는다.
    public var allowsMultipleFiles: Bool { self != .sql }

    /// 진입점 파일의 첫 내용. 학습자가 빈 화면을 마주하지 않게 한다.
    public var starterContents: String {
        switch self {
        case .python:
            """
            # 자유롭게 고쳐 보세요. 채점하지 않습니다.
            names = ["러스트", "스위프트", "파이썬"]
            for index, name in enumerate(names, start=1):
                print(f"{index}. {name}")
            """
        case .swift:
            """
            // 자유롭게 고쳐 보세요. 채점하지 않습니다.
            let names = ["러스트", "스위프트", "파이썬"]
            for (index, name) in names.enumerated() {
                print("\\(index + 1). \\(name)")
            }
            """
        case .sql:
            """
            -- 자유롭게 고쳐 보세요. 채점하지 않습니다.
            -- SQL 트랙과 같은 쇼핑몰 데이터가 들어 있습니다.
            -- 표: category · customer · product · "order" · order_item
            SELECT name, city
            FROM customer
            ORDER BY name;
            """
        case .rust:
            """
            // 자유롭게 고쳐 보세요. 채점하지 않습니다.
            fn main() {
                let names = ["러스트", "스위프트", "파이썬"];
                for (index, name) in names.iter().enumerate() {
                    println!("{}. {}", index + 1, name);
                }
            }
            """
        case .cpp:
            """
            // 자유롭게 고쳐 보세요. 채점하지 않습니다.
            #include <iostream>
            #include <string>
            #include <vector>

            int main() {
                std::vector<std::string> names = {"러스트", "스위프트", "파이썬"};
                for (std::size_t i = 0; i < names.size(); ++i) {
                    std::cout << i + 1 << ". " << names[i] << std::endl;
                }
                return 0;
            }
            """
        }
    }

    /// 진입점이 아닌 새 파일의 첫 내용.
    ///
    /// 언어마다 "이 파일이 진입점에서 보이게 하려면 무엇이 필요한가" 가 다르다. 그 답을
    /// 주석으로 파일 안에 넣어 둔다 — 화면 어딘가의 도움말보다 여기가 눈에 띈다.
    public func newFileContents(named name: String) -> String {
        let stem = name.split(separator: ".").first.map(String.init) ?? name
        switch self {
        case .python:
            return """
                # `main.py` 에서 `from \(stem) import ...` 로 가져다 씁니다.

                def hello() -> str:
                    return "안녕하세요"
                """
        case .swift:
            return """
                // 같은 모듈이라 `main.swift` 에서 그냥 부르면 됩니다.

                func hello() -> String {
                    "안녕하세요"
                }
                """
        case .rust:
            return """
                // rustc 는 크레이트 루트 하나만 받습니다. `main.rs` 에
                // `mod \(stem);` 을 적어야 이 파일이 함께 컴파일됩니다.

                pub fn hello() -> String {
                    String::from("안녕하세요")
                }
                """
        case .cpp:
            return """
                // 같은 이름의 `.h` 를 만들어 선언을 두고 `main.cpp` 에서 include 하세요.
                // `.cpp` 는 자동으로 함께 컴파일됩니다.

                #include <string>

                std::string hello() {
                    return "안녕하세요";
                }
                """
        case .sql:
            return "-- SQL 연습장은 파일 하나만 씁니다.\n"
        }
    }
}
