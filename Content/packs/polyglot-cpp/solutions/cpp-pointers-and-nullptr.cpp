#include <vector>

int* findFirstNegative(std::vector<int>& numbers) {
    for (std::size_t i = 0; i < numbers.size(); ++i) {
        if (numbers[i] < 0) {
            return &numbers[i];
        }
    }
    return nullptr;
}
