@Concept(id: cpp-fileio-concept) {
`std::ofstream` 과 `std::ifstream` 은 `std::cin`·`std::cout` 과 똑같은 방식으로 쓰지만, 대상이 화면이 아니라 파일이다. `std::ofstream out("이름");` 은 그 이름의 파일을 쓰기용으로 연다 — 파일이 없으면 새로 만들고, 있으면 기존 내용을 지우고 새로 쓴다. `<<` 로 값을 밀어 넣는 방법은 `cout` 과 동일하다.

읽을 때는 `std::ifstream in("이름");` 으로 연다. 문제는 파일이 없거나 권한이 없어도 이 생성자가 예외를 던지지 않는다는 점이다 — 그냥 조용히 "열리지 않은" 상태의 객체가 만들어진다. 그 상태로 읽기를 시도하면 아무 값도 얻지 못한 채 실패만 반복되므로, 열자마자 `is_open()` 으로 성공 여부를 확인하는 습관이 필요하다.

`std::getline(in, line)` 은 파일에서 한 줄을 통째로 읽어 `line` 에 담고, 그 줄 끝의 개행 문자는 제외한다. 더 읽을 줄이 없으면 스트림이 실패 상태가 되어 `while (std::getline(in, line))` 조건이 거짓이 되므로, 줄 수를 몰라도 끝까지 읽는 반복문을 자연스럽게 쓸 수 있다.

파일 경로는 프로그램이 실행되는 위치를 기준으로 한 상대 경로를 쓰는 것이 안전하다. 절대 경로는 실행 환경마다 달라서 다른 컴퓨터나 샌드박스에서는 그 경로 자체가 존재하지 않을 수 있다.
}

@Example(id: cpp-fileio-example, language: cpp, expected: expected/cpp-file-io.txt) {
파일에 두 줄을 쓴 뒤 다시 열어 줄 번호를 붙여 읽고, 없는 파일을 여는 경우도 확인한다.

```cpp
#include <fstream>
#include <iostream>
#include <string>

int main() {
    std::ofstream out("greeting.txt");
    out << "안녕하세요" << std::endl;
    out << "두 번째 줄" << std::endl;
    out.close();

    std::ifstream in("greeting.txt");
    if (!in.is_open()) {
        std::cout << "파일을 열 수 없습니다" << std::endl;
        return 1;
    }

    std::string line;
    int lineNumber = 1;
    while (std::getline(in, line)) {
        std::cout << lineNumber << ": " << line << std::endl;
        ++lineNumber;
    }
    in.close();

    std::ifstream missing("no-such-file.txt");
    if (!missing.is_open()) {
        std::cout << "없는 파일은 열리지 않습니다" << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-fileio-blank, language: cpp) {
쓰기용 스트림 타입, 읽기용 스트림 타입, 열림 확인 함수, 줄 단위 읽기 함수를 채워 완성하자.

```cpp
#include <fstream>
#include <iostream>
#include <string>

int main() {
    std::___1___ out("notes.txt");
    out << "메모" << std::endl;
    out.close();

    std::___2___ in("notes.txt");
    if (!in.___3___()) {
        return 1;
    }

    std::string line;
    std::___4___(in, line);
    std::cout << line << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`ofstream`
}

@Answer(slot: 2) {
`ifstream`
}

@Answer(slot: 3) {
`is_open`
}

@Answer(slot: 4) {
`getline`
}
}

@Task(id: cpp-fileio-task, language: cpp, starter: starters/cpp-file-io.cpp, tests: tests/cpp-file-io.cpp, solution: solutions/cpp-file-io.cpp) {
파일을 다루는 함수 두 개를 완성하라. `writeLines(path, lines)` 는 `lines` 의 각 문자열을 한 줄씩 `path` 에 쓴다(각 줄 뒤에 개행). `readLines(path)` 는 `path` 를 열어 줄 단위로 읽어 벡터로 돌려주고, 파일을 열 수 없으면 빈 벡터를 돌려준다. `path` 는 항상 현재 작업 디렉터리 기준의 상대 경로로 넘어온다.

@Hint {
ofstream 은 파일이 없으면 새로 만들고 있으면 덮어쓴다.
}

@Hint {
getline 을 while 조건에 넣으면 더 읽을 줄이 없을 때 자동으로 false 가 된다.
}

@Hint {
is_open() 이 거짓이면 빈 벡터를 그대로 돌려주면 된다.
}
}

@Quiz(id: cpp-fileio-quiz, answer: silent-fail) {
@Question {
ifstream 을 연 뒤 반드시 is_open() 을 검사해야 하는 이유는?
}

@Choice(id: silent-fail) {
파일이 없거나 권한이 없어도 스트림 생성 자체는 예외 없이 조용히 실패하기 때문이다
}

@Choice(id: always-terminate) {
열기에 실패하면 프로그램이 즉시 종료되기 때문이다
}

@Choice(id: compile-check) {
컴파일러가 파일 존재 여부를 미리 검사해 주기 때문에 실행 후에는 검사할 필요가 없다
}

@Choice(id: getline-needs) {
is_open 을 부르지 않으면 getline 자체가 컴파일되지 않기 때문이다
}

@Explanation {
std::ifstream 생성자는 파일이 없거나 열 수 없어도 예외를 던지지 않고 조용히 "열리지 않은" 상태의 객체를 만든다. 그 상태로 getline 을 부르면 그냥 아무것도 읽지 못하고 반복문이 즉시 끝나 버려 실패를 알아채기 어렵다. 그래서 열기 직후 is_open() 으로 명시적으로 확인해야 한다. 프로그램이 즉시 종료되지도, 컴파일러가 파일 존재를 미리 검사해 주지도 않으며, is_open 호출 여부와 getline 컴파일은 무관하다.
}
}

@Reflection(id: cpp-fileio-reflection) {
@Prompt(id: exception-vs-empty) {
파일이 없을 때 readLines 가 예외를 던지는 대신 빈 벡터를 돌려주도록 설계했습니다. 예외를 던지는 설계와 비교해 어떤 차이가 있을지 적어 보세요.
}

@Prompt(id: append-mode) {
ofstream 으로 파일을 열면 기존 내용이 사라집니다. 기존 내용에 이어 쓰고 싶다면 어떤 방법이 있을지 생각해 보세요.
}
}
