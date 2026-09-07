@Concept(id: class-basics) {
지금까지 우리는 리스트, 딕셔너리처럼 파이썬이 미리 만들어 둔 자료형을 써 왔다. class는 이런 자료형을 내 입맛대로 새로 만드는 설계도다. 설계도 자체는 데이터가 아니고, class를 호출하면 그 설계도대로 찍어낸 실체, 즉 인스턴스(instance)가 만들어진다. 예를 들어 class Dog는 설계도이고, Dog("초코")로 만든 객체는 이름이 초코인 실제 강아지 데이터다. __init__은 인스턴스가 만들어지는 순간 자동으로 실행되는 초기화 메서드로, 여기서 self.속성 = 값 형태로 인스턴스마다 고유한 속성을 설정한다. self는 메서드 안에서 지금 동작 중인 그 인스턴스 자신을 가리킨다. c.up()처럼 메서드를 호출하면 파이썬이 알아서 c를 self로 넘겨주기 때문에, 우리는 인자를 따로 쓰지 않아도 된다. 덕분에 하나의 class 정의로 서로 다른 상태를 가진 여러 인스턴스를 만들 수 있다.
}

@Example(id: dog-example, language: python, expected: expected/python-classes-and-objects.txt) {
강아지 class를 만들고, 두 마리의 인스턴스가 서로 다른 상태를 유지하는 모습을 실행해 보자.

```python
class Dog:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def bark(self):
        return f"{self.name}가 짖는다!"

    def have_birthday(self):
        self.age = self.age + 1

dog1 = Dog("초코", 3)
dog2 = Dog("라떼", 5)

print(dog1.name)
print(dog2.name)
print(dog1.bark())

dog1.have_birthday()
print(dog1.age)
print(dog2.age)
```
}

@Blank(id: counter-blank, language: python) {
호출 횟수를 세는 Counter class다. 초기화 메서드 이름과, 인스턴스 자신을 가리키는 이름을 채워 넣어라.

```python
class Counter:
    def ___1___(self):
        ___2___.count = 0

    def up(self):
        self.count = self.count + 1

c = Counter()
c.up()
c.up()
print(f"count={c.count}")
```

@Answer(slot: 1) {
`__init__`
}

@Answer(slot: 2) {
`self`
}
}

@Task(id: bank-account-task, language: python, starter: starters/python-classes-and-objects.py, tests: tests/python-classes-and-objects.py, solution: solutions/python-classes-and-objects.py) {
BankAccount class를 완성하라. __init__은 소유자 이름 owner와 시작 잔액 balance(기본값 0)를 받아 속성으로 저장한다. deposit(amount)는 잔액을 amount만큼 늘리고 True를 반환한다. withdraw(amount)는 잔액이 amount보다 적으면 아무것도 바꾸지 않고 False를 반환하고, 충분하면 잔액을 줄이고 True를 반환한다.

@Hint {
메서드 안에서 잔액에 접근할 때는 self.balance를 쓴다.
}

@Hint {
withdraw에서는 잔액을 줄이기 전에 먼저 부족한지 비교해야 한다.
}

@Hint {
deposit은 조건 없이 잔액을 늘리고 True를 반환하면 된다.
}
}

@Quiz(id: self-quiz, answer: instance-itself) {
@Question {
메서드 정의에서 첫 번째 매개변수로 쓰는 self는 무엇을 가리키는가?
}

@Choice(id: instance-itself) {
그 메서드를 호출한 인스턴스 자신 — acc.deposit(500)처럼 호출하면 acc가 self로 전달된다.
}

@Choice(id: the-class) {
메서드가 정의된 class 그 자체를 가리키는 이름이다.
}

@Choice(id: keyword-argument) {
메서드를 호출할 때 반드시 직접 넣어야 하는 필수 인자다.
}

@Explanation {
self는 메서드를 호출한 인스턴스 자신이다. acc.deposit(500)이라고 쓰면 파이썬이 알아서 acc를 self로 넘겨주므로 호출할 때 직접 쓰는 인자가 아니다. class는 설계도일 뿐이고, self 덕분에 각 인스턴스는 자기만의 속성값을 읽고 바꿀 수 있다.
}
}

@Reflection(id: class-reflection) {
@Prompt(id: class-vs-instance) {
class와 인스턴스의 차이를, 설계도와 실물에 빗대어 자기 말로 설명해 보자. Dog라는 class에서 몇 개의 인스턴스를 만들 수 있을까?
}

@Prompt(id: why-self) {
같은 BankAccount class로 만든 두 계좌가 서로 다른 잔액을 유지할 수 있는 이유는 무엇일까? self와 어떤 관계가 있는지 생각해 보자.
}

@Prompt(id: method-choice) {
지금까지 만든 함수들 중 하나를 골라, 상태를 가진 class의 메서드로 바꾸면 어떤 점이 나아질지 상상해 보자.
}
}
