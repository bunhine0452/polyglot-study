#include <vector>

int sumEvens(const std::vector<int>& nums) {
    int total = 0;
    for (int n : nums) {
        if (n % 2 == 0) {
            total += n;
        }
    }
    return total;
}
