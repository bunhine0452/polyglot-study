#include <string>

std::string extractDomain(const std::string& email) {
    std::size_t pos = email.find('@');
    if (pos == std::string::npos) {
        return "";
    }
    return email.substr(pos + 1);
}
