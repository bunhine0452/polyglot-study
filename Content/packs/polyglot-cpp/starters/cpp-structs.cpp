#include <stdexcept>

struct Rectangle {
    double width;
    double height;

    double area() const {
        // width 또는 height 가 0 이하면 0.0 을 돌려준다.
        // 아니면 width * height 를 돌려준다.
        throw std::runtime_error("여기를 구현해라");
    }

    double perimeter() const {
        // width 또는 height 가 0 이하면 0.0 을 돌려준다.
        // 아니면 2 * (width + height) 를 돌려준다.
        throw std::runtime_error("여기를 구현해라");
    }
};
