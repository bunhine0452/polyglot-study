#include <stdexcept>

class DynamicArray {
public:
    explicit DynamicArray(int size) : size_(size), data_(nullptr) {
        // size 개의 int 를 new[] 로 할당하고 모두 0으로 채운다.
        throw std::runtime_error("여기를 구현해라");
    }

    ~DynamicArray() {
        delete[] data_;
    }

    void set(int index, int value) {
        // index 위치에 value 를 저장한다. 범위를 벗어나면 std::out_of_range 를 던진다.
        throw std::runtime_error("여기를 구현해라");
    }

    int get(int index) const {
        // index 위치의 값을 돌려준다. 범위를 벗어나면 std::out_of_range 를 던진다.
        throw std::runtime_error("여기를 구현해라");
    }

    int size() const {
        return size_;
    }

private:
    int size_;
    int* data_;
};
