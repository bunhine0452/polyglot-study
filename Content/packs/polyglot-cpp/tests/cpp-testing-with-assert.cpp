#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("같은 값이면 일치를 돌려준다") {
    LEARNKIT_EXPECT_EQ(compareResult(5, 5), std::string("일치"));
}

LEARNKIT_TEST("다르면 기대값과 실제값을 순서대로 적는다") {
    LEARNKIT_EXPECT_EQ(compareResult(3, 7), std::string("기대값 7, 실제값 3"));
}

LEARNKIT_TEST("0 도 정상적으로 비교된다") {
    LEARNKIT_EXPECT_EQ(compareResult(0, 0), std::string("일치"));
}

LEARNKIT_TEST("음수도 부호까지 그대로 적는다") {
    LEARNKIT_EXPECT_EQ(compareResult(-2, 5), std::string("기대값 5, 실제값 -2"));
}
