@Concept(id: swift-error-handling) {
함수가 실패할 수 있다는 사실은 반환값만으로는 드러나지 않는다. Swift 는 실패 가능성을 함수의 시그니처에 적도록 강제한다. 오류는 Error 프로토콜을 채택한 값으로 표현하는데, 보통 case 마다 실패 상황 하나를 담는 열거형으로 정의한다. 연관 값을 붙이면 "얼마가 부족했는가" 같은 구체적인 정보를 오류에 실어 보낼 수 있다.

던질 수 있는 함수는 선언 뒤에 throws 를 붙이고, 실패 지점에서 throw 로 오류 값을 던진다. throw 는 그 자리에서 함수 실행을 즉시 중단시킨다. throws 함수를 호출하는 쪽은 try 를 붙여야 컴파일되는데, 이는 "이 호출은 실패할 수 있다"는 사실을 코드에 남기는 장치다.

던져진 오류는 do 블록 안에서 try 로 호출하고 catch 절에서 받아 처리한다. catch 뒤에 패턴을 적으면 특정 오류만 골라 잡을 수 있고, 패턴 없이 catch 만 쓰면 모든 오류를 error 라는 상수로 받는다. 패턴이 붙은 catch 는 그 오류만 잡으므로, 컴파일러가 잡지 못한 오류를 대비해 마지막에 패턴 없는 catch 를 하나 두는 것이 안전하다. 실패와 성공의 흐름이 타입과 문법에 그대로 드러나기 때문에, 호출하는 사람은 컴파일러의 안내만으로 오류 처리를 건너뛰지 않게 된다.
}

@Example(id: login-error-example, language: swift, expected: expected/swift-error-handling-throws.txt) {
로그인 검사 함수가 세 가지 경우를 각각 다른 오류로 던지고, 호출하는 쪽은 do-catch 로 오류별로 다른 안내 문구를 출력한다.

```swift
enum LoginError: Error {
    case emptyID
    case tooShort(minimum: Int)
}

func validate(id: String, password: String) throws {
    if id.isEmpty {
        throw LoginError.emptyID
    }
    if password.count < 4 {
        throw LoginError.tooShort(minimum: 4)
    }
}

func login(id: String, password: String) {
    do {
        try validate(id: id, password: password)
        print("\(id) 로그인 성공")
    } catch LoginError.emptyID {
        print("아이디를 입력해 주세요")
    } catch LoginError.tooShort(let minimum) {
        print("비밀번호는 \(minimum)자 이상이어야 합니다")
    } catch {
        print("알 수 없는 오류: \(error)")
    }
}

login(id: "hyun", password: "swift123")
login(id: "", password: "swift123")
login(id: "hyun", password: "12")
```
}

@Blank(id: fill-throw-try-catch, language: swift) {
오류를 던지는 문장, 던지는 함수를 부르는 문장, 오류를 잡는 문장을 채워 흐름을 완성해 보자.

```swift
enum FormError: Error {
    case missingName
}

func greeting(for name: String?) throws -> String {
    guard let name, !name.isEmpty else {
        ___1___ FormError.missingName
    }
    return "안녕하세요, \(name)님"
}

func run(with name: String?) {
    do {
        let message = ___2___ greeting(for: name)
        print(message)
    } ___3___ FormError.missingName {
        print("이름이 필요합니다")
    } catch {
        print("알 수 없는 오류: \(error)")
    }
}
```

@Answer(slot: 1) {
`throw`
}

@Answer(slot: 2) {
`try`
}

@Answer(slot: 3) {
`catch`
}
}

@Task(id: withdraw-task, language: swift, starter: starters/swift-error-handling-throws.swift, tests: tests/swift-error-handling-throws.swift, solution: solutions/swift-error-handling-throws.swift) {
은행 계좌 출금 함수 withdraw(balance:amount:) 를 완성하라. amount 가 0 이하이면 BankError.invalidAmount 를, amount 가 balance 보다 크면 BankError.insufficientFunds(needed: amount - balance) 를 던진다. 정상이면 출금 후 남은 잔액을 Int 로 반환한다. 열거형 BankError 는 이미 starter 에 정의되어 있으니 그대로 두고 함수 본문만 채워라.

@Hint {
던지는 자리마다 throw 와 오류 값을 함께 적는다. 함수 시그니처의 throws 는 이미 붙어 있다.
}

@Hint {
조건이 아닐 때를 걸러내는 guard else 형태를 쓰면 성공 경로가 함수 끝에 자연스럽게 남는다.
}

@Hint {
부족한 금액은 amount - balance 이다. 반대로 빼지 않도록 주의하라.
}
}

@Quiz(id: try-quiz, answer: compile-error) {
@Question {
throws 로 선언된 함수를 try 없이 그냥 호출하면 어떻게 될까?
}

@Choice(id: auto-ignore) {
컴파일되고, 실행 중 오류가 던져지면 자동으로 무시된다.
}

@Choice(id: compile-error) {
컴파일 오류가 난다 — 오류를 던질 수 있는 호출은 try 로 표시해야 한다.
}

@Choice(id: runtime-crash) {
컴파일은 되지만, 실행 중 오류가 던져지는 순간 프로그램이 강제로 종료된다.
}

@Choice(id: becomes-optional) {
오류가 nil 로 바뀌어 호출 결과가 옵셔널이 된다.
}

@Explanation {
Swift 는 실패 가능한 호출을 try 로 표시하도록 강제한다. try 없이 throws 함수를 호출하면 컴파일 단계에서 거부되고, 개발자는 do-catch 로 잡거나 try? / try! 중 하나를 명시적으로 골라야 한다. 실행 시점까지 미루어지는 다른 언어와 달리 Swift 는 실패 가능성을 컴파일 타임에 드러낸다.
}
}

@Reflection(id: error-reflection) {
@Prompt(id: enum-error-benefit) {
오류를 문자열이 아닌 Error 프로토콜을 채택한 열거형으로 표현하면 호출하는 쪽에서 어떤 이득이 있을까?
}

@Prompt(id: throws-signature) {
throws 가 함수 시그니처에 붙어 있으면, 그 함수를 호출하려던 코드를 읽는 사람은 무엇을 즉시 알 수 있을까?
}

@Prompt(id: catch-pattern) {
catch 절에 패턴을 적는 것과 패턴 없이 catch 만 쓰는 것의 차이는 무엇이고, 각각 언제 쓰면 좋을까?
}
}
