#include <vector>
#include <numeric>
#include <algorithm>

int sumOfSquares(const std::vector<int>& values) {
    return std::accumulate(values.begin(), values.end(), 0,
                            [](int acc, int n) { return acc + n * n; });
}

std::vector<int> incrementAll(const std::vector<int>& values, int amount) {
    std::vector<int> result(values.size());
    std::transform(values.begin(), values.end(), result.begin(),
                    [amount](int n) { return n + amount; });
    return result;
}
