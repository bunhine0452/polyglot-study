#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("기준보다 작은 값만 남기고 정렬한다") {
    std::vector<int> data = {8, 2, 9, 1, 5, 3};
    auto result = filterAndSort(data, 6);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(4));
    LEARNKIT_EXPECT_EQ(result[0], 1);
    LEARNKIT_EXPECT_EQ(result[1], 2);
    LEARNKIT_EXPECT_EQ(result[2], 3);
    LEARNKIT_EXPECT_EQ(result[3], 5);
}

LEARNKIT_TEST("모두 기준 이상이면 빈 벡터") {
    std::vector<int> data = {10, 20, 30};
    auto result = filterAndSort(data, 5);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(0));
}

LEARNKIT_TEST("모두 기준보다 작으면 전부 남는다") {
    std::vector<int> data = {3, 1, 2};
    auto result = filterAndSort(data, 100);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(result[0], 1);
    LEARNKIT_EXPECT_EQ(result[1], 2);
    LEARNKIT_EXPECT_EQ(result[2], 3);
}

LEARNKIT_TEST("빈 입력은 빈 결과") {
    std::vector<int> data;
    auto result = filterAndSort(data, 10);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(0));
}
