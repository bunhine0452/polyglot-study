#include "__learnkit_harness.h"
#include "solution.h"
#include <sstream>

LEARNKIT_TEST("생성자가 분자·분모를 그대로 채운다") {
    Fraction f(3, 4);
    LEARNKIT_EXPECT_EQ(f.getNumerator(), 3);
    LEARNKIT_EXPECT_EQ(f.getDenominator(), 4);
}

LEARNKIT_TEST("분모가 0이면 예외를 던진다") {
    bool threw = false;
    try {
        Fraction f(1, 0);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    LEARNKIT_EXPECT(threw);
}

LEARNKIT_TEST("operator+ 가 공식대로 더한다") {
    Fraction a(1, 2);
    Fraction b(1, 3);
    Fraction sum = a + b;
    LEARNKIT_EXPECT_EQ(sum.getNumerator(), 5);
    LEARNKIT_EXPECT_EQ(sum.getDenominator(), 6);
}

LEARNKIT_TEST("operator== 은 표현이 달라도 같은 값이면 참") {
    Fraction a(1, 2);
    Fraction b(2, 4);
    LEARNKIT_EXPECT(a == b);
}

LEARNKIT_TEST("operator== 은 값이 다르면 거짓") {
    Fraction a(1, 2);
    Fraction b(1, 3);
    LEARNKIT_EXPECT(!(a == b));
}

LEARNKIT_TEST("operator<< 가 분자/분모 형식으로 찍는다") {
    Fraction f(3, 4);
    std::ostringstream out;
    out << f;
    LEARNKIT_EXPECT_EQ(out.str(), std::string("3/4"));
}
