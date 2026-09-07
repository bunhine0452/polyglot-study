#include "__learnkit_harness.h"
#include "solution.h"

#include <vector>
#include <string>

LEARNKIT_TEST("쓴 줄을 그대로 읽어온다") {
    std::vector<std::string> lines = {"첫 줄", "둘째 줄", "셋째 줄"};
    writeLines("test_output_1.txt", lines);
    std::vector<std::string> result = readLines("test_output_1.txt");
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(3));
    LEARNKIT_EXPECT_EQ(result[0], std::string("첫 줄"));
    LEARNKIT_EXPECT_EQ(result[1], std::string("둘째 줄"));
    LEARNKIT_EXPECT_EQ(result[2], std::string("셋째 줄"));
}

LEARNKIT_TEST("빈 목록을 쓰면 빈 파일이 되어 빈 목록으로 읽힌다") {
    std::vector<std::string> lines;
    writeLines("test_output_2.txt", lines);
    std::vector<std::string> result = readLines("test_output_2.txt");
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(0));
}

LEARNKIT_TEST("존재하지 않는 파일을 읽으면 빈 벡터를 돌려준다") {
    std::vector<std::string> result = readLines("this_file_does_not_exist_12345.txt");
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(0));
}

LEARNKIT_TEST("다시 쓰면 이전 내용을 덮어쓴다") {
    writeLines("test_output_3.txt", {"오래된 내용"});
    writeLines("test_output_3.txt", {"새 내용"});
    std::vector<std::string> result = readLines("test_output_3.txt");
    LEARNKIT_EXPECT_EQ(result.size(), static_cast<std::size_t>(1));
    LEARNKIT_EXPECT_EQ(result[0], std::string("새 내용"));
}
