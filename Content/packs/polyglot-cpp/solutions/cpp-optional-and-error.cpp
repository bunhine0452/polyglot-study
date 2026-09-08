#include <optional>
#include <string>
#include <utility>
#include <vector>
#include <stdexcept>

std::optional<int> findAge(const std::vector<std::pair<std::string, int>>& people, const std::string& name) {
    for (const auto& person : people) {
        if (person.first == name) {
            return person.second;
        }
    }
    return std::nullopt;
}

int ageDifference(int a, int b) {
    if (a < 0 || b < 0) {
        throw std::invalid_argument("나이는 음수일 수 없다");
    }
    return (a > b) ? (a - b) : (b - a);
}
