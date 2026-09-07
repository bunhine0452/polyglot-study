#include "__learnkit_harness.h"
#include "solution.h"

#include <vector>

LEARNKIT_TEST("제곱의 합을 구한다") {
    std::vector<int> values = {1, 2, 3};
    LEARNKIT_EXPECT_EQ(sumOfSquares(values), 14);
}

LEARNKIT_TEST("빈 벡터의 제곱합은 0이다") {
    std::vector<int> values;
    LEARNKIT_EXPECT_EQ(sumOfSquares(values), 0);
}

LEARNKIT_TEST("각 원소에 amount 를 더한다") {
    std::vector<int> values = {1, 2, 3};
    std::vector<int> result = incrementAll(values, 10);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(result[0], 11);
    LEARNKIT_EXPECT_EQ(result[1], 12);
    LEARNKIT_EXPECT_EQ(result[2], 13);
}

LEARNKIT_TEST("음수를 더해 줄일 수도 있고 빈 벡터는 빈 채로 돌아온다") {
    std::vector<int> values = {5, 5};
    std::vector<int> result = incrementAll(values, -3);
    LEARNKIT_EXPECT_EQ(result[0], 2);
    LEARNKIT_EXPECT_EQ(result[1], 2);

    std::vector<int> empty;
    std::vector<int> emptyResult = incrementAll(empty, 100);
    LEARNKIT_EXPECT_EQ(emptyResult.size(), static_cast<std::size_t>(0));
}
