@Concept(id: cpp-capstone-concept) {
지금까지 배운 것을 하나로 모아 볼 차례다. 텍스트에서 단어 빈도를 세는 일은 문자열 분해(substr·find), 집계(map), 정렬(sort, 람다)이라는 서로 다른 세 도구를 순서대로 이어 붙이는 작업이다. 새로운 문법은 없다 — 이미 아는 조각들을 어떤 순서로 연결하느냐가 이번 레슨의 전부다.

단어를 나눌 때는 공백이 아닌 첫 글자를 find_first_not_of 로 찾고, 그다음 공백을 find_first_of 로 찾아 그 사이를 substr 로 잘라낸다. 이 방식은 연속된 공백을 자연스럽게 하나로 취급한다 — 공백이 아닌 자리를 찾는 것부터 다시 시작하기 때문에 빈 단어가 끼어들 여지가 없다.

빈도를 셀 때 std::map 의 operator[] 는 없던 키를 자동으로 0으로 만들어 준다는 점을 기억하면 `freq[word] += 1;` 한 줄로 충분하다. 그리고 map 은 키를 항상 정렬된 순서로 들고 있으므로, 나중에 정렬 결과가 같은 입력에 대해 항상 같은 순서로 나온다는 것도 보장된다.

정렬은 빈도만으로는 순서가 정해지지 않는 경우가 있다는 점이 관건이다. 두 단어의 빈도가 같으면 비교자가 아무 기준도 주지 못해 결과가 실행할 때마다 달라질 수 있다. 그래서 비교자에서 빈도가 다르면 그것으로, 같으면 단어 오름차순이라는 두 번째 기준으로 비교해야 결과가 항상 재현된다. 빈 입력이 들어오면 각 단계(분해·집계·정렬)가 그냥 빈 결과를 그대로 다음 단계로 넘기면 되므로, 특별한 예외 처리 없이도 안전하게 흘러간다.
}

@Example(id: cpp-capstone-example, language: cpp, expected: expected/cpp-capstone-text-stats.txt) {
문장 하나를 단어로 나누고, 빈도를 세고, 빈도 내림차순·단어 오름차순으로 정렬해 출력하는 전체 흐름을 본다.

```cpp
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>

int main() {
    std::string text = "the quick brown fox the lazy dog the fox";

    std::vector<std::string> words;
    std::size_t start = text.find_first_not_of(' ');
    while (start != std::string::npos) {
        std::size_t end = text.find_first_of(' ', start);
        if (end == std::string::npos) {
            words.push_back(text.substr(start));
            break;
        }
        words.push_back(text.substr(start, end - start));
        start = text.find_first_not_of(' ', end);
    }

    std::map<std::string, int> freq;
    for (const std::string& word : words) {
        freq[word] += 1;
    }

    std::vector<std::pair<std::string, int>> ranked(freq.begin(), freq.end());
    std::sort(ranked.begin(), ranked.end(),
              [](const std::pair<std::string, int>& a, const std::pair<std::string, int>& b) {
                  if (a.second != b.second) {
                      return a.second > b.second;
                  }
                  return a.first < b.first;
              });

    for (const auto& entry : ranked) {
        std::cout << entry.first << ": " << entry.second << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-capstone-blank, language: cpp) {
map 을 벡터로 옮기는 반복자 쌍과, 빈도 내림차순 비교 연산자를 채워 완성하자.

```cpp
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <utility>
#include <algorithm>

int main() {
    std::map<std::string, int> counts;
    counts["apple"] += 1;
    counts["banana"] += 1;
    counts["apple"] += 1;

    std::vector<std::pair<std::string, int>> ranked(counts.___1___(), counts.___2___());
    std::sort(ranked.begin(), ranked.end(),
              [](const std::pair<std::string, int>& a, const std::pair<std::string, int>& b) {
                  return a.second ___3___ b.second;
              });

    std::cout << ranked[0].first << " " << ranked[0].second << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`begin`
}

@Answer(slot: 2) {
`end`
}

@Answer(slot: 3) {
`>`
}
}

@Task(id: cpp-capstone-task, language: cpp, starter: starters/cpp-capstone-text-stats.cpp, tests: tests/cpp-capstone-text-stats.cpp, solution: solutions/cpp-capstone-text-stats.cpp) {
텍스트 통계를 계산하는 함수 세 개를 완성하라. `splitWords(text)` 는 공백(스페이스·탭·개행)을 기준으로 `text` 를 단어로 나눠 돌려준다. 연속된 공백은 하나로 취급하고, 빈 단어는 결과에 넣지 않는다. `wordFrequency(words)` 는 각 단어가 몇 번 나왔는지 `std::map` 으로 세어 돌려준다. `sortedByFrequency(freq)` 는 `freq` 의 항목들을 빈도 내림차순으로, 빈도가 같으면 단어 오름차순으로 정렬한 벡터로 돌려준다. 세 함수 모두 빈 입력이 들어오면 빈 결과를 돌려줘야 한다.

@Hint {
find_first_not_of 와 find_first_of 로 공백이 아닌 구간을 찾아 substr 로 잘라낸다.
}

@Hint {
map 의 operator[] 는 없던 키를 0으로 만들어 주므로 freq[word] += 1; 로 바로 셀 수 있다.
}

@Hint {
sort 의 비교자에서 빈도가 다르면 그것으로, 같으면 단어로 비교한다.
}
}

@Quiz(id: cpp-capstone-quiz, answer: stable-order) {
@Question {
정렬 비교자에서 빈도가 같을 때 단어를 오름차순으로 비교하는 이유는?
}

@Choice(id: stable-order) {
빈도만으로는 순서가 정해지지 않는 경우가 생기는데, 규칙을 하나 더 정해 두면 결과가 항상 똑같이 재현된다
}

@Choice(id: faster) {
그렇게 해야 std::sort 가 더 빠르게 동작하기 때문이다
}

@Choice(id: map-order) {
std::map 은 원래 정렬을 지원하지 않아서 sort 가 대신 처음부터 정렬하는 것이다
}

@Choice(id: required-syntax) {
비교자는 반드시 두 개 이상의 조건을 비교해야 컴파일되기 때문이다
}

@Explanation {
빈도만 비교하면 빈도가 같은 단어들 사이의 순서가 정의되지 않아, 실행할 때마다(또는 컴파일러·표준 라이브러리 구현에 따라) 결과가 달라질 수 있다. 단어 오름차순이라는 두 번째 기준을 추가하면 항상 같은 결과가 나온다. 속도와는 무관하고, std::map 은 이미 키 순서로 정렬되어 있으며, 비교자가 조건 두 개를 반드시 요구하는 문법 규칙은 없다.
}
}

@Reflection(id: cpp-capstone-reflection) {
@Prompt(id: empty-handling-design) {
splitWords 가 빈 문자열을 받았을 때 빈 벡터를 돌려주도록 만들었습니다. 만약 예외를 던지도록 설계했다면 wordFrequency 와 sortedByFrequency 를 어떻게 고쳐야 했을지 생각해 보세요.
}

@Prompt(id: track-retrospective) {
이 트랙에서 배운 vector·string·map·람다·정렬을 하나의 프로그램에 모아 보니, 어떤 부분이 가장 자연스럽게 이어졌는지 돌아보세요.
}
}
