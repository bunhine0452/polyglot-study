#include <algorithm>
#include <vector>

void analyze(std::vector<int> values, int target, int& outGreaterCount, int& outSortedIndex) {
    outGreaterCount = 0;
    for (int v : values) {
        if (v > target) {
            outGreaterCount++;
        }
    }

    std::sort(values.begin(), values.end());
    auto it = std::find(values.begin(), values.end(), target);
    if (it == values.end()) {
        outSortedIndex = -1;
    } else {
        outSortedIndex = static_cast<int>(it - values.begin());
    }
}
