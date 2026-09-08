#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("양수를 두 배로 만든다") {
    int n = 5;
    doubleInPlace(n);
    LEARNKIT_EXPECT_EQ(n, 10);
}

LEARNKIT_TEST("0은 그대로 0이다") {
    int n = 0;
    doubleInPlace(n);
    LEARNKIT_EXPECT_EQ(n, 0);
}

LEARNKIT_TEST("음수도 부호를 유지한 채 두 배가 된다") {
    int n = -3;
    doubleInPlace(n);
    LEARNKIT_EXPECT_EQ(n, -6);
}
