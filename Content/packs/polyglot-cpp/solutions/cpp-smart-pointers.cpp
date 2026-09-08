#include <memory>

std::unique_ptr<int> takeOwnership(std::unique_ptr<int>& source) {
    return std::move(source);
}
