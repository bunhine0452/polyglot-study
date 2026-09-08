#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("기본 할인율 25퍼센트가 적용된다") {
    double price = 100.0;
    applyDiscount(price);
    LEARNKIT_EXPECT_EQ(price, 75.0);
}

LEARNKIT_TEST("명시한 할인율이 우선한다") {
    double price = 80.0;
    applyDiscount(price, 0.5);
    LEARNKIT_EXPECT_EQ(price, 40.0);
}

LEARNKIT_TEST("할인율 0이면 가격이 그대로다") {
    double price = 50.0;
    applyDiscount(price, 0.0);
    LEARNKIT_EXPECT_EQ(price, 50.0);
}

LEARNKIT_TEST("가격 0에도 안전하다") {
    double price = 0.0;
    applyDiscount(price);
    LEARNKIT_EXPECT_EQ(price, 0.0);
}
