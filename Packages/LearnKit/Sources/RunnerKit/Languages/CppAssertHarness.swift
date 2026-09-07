/// C++ 과제의 숨은 테스트를 담는 최소 하네스.
///
/// **테스트 프레임워크를 쓰지 않는다.** Catch2·GoogleTest 는 이 머신에도 학습자
/// 머신에도 없고, 받아 오려면 네트워크가 필요한데 채점은 샌드박스 안에서 돈다.
/// 표준 라이브러리만으로 통과·실패·에러 세 종류를 가른다.
///
/// **결과를 stdout 이 아니라 파일로 낸다.** 사용자 코드의 `std::cout` 이 같은 stdout 을
/// 쓰기 때문이다 — 한 줄만 섞여도 파서가 무너지고, 그 실패는 "학습자 코드가 이상하다"로
/// 잘못 읽힌다. 출력 경로는 워크스페이스 **바깥**이라 실행이 끝나고 워크스페이스가
/// 지워진 뒤에도 채점기가 읽을 수 있다. (`PythonUnittestHarness` 와 같은 계약이다.)
///
/// 레슨 저자가 쓰는 것은 `LEARNKIT_TEST(이름) { … }` 블록과 `LEARNKIT_EXPECT(식)` ·
/// `LEARNKIT_EXPECT_EQ(a, b)` 뿐이다. `main` 은 하네스가 준다 — 저자가 쓰면 링커가
/// 중복 정의로 거부한다.
enum CppAssertHarness {
    /// 워크스페이스에 함께 놓이는 하네스 헤더 이름.
    static let headerName = "__learnkit_harness.h"

    /// 하네스의 `main` 을 담는 번역 단위. 헤더와 갈라 둔 이유는 저자의 테스트 파일이
    /// 헤더만 include 하면 되게 하려는 것이다 — `main` 이 헤더에 있으면 여러 테스트
    /// 파일을 함께 컴파일할 때 중복 정의가 된다.
    static let mainName = "__learnkit_harness.cpp"

    static let header = #"""
    // learnkit C++ 채점 하네스. 표준 라이브러리만 쓴다.
    #ifndef LEARNKIT_HARNESS_H
    #define LEARNKIT_HARNESS_H

    #include <cstddef>
    #include <exception>
    #include <sstream>
    #include <string>
    #include <vector>

    namespace learnkit {

    struct Failure {
        std::string message;
        int line;
    };

    struct TestCase {
        const char* name;
        void (*body)(std::vector<Failure>&);
    };

    // 등록부는 함수 지역 static 이다. 전역 객체로 두면 번역 단위 사이의 초기화 순서가
    // 정해지지 않아, 테스트가 등록되기 전에 main 이 도는 경우가 생긴다.
    inline std::vector<TestCase>& registry() {
        static std::vector<TestCase> tests;
        return tests;
    }

    struct Registrar {
        Registrar(const char* name, void (*body)(std::vector<Failure>&)) {
            registry().push_back(TestCase{name, body});
        }
    };

    template <typename T>
    inline std::string describe(const T& value) {
        std::ostringstream out;
        out << value;
        return out.str();
    }

    // bool 을 1/0 이 아니라 true/false 로 보여준다 — 기대와 실제를 눈으로 맞출 때
    // 1/0 은 정수와 구분되지 않는다.
    inline std::string describe(bool value) { return value ? "true" : "false"; }

    }  // namespace learnkit

    #define LEARNKIT_CONCAT_INNER(a, b) a##b
    #define LEARNKIT_CONCAT(a, b) LEARNKIT_CONCAT_INNER(a, b)

    #define LEARNKIT_TEST(name)                                                     \
        static void LEARNKIT_CONCAT(learnkit_test_, __LINE__)(                      \
            std::vector<::learnkit::Failure>& learnkit_failures);                   \
        static ::learnkit::Registrar LEARNKIT_CONCAT(learnkit_reg_, __LINE__)(      \
            name, &LEARNKIT_CONCAT(learnkit_test_, __LINE__));                      \
        static void LEARNKIT_CONCAT(learnkit_test_, __LINE__)(                      \
            std::vector<::learnkit::Failure>& learnkit_failures)

