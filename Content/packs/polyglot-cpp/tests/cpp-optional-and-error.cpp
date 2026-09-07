#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("이름이 있으면 나이를 찾는다") {
    std::vector<std::pair<std::string, int>> people = {{"민수", 20}, {"영희", 25}};
    auto age = findAge(people, "영희");
    LEARNKIT_EXPECT(age.has_value());
    LEARNKIT_EXPECT_EQ(age.value(), 25);
}

LEARNKIT_TEST("이름이 없으면 nullopt") {
    std::vector<std::pair<std::string, int>> people = {{"민수", 20}};
    auto age = findAge(people, "철수");
    LEARNKIT_EXPECT(!age.has_value());
}

LEARNKIT_TEST("빈 목록이면 nullopt") {
    std::vector<std::pair<std::string, int>> people;
    auto age = findAge(people, "아무나");
    LEARNKIT_EXPECT(!age.has_value());
}

LEARNKIT_TEST("나이 차이를 순서 상관없이 구한다") {
    LEARNKIT_EXPECT_EQ(ageDifference(20, 25), 5);
    LEARNKIT_EXPECT_EQ(ageDifference(25, 20), 5);
}

LEARNKIT_TEST("같은 나이면 차이는 0") {
    LEARNKIT_EXPECT_EQ(ageDifference(30, 30), 0);
}

LEARNKIT_TEST("음수가 있으면 예외를 던진다") {
    bool threw = false;
    try {
        ageDifference(-1, 5);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    LEARNKIT_EXPECT(threw);
}
