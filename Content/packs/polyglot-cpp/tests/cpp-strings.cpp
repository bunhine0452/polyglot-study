#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("평범한 이메일에서 도메인을 잘라낸다") {
    LEARNKIT_EXPECT_EQ(extractDomain("user@example.com"), std::string("example.com"));
}

LEARNKIT_TEST("다른 이메일도 된다") {
    LEARNKIT_EXPECT_EQ(extractDomain("a@b.co"), std::string("b.co"));
}

LEARNKIT_TEST("골뱅이가 없으면 빈 문자열이다") {
    LEARNKIT_EXPECT_EQ(extractDomain("no-at-sign"), std::string(""));
}

LEARNKIT_TEST("골뱅이가 맨 앞이어도 된다") {
    LEARNKIT_EXPECT_EQ(extractDomain("@onlydomain.com"), std::string("onlydomain.com"));
}
