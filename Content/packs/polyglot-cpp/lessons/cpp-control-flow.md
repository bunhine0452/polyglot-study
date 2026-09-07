@Concept(id: cpp-control-concept) {
`if` 는 조건을 위에서 아래로 순서대로 검사한다. 맨 처음 참으로 판정되는 조건의 블록만 실행되고, 그 뒤에 나오는 `else if`·`else` 는 전부 건너뛴다. 그래서 조건을 쓰는 순서가 중요하다 — 넓은 범위를 먼저 검사하면 좁은 범위는 영영 검사될 기회를 얻지 못한다. `else` 는 앞의 조건이 전부 거짓일 때 실행되는 마지막 안전망이다.

`switch` 는 다른 방식으로 갈라진다. 조건을 하나씩 참·거짓으로 따지는 게 아니라, 괄호 안 값과 똑같은 `case` 라벨을 찾아 그 지점으로 곧장 건너뛴다. 그래서 switch 는 범위나 복합 조건이 아니라 "이 값이 정확히 무엇과 같은가" 를 따질 때 쓴다.

switch 에서 헷갈리는 점은 `case` 라벨이 실행을 막는 장벽이 아니라 그냥 진입점이라는 것이다. 어떤 case 로 뛰어든 뒤에는 `break` 를 만나기 전까지 그 아래 코드가 순서대로 계속 실행된다 — 설령 그 코드가 다른 case 라벨 아래에 있어도 상관없다. `break` 를 빠뜨리면 의도치 않게 다음 case 의 코드까지 실행되어 버린다. 반대로 이 성질을 일부러 이용해 여러 case 라벨을 몸통 없이 연달아 쌓아 두면(예: `case 1: case 2:`), "1이거나 2" 를 표현하는 관용적인 방법이 된다.
}

@Example(id: cpp-control-example, language: cpp, expected: expected/cpp-control-flow.txt) {
if-else if-else 로 점수를 학점으로 나누고, switch 에서 여러 case 를 몸통 없이 묶어 요일을 분류한다.

```cpp
#include <iostream>

int main() {
    int score = 82;

    if (score >= 90) {
        std::cout << "학점: A" << std::endl;
    } else if (score >= 80) {
        std::cout << "학점: B" << std::endl;
    } else {
        std::cout << "학점: C 이하" << std::endl;
    }

    int day = 3;
    switch (day) {
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
            std::cout << "평일" << std::endl;
            break;
        case 6:
        case 7:
            std::cout << "주말" << std::endl;
            break;
        default:
            std::cout << "잘못된 값" << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-control-blank, language: cpp) {
온도 분기의 두 번째 조건과, switch 의 case 1 을 끝맺는 키워드를 채워 완성하자.

```cpp
#include <iostream>

int main() {
    int temperature = 15;

    if (temperature >= 30) {
        std::cout << "더움" << std::endl;
    } ___1___ (temperature >= 10) {
        std::cout << "적당함" << std::endl;
    } else {
        std::cout << "추움" << std::endl;
    }

    int level = 2;
    switch (level) {
        case 1:
            std::cout << "낮음" << std::endl;
            ___2___;
        case 2:
            std::cout << "보통" << std::endl;
            break;
        default:
            std::cout << "알 수 없음" << std::endl;
    }

    return 0;
}
```

@Answer(slot: 1) {
`else if`
}

@Answer(slot: 2) {
`break`
}
}

@Task(id: cpp-control-task, language: cpp, starter: starters/cpp-control-flow.cpp, tests: tests/cpp-control-flow.cpp, solution: solutions/cpp-control-flow.cpp) {
점수를 받아 학점을 문자열로 돌려주는 함수 `classify` 를 완성하라. 90 이상이면 "A", 80 이상 90 미만이면 "B", 70 이상 80 미만이면 "C", 그 미만이면 "F" 를 돌려준다. 경계값도 정확히 처리해야 한다 — 정확히 90 은 A, 89 는 B 여야 한다.

@Hint {
조건은 위에서 아래로 검사되어 먼저 참인 곳에서 멈춘다 — 큰 값 기준부터 검사하는 순서를 지켜라.
}

@Hint {
각 분기에서 바로 return 하면 그 아래 조건은 검사되지 않는다.
}

@Hint {
경계값 90·80·70 은 각각 그 등급에 '포함'된다 — >= 를 써라.
}
}

@Quiz(id: cpp-control-quiz, answer: falls-through) {
@Question {
switch 문에서 case 1 의 본문 끝에 break 를 빠뜨렸고 바로 다음에 case 2 가 이어진다면, x 가 1일 때 실행 흐름은 어떻게 될까요?
}

@Choice(id: case1-only) {
case 1 의 코드만 실행되고 switch 를 빠져나간다
}

@Choice(id: falls-through) {
case 1 의 코드가 실행된 뒤, break 를 만날 때까지 case 2 의 코드도 이어서 실행된다
}

@Choice(id: nothing-runs) {
라벨 사이에 break 가 없으므로 두 case 모두 실행되지 않는다
}

@Choice(id: compile-error) {
break 가 없는 case 가 있으면 컴파일 에러가 난다
}

@Explanation {
case 라벨은 실행을 가로막는 장벽이 아니라 그저 뛰어드는 진입점이다. break 가 없으면 흐름은 라벨을 무시하고 다음 줄로 그대로 이어지므로, case 1 의 코드를 실행한 뒤 break 를 만날 때까지 case 2 의 코드까지 실행된다. 컴파일은 문제없이 되고, 실행이 멈추는 것도 아니며 오히려 여러 case 가 이어서 도는 것이 핵심이다.
}
}

@Reflection(id: cpp-control-reflection) {
@Prompt(id: label-not-barrier) {
case 라벨이 '장벽'이 아니라 '진입점'이라는 설명을 읽고, 이 성질 때문에 실수하기 쉬운 상황을 하나 떠올려 적어 보세요.
}

@Prompt(id: if-vs-switch-choice) {
if-else 체인과 switch 중 하나를 골라야 한다면, 어떤 상황에서 어느 쪽을 쓰겠는지 이유와 함께 적어 보세요.
}
}
