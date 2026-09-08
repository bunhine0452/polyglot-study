#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("짝수만 더한다") {
    LEARNKIT_EXPECT_EQ(sumEvens({1, 2, 3, 4, 5, 6}), 12);
}

LEARNKIT_TEST("빈 벡터는 0이다") {
    LEARNKIT_EXPECT_EQ(sumEvens({}), 0);
}

LEARNKIT_TEST("짝수가 없으면 0이다") {
    LEARNKIT_EXPECT_EQ(sumEvens({1, 3, 5}), 0);
}

LEARNKIT_TEST("음수인 짝수도 더해진다") {
    LEARNKIT_EXPECT_EQ(sumEvens({-4, -3, -2}), -6);
}
