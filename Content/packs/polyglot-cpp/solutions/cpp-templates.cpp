#include <vector>
#include <stdexcept>

template <typename T>
T maxIn(const std::vector<T>& values) {
    if (values.empty()) {
        throw std::invalid_argument("빈 벡터에는 최댓값이 없다");
    }
    T best = values[0];
    for (const T& v : values) {
        if (v > best) {
            best = v;
        }
    }
    return best;
}

template <typename T>
class Pair {
 public:
    Pair(T first, T second) : firstValue(first), secondValue(second) {}

    T getFirst() const {
        return firstValue;
    }

    T getSecond() const {
        return secondValue;
    }

 private:
    T firstValue;
    T secondValue;
};
