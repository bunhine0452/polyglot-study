#include <algorithm>
#include <vector>

std::vector<int> filterAndSort(const std::vector<int>& values, int limit) {
    auto isUnder = [limit](int x) { return x < limit; };

    std::vector<int> result;
    for (int v : values) {
        if (isUnder(v)) {
            result.push_back(v);
        }
    }

    std::sort(result.begin(), result.end());
    return result;
}
