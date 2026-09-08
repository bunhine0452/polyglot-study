#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("짝수 합의 평균") {
    LEARNKIT_EXPECT_EQ(average(4, 2), 3.0);
}

LEARNKIT_TEST("홀수 합은 소수 평균이 나온다") {
    LEARNKIT_EXPECT_EQ(average(7, 2), 4.5);
}

LEARNKIT_TEST("둘 다 음수여도 된다") {
    LEARNKIT_EXPECT_EQ(average(-5, -2), -3.5);
}

LEARNKIT_TEST("서로 상쇄되면 0이다") {
    LEARNKIT_EXPECT_EQ(average(-3, 3), 0.0);
}
