@Concept(id: cpp-loops-concept) {
`for` 문은 초기화·조건·증감을 한자리에 모아 둔다. 반복할 횟수나 범위를 시작할 때부터 알고 있을 때 특히 잘 맞는데, 반복을 통제하는 세 부분이 한눈에 들어와 "어디서 시작해서 언제까지 어떻게 나아가는지" 를 코드만 보고 바로 알 수 있기 때문이다. `while` 도 같은 반복을 표현할 수 있지만 그 세 부분이 흩어져 있어 놓치기 쉽다.

`while` 은 몸통을 실행하기 **전에** 조건을 검사하고, `do-while` 은 몸통을 실행한 **뒤에** 조건을 검사한다. 이 순서 차이 때문에 조건이 처음부터 거짓이면 `while` 은 단 한 번도 돌지 않지만, `do-while` 은 무조건 최소 한 번은 실행된다. 예를 들어 사용자에게 무언가를 한 번 보여준 다음에야 "더 할지 말지" 를 물을 수 있는 상황이라면, 그 첫 실행을 조건 검사 뒤로 미룰 수 없으므로 `do-while` 이 자연스럽다.

`continue` 는 그 순간의 반복만 즉시 그만두고 다음 반복 조건 검사(또는 for 의 증감)로 건너뛴다 — 반복 자체는 계속된다. 반면 `break` 는 반복 자체를 완전히 끝내고 빠져나온다. 둘 다 "건너뛴다" 는 느낌이라 헷갈리기 쉽지만, continue 는 "이번 판은 그만, 다음 판으로" 이고 break 는 "게임 자체를 종료" 라는 차이가 있다.
}

@Example(id: cpp-loops-example, language: cpp, expected: expected/cpp-loops.txt) {
for 에서 continue 로 짝수를 건너뛰고, while 과 do-while 을 나란히 돌려 시작 조건의 차이를 확인한다.

```cpp
#include <iostream>

int main() {
    for (int i = 1; i <= 5; ++i) {
        if (i % 2 == 0) {
            continue;
        }
        std::cout << "홀수: " << i << std::endl;
    }

    int count = 0;
    while (count < 3) {
        std::cout << "while: " << count << std::endl;
        ++count;
    }

    int x = 10;
    do {
        std::cout << "do-while: " << x << std::endl;
        ++x;
    } while (x < 10);

    return 0;
}
```
}

@Blank(id: cpp-loops-blank, language: cpp) {
3의 배수를 건너뛰는 자리와, do 블록을 끝맺는 키워드를 채워 완성하자.

```cpp
#include <iostream>

int main() {
    for (int i = 1; i <= 6; ++i) {
        if (i % 3 == 0) {
            ___1___;
        }
        std::cout << i << " ";
    }
    std::cout << std::endl;

    int n = 0;
    do {
        std::cout << "n=" << n << std::endl;
        ++n;
    } ___2___ (n < 2);

    return 0;
}
```

@Answer(slot: 1) {
`continue`
}

@Answer(slot: 2) {
`while`
}
}

@Task(id: cpp-loops-task, language: cpp, starter: starters/cpp-loops.cpp, tests: tests/cpp-loops.cpp, solution: solutions/cpp-loops.cpp) {
1부터 n 까지의 정수를 더하되 3의 배수는 더하지 않고 건너뛰는 함수 `sumSkipMultiplesOfThree` 를 완성하라. 단, 더해 나가는 도중 합계가 100 을 넘는 순간 그 자리에서 즉시 반복을 멈추고 그때까지의 합을 반환해야 한다 — n 이 아무리 커도 100 을 넘기고 나면 더 이상 더하지 않는다. n 이 0이면 0을 반환한다.

@Hint {
continue 는 그 순간의 반복만 건너뛴다 — sum += i 를 하기 전에 3의 배수인지 검사해 continue 하라.
}

@Hint {
sum 을 더한 직후에 100 을 넘었는지 검사해서 넘었으면 break 로 반복 자체를 끝내라.
}

@Hint {
n 이 0이면 for 의 조건 i <= n 이 처음부터 거짓이라 몸통이 한 번도 실행되지 않는다.
}
}

@Quiz(id: cpp-loops-quiz, answer: while-five-do-six) {
@Question {
x = 5 로 시작할 때, `while (x < 3) { x++; }` 와 `do { x++; } while (x < 3);` 를 각각 실행하면 x 의 최종값은 어떻게 다를까요?
}

@Choice(id: both-five) {
둘 다 5 그대로다
}

@Choice(id: while-five-do-six) {
while 은 5 그대로이고, do-while 은 6이 된다
}

@Choice(id: both-six) {
둘 다 6이 된다
}

@Choice(id: infinite-loop) {
둘 다 무한 루프에 빠진다
}

@Explanation {
while 은 몸통을 실행하기 전에 조건을 검사한다. x<3, 즉 5<3 은 처음부터 거짓이므로 몸통이 한 번도 실행되지 않아 x 는 5 그대로다. do-while 은 몸통을 먼저 한 번 실행한 뒤에야 조건을 검사하므로 x++ 가 한 번 실행되어 6이 되고, 그다음 6<3 이 거짓이라 멈춘다. 두 경우 모두 조건이 곧 거짓이 되므로 무한 루프에는 빠지지 않는다.
}
}

@Reflection(id: cpp-loops-reflection) {
@Prompt(id: do-while-use-case) {
do-while 이 유용한, 즉 '몸통을 최소 한 번은 반드시 실행해야 하는' 실제 상황을 하나 떠올려 적어 보세요.
}

@Prompt(id: continue-vs-break) {
continue 와 break 는 둘 다 반복 도중 '건너뛰는' 느낌을 주지만 정확히 어디로 가는지가 다릅니다. 이 차이를 자신의 말로 설명해 보세요.
}
}
