#include <string>
#include <vector>
#include <map>
#include <algorithm>

std::vector<std::string> splitWords(const std::string& text) {
    std::vector<std::string> words;
    std::size_t start = text.find_first_not_of(" \t\n");
    while (start != std::string::npos) {
        std::size_t end = text.find_first_of(" \t\n", start);
        if (end == std::string::npos) {
            words.push_back(text.substr(start));
            break;
        }
        words.push_back(text.substr(start, end - start));
        start = text.find_first_not_of(" \t\n", end);
    }
    return words;
}

std::map<std::string, int> wordFrequency(const std::vector<std::string>& words) {
    std::map<std::string, int> freq;
    for (const std::string& word : words) {
        freq[word] += 1;
    }
    return freq;
}

std::vector<std::pair<std::string, int>> sortedByFrequency(const std::map<std::string, int>& freq) {
    std::vector<std::pair<std::string, int>> result(freq.begin(), freq.end());
    std::sort(result.begin(), result.end(),
              [](const std::pair<std::string, int>& a, const std::pair<std::string, int>& b) {
                  if (a.second != b.second) {
                      return a.second > b.second;
                  }
                  return a.first < b.first;
              });
    return result;
}
