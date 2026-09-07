#include <optional>
#include <string>
#include <utility>
#include <vector>
#include <stdexcept>

std::optional<int> findAge(const std::vector<std::pair<std::string, int>>& people, const std::string& name) {
    // people 을 순회하며 이름이 같은 첫 항목의 나이를 돌려준다. 없으면 std::nullopt.
    throw std::runtime_error("여기를 구현해라");
}

int ageDifference(int a, int b) {
    // a 나 b 가 음수면 std::invalid_argument 를 던진다.
    // 아니면 큰 값에서 작은 값을 뺀 값을 돌려준다.
    throw std::runtime_error("여기를 구현해라");
}
