@Concept(id: concept) {
지금까지 우리가 만든 코드는 한 번이라도 오류가 나면 그대로 멈췄습니다. `int("abc")`처럼 숫자로 바꿀 수 없는 문자열을 변환하면 `ValueError`가 발생하고, `100 / 0`처럼 0으로 나누면 `ZeroDivisionError`가 발생하면서 프로그램이 그 자리에서 종료됩니다. 파이썬은 이런 실행 중 오류를 **예외(exception)** 라는 이름으로 표현합니다. 예외는 프로그램을 죽이는 실패 선언이 아니라, 잡아서 처리할 수 있는 하나의 사건입니다.

예외를 잡는 도구가 바로 `try`와 `except`입니다. `try` 블록 안에 오류가 날 수 있는 코드를 넣고, 예외가 발생하면 파이썬은 try 블록의 나머지 부분을 건너뛰고 곧바로 `except` 블록으로 이동합니다. 예외가 전혀 발생하지 않으면 except 블록은 그냥 지나쳐 갑니다. 즉 try/except는 "이 코드를 시도해 보고, 이런 종류의 사건이 터지면 이렇게 대응하라"는 뜻이 됩니다.

except 블록은 여러 개 둘 수 있고, 파이썬은 발생한 예외의 종류에 맞는 except 하나만 실행합니다. `except ValueError` 아래에는 숫자 변환 실패 같은 문제를, `except ZeroDivisionError` 아래에는 0으로 나누는 문제를 각각 다르게 대응하도록 작성할 수 있습니다. 또 `except ValueError as e`처럼 `as`를 붙이면 예외 객체를 변수에 담을 수 있어서, 예외가 왜 발생했는지 설명하는 메시지를 그대로 꺼내 쓸 수 있습니다.

예외를 잡는 쪽만 있는 것이 아닙니다. `raise`를 쓰면 우리 코드에서 직접 예외를 발생시킬 수 있습니다. 함수 안에서 인자가 범위를 벗어났거나, 애초에 처리할 수 없는 값이 들어왔을 때 조용히 이상한 값을 반환하는 것보다 `raise ValueError("나이는 음수일 수 없습니다")`처럼 문제를 알려주는 편이 훨씬 안전합니다. raise로 던져진 예외는 그 함수 안에서 잡히지 않는 한 호출한 쪽으로 전달되고, 결국 어디선가 except로 잡히거나 프로그램을 멈추게 합니다. 이 레슨에서는 예외를 잡는 코드와 던지는 코드를 모두 직접 실행해 봅니다.
}

@Example(id: example, language: python, expected: expected/python-exception-handling.txt) {
문자열 목록을 하나씩 정수로 바꿔 나누는 프로그램입니다. `int()`가 실패하면 `ValueError`, 인자가 0이면 `divide_100_by` 안의 `raise`가 `ZeroDivisionError`를 던집니다. 어떤 입력이 들어와도 except가 잡아 주기 때문에 반복문이 끝까지 돌고, 마지막 문장까지 실행됩니다. 직접 실행해 보세요.

```python
def divide_100_by(n):
    if n == 0:
        raise ZeroDivisionError("0으로는 나눌 수 없습니다")
    return round(100 / n, 2)


inputs = ["10", "3", "abc", "0", "7"]
for text in inputs:
    try:
        n = int(text)
        print(f"100 / {n} = {divide_100_by(n)}")
    except ValueError:
        print(f"'{text}'는 숫자가 아닙니다")
    except ZeroDivisionError as e:
        print(f"오류: {e}")
print("모든 입력 처리 완료")
```
}

@Blank(id: blank, language: python) {
예외를 잡는 세 가지 핵심 키워드를 빈칸에 채워 보세요. 목록에서 숫자로 바꿀 수 없는 항목은 건너뛰고, 음량 값이 범위를 벗어나면 직접 예외를 던지는 코드입니다.

```python
def to_int_list(texts):
    result = []
    for t in texts:
        ___1___:
            result.append(int(t))
        except ___2___:
            continue
    return result


def set_volume(level):
    if level < 0 or level > 100:
        ___3___ ValueError("음량은 0에서 100 사이여야 합니다")
    return level


texts = ["10", "x", "20"]
print(to_int_list(texts))
print(set_volume(80))
```

@Answer(slot: 1) {
`try`
}

@Answer(slot: 2) {
`ValueError`
}

@Answer(slot: 3) {
`raise`
}
}

@Task(id: task, language: python, starter: starters/python-exception-handling.py, tests: tests/python-exception-handling.py, solution: solutions/python-exception-handling.py) {
은행 출금 처리기의 일부를 만듭니다. 문자열 금액을 정수로 바꾸는 `parse_amount`와, 출금 규칙을 검사하는 `withdraw` 두 함수를 완성하세요. `withdraw`는 잘못된 요청에서 조용히 값을 돌려주는 대신 직접 예외를 발생시켜야 합니다.

@Hint {
int()가 실패하면 ValueError가 발생합니다. try/except ValueError로 잡아 기본값을 반환하면 됩니다.
}

@Hint {
withdraw에서는 if로 조건을 검사한 뒤 raise ValueError("메시지")로 예외를 던지세요. raise는 return처럼 함수 실행을 그 자리에서 끝냅니다.
}
}

@Quiz(id: quiz, answer: b) {
@Question {
다음 코드를 실행하면 화면에 무엇이 출력될까요?

try:
    x = int("안녕")
    print("계산 완료")
except ValueError:
    print("숫자가 아닙니다")
except ZeroDivisionError:
    print("0으로 나눴습니다")
print("끝")
}

@Choice(id: a) {
"계산 완료"가 출력된 다음 줄에 "끝"이 출력된다
}

@Choice(id: b) {
"숫자가 아닙니다"가 출력된 다음 줄에 "끝"이 출력된다
}

@Choice(id: c) {
"숫자가 아닙니다"와 "0으로 나눴습니다"가 둘 다 출력된 다음 "끝"이 출력된다
}

@Choice(id: d) {
오류 메시지를 출력하며 프로그램이 비정상 종료된다
}

@Explanation {
`int("안녕")`에서 `ValueError`가 발생하므로 try 블록의 나머지인 print("계산 완료")는 건너뛰어지고, 종류가 맞는 `except ValueError` 블록만 실행됩니다. 예외를 잡았기 때문에 프로그램은 멈추지 않고 이어서 print("끝")까지 실행합니다.
}
}

@Reflection(id: reflection) {
@Prompt(id: prompt-1) {
try/except는 강력하지만, 모든 오류를 조용히 잡아 넘겨 버리면 오히려 문제가 생길 수 있습니다. 잡아서 계속 진행해도 괜찮은 오류의 예와, 잡지 말고 프로그램이 멈추게 두는 편이 나은 오류의 예를 하나씩 들고 그 이유를 설명해 보세요.
}

@Prompt(id: prompt-2) {
raise는 프로그램을 죽이는 명령이 아니라 호출한 쪽에 문제를 알리는 신호입니다. 함수를 작성하는 사람 입장에서, 잘못된 인자가 들어왔을 때 이상한 값을 반환하는 대신 raise로 알리는 것이 왜 안전한지 생각해 보세요.
}
}
