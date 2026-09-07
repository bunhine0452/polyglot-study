#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("초기값이 그대로 반영된다") {
    Stock s(10);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 10);
}

LEARNKIT_TEST("음수 초기값은 0이 된다") {
    Stock s(-5);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 0);
}

LEARNKIT_TEST("add 로 늘어난다") {
    Stock s(10);
    s.add(5);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 15);
}

LEARNKIT_TEST("add 에 음수를 주면 무시된다") {
    Stock s(10);
    s.add(-3);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 10);
}

LEARNKIT_TEST("remove 가 정상적으로 줄어들고 true 를 돌려준다") {
    Stock s(10);
    bool ok = s.remove(4);
    LEARNKIT_EXPECT(ok);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 6);
}

LEARNKIT_TEST("remove 가 재고보다 많으면 실패하고 변화 없다") {
    Stock s(3);
    bool ok = s.remove(10);
    LEARNKIT_EXPECT(!ok);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 3);
}

LEARNKIT_TEST("remove 에 0을 주면 실패한다") {
    Stock s(5);
    bool ok = s.remove(0);
    LEARNKIT_EXPECT(!ok);
    LEARNKIT_EXPECT_EQ(s.getQuantity(), 5);
}
