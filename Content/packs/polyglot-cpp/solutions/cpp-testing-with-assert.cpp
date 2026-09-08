#include <string>

std::string compareResult(int actual, int expected) {
    if (actual == expected) {
        return "일치";
    }
    return "기대값 " + std::to_string(expected) + ", 실제값 " + std::to_string(actual);
}
