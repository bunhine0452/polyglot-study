#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("단어별 등장 횟수를 센다") {
    std::vector<std::string> words = {"a", "b", "a", "c", "b", "a"};
    auto result = countWords(words);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(result["a"], 3);
    LEARNKIT_EXPECT_EQ(result["b"], 2);
    LEARNKIT_EXPECT_EQ(result["c"], 1);
}

LEARNKIT_TEST("빈 입력은 빈 map 을 돌려준다") {
    std::vector<std::string> words;
    auto result = countWords(words);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(0));
}

LEARNKIT_TEST("단어가 하나뿐이면 등장 횟수는 1") {
    std::vector<std::string> words = {"홀로"};
    auto result = countWords(words);
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(1));
    LEARNKIT_EXPECT_EQ(result["홀로"], 1);
}

LEARNKIT_TEST("목록에 없는 단어를 조회하면 0이 아니라 count 로 확인해야 한다") {
    std::vector<std::string> words = {"x", "y"};
    auto result = countWords(words);
    LEARNKIT_EXPECT_EQ(result.count("z"), static_cast<std::size_t>(0));
}
