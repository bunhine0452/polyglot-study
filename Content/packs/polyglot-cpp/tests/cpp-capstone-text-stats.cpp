#include "__learnkit_harness.h"
#include "solution.h"

#include <string>
#include <vector>
#include <map>

LEARNKIT_TEST("공백으로 단어를 나눈다") {
    std::vector<std::string> words = splitWords("hello world c++");
    LEARNKIT_EXPECT_EQ(words.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(words[0], std::string("hello"));
    LEARNKIT_EXPECT_EQ(words[1], std::string("world"));
    LEARNKIT_EXPECT_EQ(words[2], std::string("c++"));
}

LEARNKIT_TEST("연속된 공백은 하나로 취급하고 빈 문자열은 빈 목록이다") {
    std::vector<std::string> words = splitWords("  a   b  ");
    LEARNKIT_EXPECT_EQ(words.size(), static_cast<std::size_t>(2));
    LEARNKIT_EXPECT_EQ(words[0], std::string("a"));
    LEARNKIT_EXPECT_EQ(words[1], std::string("b"));

    std::vector<std::string> empty = splitWords("");
    LEARNKIT_EXPECT_EQ(empty.size(), static_cast<std::size_t>(0));
}

LEARNKIT_TEST("단어 빈도를 센다") {
    std::vector<std::string> words = {"a", "b", "a", "c", "a", "b"};
    std::map<std::string, int> freq = wordFrequency(words);
    LEARNKIT_EXPECT_EQ(freq.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(freq["a"], 3);
    LEARNKIT_EXPECT_EQ(freq["b"], 2);
    LEARNKIT_EXPECT_EQ(freq["c"], 1);
}

LEARNKIT_TEST("빈도 내림차순, 동률이면 단어 오름차순으로 정렬한다") {
    std::map<std::string, int> freq;
    freq["banana"] = 2;
    freq["apple"] = 2;
    freq["cherry"] = 3;
    std::vector<std::pair<std::string, int>> sorted = sortedByFrequency(freq);
    LEARNKIT_EXPECT_EQ(sorted.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(sorted[0].first, std::string("cherry"));
    LEARNKIT_EXPECT_EQ(sorted[0].second, 3);
    LEARNKIT_EXPECT_EQ(sorted[1].first, std::string("apple"));
    LEARNKIT_EXPECT_EQ(sorted[2].first, std::string("banana"));
}

LEARNKIT_TEST("빈 map 을 정렬하면 빈 목록이다") {
    std::map<std::string, int> freq;
    std::vector<std::pair<std::string, int>> sorted = sortedByFrequency(freq);
    LEARNKIT_EXPECT_EQ(sorted.size(), static_cast<std::size_t>(0));
}
