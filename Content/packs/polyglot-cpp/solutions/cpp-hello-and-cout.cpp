#include <string>

std::string greeting(const std::string& name) {
    if (name.empty()) {
        return "안녕하세요, 이름 없음!";
    }
    return "안녕하세요, " + name + "!";
}
