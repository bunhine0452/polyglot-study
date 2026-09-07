#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("평범한 벡터에서 최소·최대를 찾는다") {
    std::vector<int> data = {3, -1, 4, 1, 5, 9, -2};
    int mn = 0, mx = 0;
    findMinMax(data, mn, mx);
    LEARNKIT_EXPECT_EQ(mn, -2);
    LEARNKIT_EXPECT_EQ(mx, 9);
}

LEARNKIT_TEST("원소가 하나면 최소와 최대가 같다") {
    std::vector<int> data = {7};
    int mn = 0, mx = 0;
    findMinMax(data, mn, mx);
    LEARNKIT_EXPECT_EQ(mn, 7);
    LEARNKIT_EXPECT_EQ(mx, 7);
}

LEARNKIT_TEST("모두 음수여도 정확히 찾는다") {
    std::vector<int> data = {-5, -1, -9, -3};
    int mn = 0, mx = 0;
    findMinMax(data, mn, mx);
    LEARNKIT_EXPECT_EQ(mn, -9);
    LEARNKIT_EXPECT_EQ(mx, -1);
}

LEARNKIT_TEST("빈 벡터는 예외를 던진다") {
    std::vector<int> data;
    int mn = 0, mx = 0;
    bool threw = false;
    try {
        findMinMax(data, mn, mx);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    LEARNKIT_EXPECT(threw);
}
