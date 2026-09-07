#include "__learnkit_harness.h"
#include "solution.h"
#include <vector>

LEARNKIT_TEST("평범한 경우") {
    std::vector<int> data = {5, 2, 8, 2, 9, 1};
    int greater = 0, idx = 0;
    analyze(data, 5, greater, idx);
    LEARNKIT_EXPECT_EQ(greater, 2);
    LEARNKIT_EXPECT_EQ(idx, 3);
}

LEARNKIT_TEST("target 이 없으면 -1") {
    std::vector<int> data = {1, 2, 3};
    int greater = 0, idx = 0;
    analyze(data, 10, greater, idx);
    LEARNKIT_EXPECT_EQ(greater, 0);
    LEARNKIT_EXPECT_EQ(idx, -1);
}

LEARNKIT_TEST("target 이 가장 작은 값이면 인덱스 0") {
    std::vector<int> data = {5, 3, 8};
    int greater = 0, idx = 0;
    analyze(data, 3, greater, idx);
    LEARNKIT_EXPECT_EQ(greater, 2);
    LEARNKIT_EXPECT_EQ(idx, 0);
}

LEARNKIT_TEST("원본 벡터는 값으로 받아 바뀌지 않는다") {
    std::vector<int> data = {3, 1, 2};
    int greater = 0, idx = 0;
    analyze(data, 2, greater, idx);
    LEARNKIT_EXPECT_EQ(data.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(data[0], 3);
}
