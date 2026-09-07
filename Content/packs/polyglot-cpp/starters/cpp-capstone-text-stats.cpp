#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <stdexcept>

std::vector<std::string> splitWords(const std::string& text) {
    // 공백(스페이스·탭·개행)을 기준으로 text 를 단어로 나눠 돌려준다.
    // 연속된 공백은 하나로 취급하고, 빈 단어는 결과에 넣지 않는다.
    throw std::runtime_error("여기를 구현해라");
}

std::map<std::string, int> wordFrequency(const std::vector<std::string>& words) {
    // 각 단어가 몇 번 나왔는지 세어 map 으로 돌려준다.
    throw std::runtime_error("여기를 구현해라");
}

std::vector<std::pair<std::string, int>> sortedByFrequency(const std::map<std::string, int>& freq) {
    // 빈도 내림차순으로, 빈도가 같으면 단어 오름차순으로 정렬해 돌려준다.
    throw std::runtime_error("여기를 구현해라");
}
