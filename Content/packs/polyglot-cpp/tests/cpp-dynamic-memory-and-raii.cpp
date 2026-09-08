#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("초기값은 모두 0이다") {
    DynamicArray arr(3);
    LEARNKIT_EXPECT_EQ(arr.get(0), 0);
    LEARNKIT_EXPECT_EQ(arr.get(1), 0);
    LEARNKIT_EXPECT_EQ(arr.get(2), 0);
}

LEARNKIT_TEST("set 한 값을 get 으로 읽는다") {
    DynamicArray arr(4);
    arr.set(2, 99);
    LEARNKIT_EXPECT_EQ(arr.get(2), 99);
    LEARNKIT_EXPECT_EQ(arr.get(0), 0);
}

LEARNKIT_TEST("size 가 생성자에 준 값과 같다") {
    DynamicArray arr(10);
    LEARNKIT_EXPECT_EQ(arr.size(), 10);
}

LEARNKIT_TEST("범위를 벗어난 인덱스는 예외를 던진다") {
    DynamicArray arr(3);
    bool threw = false;
    try {
        arr.set(3, 1);
    } catch (const std::out_of_range&) {
        threw = true;
    }
    LEARNKIT_EXPECT(threw);
}
