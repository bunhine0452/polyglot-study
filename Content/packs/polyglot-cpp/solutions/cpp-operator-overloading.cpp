#include <ostream>
#include <stdexcept>

class Fraction {
 public:
    Fraction(int num, int den) {
        if (den == 0) {
            throw std::invalid_argument("분모는 0일 수 없다");
        }
        num_ = num;
        den_ = den;
    }

    Fraction operator+(const Fraction& other) const {
        return Fraction(num_ * other.den_ + other.num_ * den_, den_ * other.den_);
    }

    bool operator==(const Fraction& other) const {
        return num_ * other.den_ == other.num_ * den_;
    }

    int getNumerator() const {
        return num_;
    }

    int getDenominator() const {
        return den_;
    }

 private:
    int num_;
    int den_;
};

inline std::ostream& operator<<(std::ostream& out, const Fraction& f) {
    out << f.getNumerator() << "/" << f.getDenominator();
    return out;
}
