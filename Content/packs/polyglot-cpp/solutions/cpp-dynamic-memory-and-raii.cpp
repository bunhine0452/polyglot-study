#include <stdexcept>

class DynamicArray {
public:
    explicit DynamicArray(int size) : size_(size), data_(new int[size]) {
        for (int i = 0; i < size_; ++i) {
            data_[i] = 0;
        }
    }

    ~DynamicArray() {
        delete[] data_;
    }

    void set(int index, int value) {
        if (index < 0 || index >= size_) {
            throw std::out_of_range("index out of range");
        }
        data_[index] = value;
    }

    int get(int index) const {
        if (index < 0 || index >= size_) {
            throw std::out_of_range("index out of range");
        }
        return data_[index];
    }

    int size() const {
        return size_;
    }

private:
    int size_;
    int* data_;
};
