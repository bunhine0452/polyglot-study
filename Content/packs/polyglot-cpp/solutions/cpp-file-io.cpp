#include <fstream>
#include <string>
#include <vector>

void writeLines(const std::string& path, const std::vector<std::string>& lines) {
    std::ofstream out(path);
    for (const std::string& line : lines) {
        out << line << std::endl;
    }
}

std::vector<std::string> readLines(const std::string& path) {
    std::vector<std::string> result;
    std::ifstream in(path);
    if (!in.is_open()) {
        return result;
    }
    std::string line;
    while (std::getline(in, line)) {
        result.push_back(line);
    }
    return result;
}
