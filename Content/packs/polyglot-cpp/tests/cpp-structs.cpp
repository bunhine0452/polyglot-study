#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("평범한 직사각형의 넓이") {
    Rectangle r{4.0, 5.0};
    LEARNKIT_EXPECT_EQ(r.area(), 20.0);
}

LEARNKIT_TEST("평범한 직사각형의 둘레") {
    Rectangle r{4.0, 5.0};
    LEARNKIT_EXPECT_EQ(r.perimeter(), 18.0);
}

LEARNKIT_TEST("정사각형도 된다") {
    Rectangle r{3.0, 3.0};
    LEARNKIT_EXPECT_EQ(r.area(), 9.0);
    LEARNKIT_EXPECT_EQ(r.perimeter(), 12.0);
}

LEARNKIT_TEST("너비가 0이면 넓이와 둘레 모두 0") {
    Rectangle r{0.0, 5.0};
    LEARNKIT_EXPECT_EQ(r.area(), 0.0);
    LEARNKIT_EXPECT_EQ(r.perimeter(), 0.0);
}

LEARNKIT_TEST("음수 높이도 0을 돌려준다") {
    Rectangle r{4.0, -1.0};
    LEARNKIT_EXPECT_EQ(r.area(), 0.0);
    LEARNKIT_EXPECT_EQ(r.perimeter(), 0.0);
}
