#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("90 이상은 A") {
    LEARNKIT_EXPECT_EQ(classify(95), std::string("A"));
}

LEARNKIT_TEST("경계값 90은 A") {
    LEARNKIT_EXPECT_EQ(classify(90), std::string("A"));
}

LEARNKIT_TEST("경계값 89는 B") {
    LEARNKIT_EXPECT_EQ(classify(89), std::string("B"));
}

LEARNKIT_TEST("경계값 70은 C") {
    LEARNKIT_EXPECT_EQ(classify(70), std::string("C"));
}

LEARNKIT_TEST("70 미만은 F") {
    LEARNKIT_EXPECT_EQ(classify(65), std::string("F"));
}
