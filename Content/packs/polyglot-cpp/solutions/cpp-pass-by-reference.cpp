#include <vector>
#include <stdexcept>

void findMinMax(const std::vector<int>& values, int& outMin, int& outMax) {
    if (values.empty()) {
        throw std::invalid_argument("빈 벡터에는 최솟값·최댓값이 없다");
    }
    outMin = values[0];
    outMax = values[0];
    for (int v : values) {
        if (v < outMin) {
            outMin = v;
        }
        if (v > outMax) {
            outMax = v;
        }
    }
}
