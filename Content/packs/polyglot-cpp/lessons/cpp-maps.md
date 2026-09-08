@Concept(id: cpp-maps-concept) {
`std::vector` 는 정수 인덱스로 원소를 찾는다. 하지만 "사과의 가격"처럼 이름표로 값을 찾고 싶을 때는 인덱스가 아니라 키가 필요하다. `std::map<K, V>` 는 키(K) 하나에 값(V) 하나를 짝짓는 자료구조다 — `std::map<std::string, int> prices;` 라고 선언하면 문자열 키로 정수 값을 찾는 지도가 된다.

값을 넣거나 바꿀 때는 `prices["사과"] = 1000;` 처럼 `operator[]` 를 쓴다. 이 연산자의 특이한 점은, 없는 키에 접근하면 자동으로 그 키를 만들고 값 타입의 기본값(정수라면 0)으로 채운 뒤 그 자리를 돌려준다는 것이다. 그래서 `prices["바나나"]` 를 읽기만 했는데도 `"바나나"` 라는 키가 새로 생겨 버릴 수 있다 — 키가 있는지 모르고 그냥 읽으려면 이 부작용을 조심해야 한다.

키의 존재만 확인하고 싶을 때는 `count(key)` 를 쓴다. `map` 은 키가 중복되지 않으므로 `count` 는 0 아니면 1이다. 값까지 안전하게 얻고 싶다면 `find(key)` 가 돌려주는 반복자를 검사한다 — `auto it = prices.find("사과"); if (it != prices.end()) { ... it->second ... }` 형태로 쓰는데, `it->first` 가 키, `it->second` 가 값이다. `find` 는 `operator[]` 와 달리 없는 키를 만들어 내지 않는다.

`std::map` 을 범위 기반 for 로 순회하면 항상 키가 오름차순으로 정렬된 순서로 나온다. 이는 우연이 아니라 `map` 의 내부 구조(정렬된 트리)가 보장하는 성질이라 실행할 때마다 순서가 같다. 뒤에서 다룰 `std::unordered_map` 은 더 빠르지만 이 순서 보장이 없다 — 순서가 중요한 출력이라면 `map` 을 쓰는 이유가 여기 있다.
}

@Example(id: cpp-maps-example, language: cpp, expected: expected/cpp-maps.txt) {
과일 가격표를 map 에 담고, count 로 존재를 확인한 뒤 정렬된 순서로 전체를 출력한다.

```cpp
#include <iostream>
#include <map>
#include <string>

int main() {
    std::map<std::string, int> prices;
    prices["바나나"] = 500;
    prices["사과"] = 1000;
    prices["체리"] = 3000;

    if (prices.count("사과") > 0) {
        std::cout << "사과 가격: " << prices["사과"] << std::endl;
    }

    auto it = prices.find("포도");
    if (it == prices.end()) {
        std::cout << "포도는 목록에 없습니다" << std::endl;
    }

    std::cout << "전체 목록(키 순서):" << std::endl;
    for (const auto& pair : prices) {
        std::cout << pair.first << ": " << pair.second << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-maps-blank, language: cpp) {
키가 있는지 값을 만들지 않고 확인하는 count 호출을 채워 완성하자.

```cpp
#include <iostream>
#include <map>
#include <string>

int main() {
    std::map<std::string, int> ages;
    ages["민수"] = 20;

    if (ages.___1___("영희") ___2___ 0) {
        std::cout << "없음" << std::endl;
    }
    return 0;
}
```

@Answer(slot: 1) {
`count`
}

@Answer(slot: 2) {
`==`
}
}

@Task(id: cpp-maps-task, language: cpp, starter: starters/cpp-maps.cpp, tests: tests/cpp-maps.cpp, solution: solutions/cpp-maps.cpp) {
단어 목록을 받아 각 단어가 몇 번 등장하는지 세는 함수 `countWords` 를 완성하라. 시그니처는 `std::map<std::string, int> countWords(const std::vector<std::string>& words)` 다. 입력 벡터를 순회하며 각 단어의 등장 횟수를 map 에 누적해 돌려준다. 입력이 비어 있으면 빈 map 을 돌려준다(예외를 던지지 않는다).

@Hint {
map 의 operator[] 는 없는 키에 접근하면 0으로 자동 초기화된 자리를 만들어 준다.
}

@Hint {
counts[word]++; 한 줄로 '없으면 만들고, 있으면 1 늘린다'를 동시에 할 수 있다.
}

@Hint {
빈 벡터라면 반복문이 아예 안 돌아서 자연히 빈 map 이 남는다.
}
}

@Quiz(id: cpp-maps-quiz, answer: auto-insert) {
@Question {
std::map<std::string, int> m; 에서 m["없는키"] 를 그냥 읽기만 했을 때 일어나는 일은?
}

@Choice(id: auto-insert) {
"없는키" 가 값 0과 함께 map 에 새로 삽입된다
}

@Choice(id: throws) {
std::out_of_range 예외가 던져진다
}

@Choice(id: returns-optional) {
std::optional<int> 가 반환되어 값이 없음을 나타낸다
}

@Choice(id: no-op) {
아무 일도 일어나지 않고 0이 반환되지만 map 은 그대로다
}

@Explanation {
operator[] 는 키가 없으면 그 키를 값 타입의 기본값과 함께 자동으로 삽입한 뒤 그 자리의 참조를 돌려준다 — 읽기만 하려던 코드가 map 의 크기를 몰래 바꿀 수 있다는 뜻이다. 예외를 던지는 쪽은 at() 이고, std::optional 을 돌려주는 표준 멤버 함수는 없으며, map 이 그대로 남는다는 것도 틀렸다 — 새 키가 실제로 추가된다.
}
}

@Reflection(id: cpp-maps-reflection) {
@Prompt(id: operator-bracket-risk) {
operator[] 가 없는 키를 자동으로 만들어 버리는 성질이 어떤 버그로 이어질 수 있을지, 실제로 겪을 법한 상황을 상상해 적어 보세요.
}

@Prompt(id: sorted-vs-unsorted) {
map 이 항상 키 순서로 순회된다는 성질이 유용한 상황과, 오히려 필요 없어서 더 빠른 자료구조(예: unordered_map)를 쓰고 싶어질 상황을 각각 하나씩 떠올려 보세요.
}
}
