@Concept(id: cpp-strings-concept) {
`std::string` 은 문자들을 담는, 크기가 스스로 늘어나는 컨테이너다. `+` 로 두 문자열을 이어 새 문자열을 만들 수 있고, `+=` 로 뒤에 덧붙일 수도 있다 — 앞에서 본 vector 처럼 메모리를 알아서 관리하기 때문에, C 스타일 문자 배열과 달리 크기를 미리 정해 둘 필요가 없다.

`length()` 는 문자열이 담고 있는 문자 개수를 돌려준다. `substr(pos, len)` 은 인덱스 pos 에서 시작해 len 개의 문자를 잘라 새 문자열로 돌려주는데(len 을 생략하면 끝까지 잘린다), 원래 문자열은 전혀 바뀌지 않고 그대로 남는다. pos 가 문자열 길이를 넘어서면 오류가 나므로, 잘라내기 전에 위치가 유효한지 확인하는 습관이 필요하다.

`find(target)` 은 target 이 처음 나타나는 위치를 인덱스로 돌려준다. 못 찾으면 어떻게 될까? 유효한 인덱스는 0부터 `length() - 1` 까지뿐이라 그 범위 안의 어떤 수도 "없음" 을 뜻하기에는 이미 다른 의미로 쓰이고 있다. 그래서 C++ 은 `std::string::npos` 라는, 어떤 실제 위치도 될 수 없는 특별한 값을 따로 정해 두고 못 찾았을 때 그 값을 돌려준다.

문자열도 vector 처럼 문자 하나하나를 범위 기반 for(`for (char c : s)`)로 순회할 수 있다. 각 문자는 작은따옴표로 쓰는 `char` 값으로 꺼내지고, `==` 로 특정 글자와 비교하거나 세는 데 그대로 쓸 수 있다.
}

@Example(id: cpp-strings-example, language: cpp, expected: expected/cpp-strings.txt) {
두 문자열을 이어 붙이고, length·substr·find 로 부분을 살펴본 뒤 문자를 하나씩 세어 본다.

```cpp
#include <iostream>
#include <string>

int main() {
    std::string first = "Hello, ";
    std::string second = "World!";
    std::string greeting = first + second;

    std::cout << greeting << std::endl;
    std::cout << "길이: " << greeting.length() << std::endl;
    std::cout << "부분: " << greeting.substr(7, 5) << std::endl;

    std::size_t pos = greeting.find("World");
    std::cout << "World 위치: " << pos << std::endl;

    int letterCount = 0;
    for (char c : greeting) {
        if (c != ' ' && c != ',' && c != '!') {
            ++letterCount;
        }
    }
    std::cout << "문자 수: " << letterCount << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-strings-blank, language: cpp) {
a 와 b 를 이어 붙이는 연산자와, 길이를 구하는 메서드 이름을 채워 완성하자.

```cpp
#include <iostream>
#include <string>

int main() {
    std::string a = "Poly";
    std::string b = "glot";
    std::string combined = a ___1___ b;

    std::cout << combined << std::endl;
    std::cout << "length=" << combined.___2___() << std::endl;

    return 0;
}
```

@Answer(slot: 1) {
`+`
}

@Answer(slot: 2) {
`length`
}
}

@Task(id: cpp-strings-task, language: cpp, starter: starters/cpp-strings.cpp, tests: tests/cpp-strings.cpp, solution: solutions/cpp-strings.cpp) {
이메일 주소 문자열에서 '@' 뒤의 도메인 부분만 잘라 반환하는 함수 `extractDomain` 을 완성하라. `extractDomain("user@example.com")` 은 `"example.com"` 을 반환해야 한다. '@' 가 아예 없으면 빈 문자열 `""` 을 반환하고, '@' 가 맨 앞에 있으면 그 뒤 전체를 반환한다.

@Hint {
email.find('@') 로 '@' 의 위치를 찾아라 — 문자 하나를 찾을 땐 작은따옴표를 쓴다.
}

@Hint {
찾지 못했을 때는 std::string::npos 와 비교해서 확인하라.
}

@Hint {
substr(pos + 1) 은 그 위치 바로 다음부터 끝까지를 잘라 준다 — 길이를 안 주면 끝까지 잘린다.
}
}

@Quiz(id: cpp-strings-quiz, answer: npos) {
@Question {
std::string s = "cat"; 일 때 s.find("dog") 처럼 찾는 대상이 없을 때, 반환값은 무엇과 비교해서 확인해야 할까요?
}

@Choice(id: npos) {
std::string::npos — 찾지 못했을 때 돌려주기로 정해진 특별한 값이다
}

@Choice(id: zero) {
0 — 찾지 못하면 항상 0이 반환된다
}

@Choice(id: length) {
s.length() — 문자열 길이가 그대로 반환된다
}

@Choice(id: throws) {
비교할 필요가 없다 — 못 찾으면 예외가 던져진다
}

@Explanation {
find 는 못 찾아도 예외를 던지지 않고, 대신 std::string::npos 라는 정해진 특별한 값을 돌려준다. 유효한 인덱스는 0부터 length()-1 까지뿐이라 그 범위 안의 수는 전부 이미 '몇 번째에서 찾았다' 는 뜻으로 쓰이고 있어서, '못 찾음' 을 나타내려면 그 범위 밖의 별도 값이 필요하다. 0은 오히려 맨 앞에서 찾았다는 뜻이다.
}
}

@Reflection(id: cpp-strings-reflection) {
@Prompt(id: npos-vs-bool) {
std::string::npos 처럼 '못 찾음'을 특별한 값 하나로 표현하는 방식과, 위치와 별도로 찾았는지 여부를 참/거짓으로 같이 반환하는 방식을 비교하면 각각 어떤 장단점이 있을까요?
}

@Prompt(id: substr-non-mutating) {
substr 로 일부를 잘라내도 원래 문자열은 전혀 바뀌지 않습니다. 이 성질이 왜 안전한 설계라고 생각하는지 적어 보세요.
}
}
