#include <vector>
#include <stdexcept>

template <typename T>
T maxIn(const std::vector<T>& values) {
    // values 가 비어 있으면 std::invalid_argument 를 던진다.
    // 아니면 > 로 비교하며 최댓값을 찾아 돌려준다.
    throw std::runtime_error("여기를 구현해라");
}

template <typename T>
class Pair {
 public:
    Pair(T first, T second) {
        // first, second 를 필드에 채운다.
        throw std::runtime_error("여기를 구현해라");
    }

    T getFirst() const {
        throw std::runtime_error("여기를 구현해라");
    }

    T getSecond() const {
        throw std::runtime_error("여기를 구현해라");
    }

 private:
    T firstValue;
    T secondValue;
};
