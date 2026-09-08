#include "__learnkit_harness.h"
#include "solution.h"

#include <vector>

LEARNKIT_TEST("첫 음수를 찾는다") {
    std::vector<int> numbers = {3, 5, -2, 8, -9};
    int* result = findFirstNegative(numbers);
    LEARNKIT_EXPECT(result != nullptr);
    LEARNKIT_EXPECT_EQ(*result, -2);
}

LEARNKIT_TEST("가리킨 주소를 통해 값을 바꾸면 원본이 바뀐다") {
    std::vector<int> numbers = {1, -7, 3};
    int* result = findFirstNegative(numbers);
    LEARNKIT_EXPECT(result != nullptr);
    *result = 100;
    LEARNKIT_EXPECT_EQ(numbers[1], 100);
}

LEARNKIT_TEST("음수가 없으면 nullptr 이다") {
    std::vector<int> numbers = {1, 2, 3};
    int* result = findFirstNegative(numbers);
    LEARNKIT_EXPECT(result == nullptr);
}

LEARNKIT_TEST("빈 벡터도 nullptr 이다") {
    std::vector<int> numbers;
    int* result = findFirstNegative(numbers);
    LEARNKIT_EXPECT(result == nullptr);
}
