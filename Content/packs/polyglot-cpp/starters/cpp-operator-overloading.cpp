#include <ostream>
#include <stdexcept>

class Fraction {
 public:
    Fraction(int num, int den) {
        // den 이 0이면 std::invalid_argument 를 던진다.
        // 아니면 분자·분모를 필드에 채운다.
        throw std::runtime_error("여기를 구현해라");
    }

    Fraction operator+(const Fraction& other) const {
        throw std::runtime_error("여기를 구현해라");
    }

    bool operator==(const Fraction& other) const {
        throw std::runtime_error("여기를 구현해라");
    }

    int getNumerator() const {
        throw std::runtime_error("여기를 구현해라");
    }

    int getDenominator() const {
        throw std::runtime_error("여기를 구현해라");
    }

 private:
    int num_;
    int den_;
};

inline std::ostream& operator<<(std::ostream& out, const Fraction& f) {
    // "분자/분모" 형식으로 out 에 쓰고 out 을 돌려준다.
    throw std::runtime_error("여기를 구현해라");
}
