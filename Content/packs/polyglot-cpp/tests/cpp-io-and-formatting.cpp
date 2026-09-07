#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("소수 한 자리는 0으로 채워진다") {
    LEARNKIT_EXPECT_EQ(formatFixed(3.1), std::string("3.10"));
}

LEARNKIT_TEST("반올림된다") {
    LEARNKIT_EXPECT_EQ(formatFixed(19.999), std::string("20.00"));
}

LEARNKIT_TEST("0.0은 0.00이다") {
    LEARNKIT_EXPECT_EQ(formatFixed(0.0), std::string("0.00"));
}

LEARNKIT_TEST("음수도 부호가 유지된다") {
    LEARNKIT_EXPECT_EQ(formatFixed(-2.5), std::string("-2.50"));
}
