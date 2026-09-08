#include "__learnkit_harness.h"
#include "solution.h"

LEARNKIT_TEST("매니저 보너스는 급여의 10퍼센트다") {
    Manager m("김부장", 1000000);
    LEARNKIT_EXPECT_EQ(m.bonus(), 100000);
}

LEARNKIT_TEST("인턴 보너스는 급여와 무관하게 고정이다") {
    Intern i("이인턴", 2000000);
    LEARNKIT_EXPECT_EQ(i.bonus(), 50000);
}

LEARNKIT_TEST("기반 클래스 포인터로 호출해도 각자의 재정의가 실행된다") {
    Manager m("박부장", 500000);
    Intern i("최인턴", 100);
    Employee* asManager = &m;
    Employee* asIntern = &i;
    LEARNKIT_EXPECT_EQ(asManager->bonus(), 50000);
    LEARNKIT_EXPECT_EQ(asIntern->bonus(), 50000);
}

LEARNKIT_TEST("나눠떨어지지 않는 급여는 소수점 이하를 버린다") {
    Manager m("경계", 55);
    LEARNKIT_EXPECT_EQ(m.bonus(), 5);
}
