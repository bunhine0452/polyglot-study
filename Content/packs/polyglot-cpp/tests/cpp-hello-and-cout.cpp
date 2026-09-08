#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("이름을 넣어 인사한다") {
    LEARNKIT_EXPECT_EQ(greeting("세계"), std::string("안녕하세요, 세계!"));
}

LEARNKIT_TEST("다른 이름도 된다") {
    LEARNKIT_EXPECT_EQ(greeting("C++"), std::string("안녕하세요, C++!"));
}

LEARNKIT_TEST("빈 문자열은 이름 없음이다") {
    LEARNKIT_EXPECT_EQ(greeting(""), std::string("안녕하세요, 이름 없음!"));
}
