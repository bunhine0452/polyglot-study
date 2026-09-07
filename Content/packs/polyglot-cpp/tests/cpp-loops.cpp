#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("n이 0이면 0이다") {
    LEARNKIT_EXPECT_EQ(sumSkipMultiplesOfThree(0), 0);
}

LEARNKIT_TEST("작은 n은 그대로 다 더한다") {
    LEARNKIT_EXPECT_EQ(sumSkipMultiplesOfThree(5), 12);
}

LEARNKIT_TEST("100 문턱 바로 아래에서는 끝까지 돈다") {
    LEARNKIT_EXPECT_EQ(sumSkipMultiplesOfThree(16), 91);
}

LEARNKIT_TEST("100을 넘는 순간 멈춘다") {
    LEARNKIT_EXPECT_EQ(sumSkipMultiplesOfThree(17), 108);
}

LEARNKIT_TEST("n이 커도 멈춘 지점 이후로는 더하지 않는다") {
    LEARNKIT_EXPECT_EQ(sumSkipMultiplesOfThree(1000), 108);
}