    #define LEARNKIT_EXPECT(expr)                                                   \
        do {                                                                        \
            if (!(expr)) {                                                          \
                learnkit_failures.push_back(                                        \
                    ::learnkit::Failure{"기대가 거짓입니다: " #expr, __LINE__});    \
            }                                                                       \
        } while (false)

    #define LEARNKIT_EXPECT_EQ(actual, expected)                                    \
        do {                                                                        \
            const auto& learnkit_a = (actual);                                      \
            const auto& learnkit_b = (expected);                                     \
            if (!(learnkit_a == learnkit_b)) {                                      \
                learnkit_failures.push_back(::learnkit::Failure{                    \
                    std::string(#actual) + " 가 " +                                 \
                        ::learnkit::describe(learnkit_b) + " 이어야 하는데 " +      \
                        ::learnkit::describe(learnkit_a) + " 입니다",                \
                    __LINE__});                                                     \
            }                                                                       \
        } while (false)

    #endif  // LEARNKIT_HARNESS_H
    """#

    static let main = #"""
    // learnkit C++ 채점 하네스의 진입점. 결과를 argv[1] 경로에 JSON Lines 로 쓴다.
    #include "__learnkit_harness.h"

    #include <cstdio>
    #include <exception>
    #include <string>
    #include <vector>

    namespace {

    // JSON 문자열 이스케이프. 제어 문자까지 다뤄야 한다 — 실패 메시지에 개행이 흔하다.
    std::string escape(const std::string& text) {
        std::string out;
        out.reserve(text.size() + 16);
        for (unsigned char c : text) {
            switch (c) {
                case '"': out += "\\\""; break;
                case '\\': out += "\\\\"; break;
                case '\n': out += "\\n"; break;
                case '\r': out += "\\r"; break;
                case '\t': out += "\\t"; break;
                default:
                    if (c < 0x20) {
                        char buf[7];
                        std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                        out += buf;
                    } else {
                        out += static_cast<char>(c);
                    }
            }
        }
        return out;
    }

    }  // namespace

    int main(int argc, char** argv) {
        if (argc < 2) {
            std::fprintf(stderr, "learnkit: 결과 파일 경로가 필요합니다\n");
            return 2;
        }
        std::FILE* out = std::fopen(argv[1], "w");
        if (out == nullptr) {
            std::fprintf(stderr, "learnkit: 결과 파일을 열 수 없습니다: %s\n", argv[1]);
            return 2;
        }

        int failed = 0;
        for (const auto& test : ::learnkit::registry()) {
            std::vector<::learnkit::Failure> failures;
            std::string error;
            // 던져진 예외는 실패가 아니라 **에러**다. 구현이 없는 starter 가 흔히
            // 여기로 온다 — 그 둘을 뭉치면 "왜 실패했나" 를 학습자가 못 읽는다.
            try {
                test.body(failures);
            } catch (const std::exception& e) {
                error = std::string("예외가 던져졌습니다: ") + e.what();
            } catch (...) {
                error = "알 수 없는 예외가 던져졌습니다";
            }

            const char* status = "passed";
            std::string message;
            if (!error.empty()) {
                status = "error";
                message = error;
                failed += 1;
            } else if (!failures.empty()) {
                status = "failed";
                for (std::size_t i = 0; i < failures.size(); ++i) {
                    if (i > 0) message += "\n";
                    message += failures[i].message;
                }
                failed += 1;
            }

            std::fprintf(out, "{\"name\":\"%s\",\"status\":\"%s\",\"message\":\"%s\"}\n",
                         escape(test.name).c_str(), status, escape(message).c_str());
        }

        std::fclose(out);
        // 종료 코드는 신호일 뿐이다 — 정본은 결과 파일이다. 사용자 코드가 exit 를
        // 부르거나 크래시하면 이 값은 오지 않고, 그때는 파일이 짧은 것으로 드러난다.
        return failed == 0 ? 0 : 1;
    }
    """#
}
