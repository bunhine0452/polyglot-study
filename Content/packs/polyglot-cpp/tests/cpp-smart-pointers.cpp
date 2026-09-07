#include "__learnkit_harness.h"
#include "solution.h"

#include <memory>

LEARNKIT_TEST("소유권을 가져오면 값을 그대로 담고 있다") {
    std::unique_ptr<int> original = std::make_unique<int>(42);
    std::unique_ptr<int> taken = takeOwnership(original);
    LEARNKIT_EXPECT(taken.get() != nullptr);
    LEARNKIT_EXPECT_EQ(*taken, 42);
}

LEARNKIT_TEST("가져온 뒤 원래 포인터는 비워진다") {
    std::unique_ptr<int> original = std::make_unique<int>(7);
    std::unique_ptr<int> taken = takeOwnership(original);
    (void)taken;
    LEARNKIT_EXPECT(original.get() == nullptr);
}

LEARNKIT_TEST("다른 값으로도 동작한다") {
    std::unique_ptr<int> original = std::make_unique<int>(-3);
    std::unique_ptr<int> taken = takeOwnership(original);
    LEARNKIT_EXPECT_EQ(*taken, -3);
}

LEARNKIT_TEST("이미 비어 있는 포인터를 넘기면 비어 있는 채로 돌아온다") {
    std::unique_ptr<int> empty;
    std::unique_ptr<int> taken = takeOwnership(empty);
    LEARNKIT_EXPECT(taken.get() == nullptr);
}
