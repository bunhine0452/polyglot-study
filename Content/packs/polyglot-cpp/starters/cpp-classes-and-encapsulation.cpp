#include <stdexcept>

class Stock {
 public:
    Stock(int initial) {
        // initial 이 음수면 0으로, 아니면 그대로 quantity 에 채운다.
        throw std::runtime_error("여기를 구현해라");
    }

    void add(int amount) {
        // amount 가 양수일 때만 더한다.
        throw std::runtime_error("여기를 구현해라");
    }

    bool remove(int amount) {
        // amount 가 양수이고 quantity 이하일 때만 빼고 true, 아니면 false.
        throw std::runtime_error("여기를 구현해라");
    }

    int getQuantity() const {
        return quantity;
    }

 private:
    int quantity;
};
