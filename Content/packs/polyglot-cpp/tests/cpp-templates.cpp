#include "__learnkit_harness.h"
#include "solution.h"
#include <string>

LEARNKIT_TEST("int 벡터에서 최댓값을 찾는다") {
    std::vector<int> data = {3, 9, 1, 7};
    LEARNKIT_EXPECT_EQ(maxIn(data), 9);
}

LEARNKIT_TEST("double 벡터에서도 동작한다") {
    std::vector<double> data = {1.5, 3.5, 2.0};
    LEARNKIT_EXPECT_EQ(maxIn(data), 3.5);
}

LEARNKIT_TEST("원소가 하나면 그 값이 최댓값이다") {
    std::vector<int> data = {42};
    LEARNKIT_EXPECT_EQ(maxIn(data), 42);
}

LEARNKIT_TEST("빈 벡터는 예외를 던진다") {
    std::vector<int> data;
    bool threw = false;
    try {
        maxIn(data);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    LEARNKIT_EXPECT(threw);
}

LEARNKIT_TEST("Pair<int> 가 두 값을 각각 돌려준다") {
    Pair<int> p(3, 7);
    LEARNKIT_EXPECT_EQ(p.getFirst(), 3);
    LEARNKIT_EXPECT_EQ(p.getSecond(), 7);
}

LEARNKIT_TEST("Pair<std::string> 도 동작한다") {
    Pair<std::string> p(std::string("a"), std::string("b"));
    LEARNKIT_EXPECT_EQ(p.getFirst(), std::string("a"));
    LEARNKIT_EXPECT_EQ(p.getSecond(), std::string("b"));
}
