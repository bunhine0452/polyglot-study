#include <map>
#include <string>
#include <vector>

std::map<std::string, int> countWords(const std::vector<std::string>& words) {
    std::map<std::string, int> counts;
    for (const std::string& word : words) {
        counts[word]++;
    }
    return counts;
}
