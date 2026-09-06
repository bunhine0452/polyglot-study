@Concept(id: concept-dict) {
딕셔너리는 값마다 이름표를 붙여 보관하는 자료형이다. 리스트가 "첫 번째, 두 번째"처럼 번호로 값을 찾는다면, 딕셔너리는 "수학, 영어"처럼 의미 있는 키로 값을 찾는다. 중괄호 안에 키: 값 쌍을 쉼표로 나열해서 만든다. 예를 들어 scores = {"수학": 92, "영어": 87} 처럼 쓰면, 과목 이름이 키이고 점수가 값이다.

값을 읽을 때는 대괄호 안에 키를 넣는다. scores["수학"]처럼 쓰면 92가 나온다. 리스트의 인덱스 접근과 모양이 똑같아 보이지만 의미가 다르다. 리스트의 대괄호 안에 들어가는 것은 위치를 뜻하는 번호 0, 1, 2뿐이고, 딕셔너리의 대괄호 안에는 값의 이름인 키가 들어간다. 그래서 week = ["월", "화", "수"]에서 week[1]이 "화"인 것은 "화요일"이라는 뜻이 아니라 두 번째 칸이라는 뜻이지만, scores["수학"]은 이름 그대로 수학 점수를 꺼낸다.

없는 키로 대괄호 접근을 하면 KeyError라는 오류가 나면서 프로그램이 멈춘다. 예를 들어 prices에 "cake"라는 키가 없는 상태에서 prices["cake"]를 쓰면 KeyError다. 같은 상황에서 get()은 조용히 처리해 준다. 키가 없으면 None을 돌려주고, 둘째 인자로 기본값을 넘기면 그 기본값을 돌려준다. prices.get("cake", 0)은 키가 없어도 0을 돌려주므로, 없어도 되는 값에 대한 안전장치로 쓰기 좋다.

새 키-값 쌍을 추가하는 방법은 값을 읽는 방법과 같은 모양인데 대입만 하면 된다. prices["juice"] = 5200을 쓰면 "juice"라는 새 키가 생기고, 이미 있는 키에 대입하면 그 키의 값이 덮어써진다. 특정 키가 들어 있는지 검사할 때는 in을 쓴다. "latte" in prices는 키가 있으면 True, 없으면 False인 불값을 돌려준다.

딕셔너리의 모든 키-값 쌍을 하나씩 꺼내 처리할 때는 items()를 쓴다. for name, price in prices.items(): 처럼 쓰면 한 바퀴마다 키와 값이 두 변수에 나뉘어 들어간다. 리스트를 for로 순회하던 것과 같은데, 쌍으로 꺼낸다는 점만 다르다.
}

@Example(id: example-dict-basics, language: python, expected: expected/python-dictionaries.txt) {
리스트의 인덱스 접근과 딕셔너리의 키 접근을 나란히 실행해 보고, 새 키 추가와 get()의 기본값, items() 순회도 확인해 보세요.

```python
week = ["월", "화", "수"]
print(week[1])

scores = {"수학": 92, "영어": 87}
print(scores["수학"])

prices = {"americano": 4100, "latte": 4600}
print(prices["latte"])

prices["juice"] = 5200
print(prices)

print(prices.get("cake"))
print(prices.get("cake", 0))

print("latte" in prices, "cake" in prices)

total = 0
for name, price in prices.items():
    print(name, price)
    total += price

print(f"합계: {total}")
```
}

@Blank(id: blank-dict-basics, language: python) {
재고 프로그램의 빈칸을 채워 완성해 보세요. 없는 키를 안전하게 꺼내고, 키가 있는지 검사하고, 모든 키-값 쌍을 순회하는 세 가지가 빠져 있습니다.

```python
stock = {"pen": 12, "note": 30}

print(stock["pen"])

stock["eraser"] = 5

print(stock.get("ruler", ___1___))

print("pen" ___2___ stock)

for item, count in stock.___3___():
    print(f"{item}: {count}")
```

@Answer(slot: 1) {
`0`
}

@Answer(slot: 2) {
`in`
}

@Answer(slot: 3) {
`items`
}
}

@Task(id: task-total-price, language: python, starter: starters/python-dictionaries.py, tests: tests/python-dictionaries.py, solution: solutions/python-dictionaries.py) {
주문 목록 order(항목 이름 리스트)와 가격표 prices(딕셔너리)를 받아 총액을 계산하는 total_price 함수를 완성하세요. prices에 없는 항목의 가격은 0으로 칩니다. 예를 들어 order가 ["latte", "latte"]이고 prices가 {"latte": 4600}이면 9200을 반환해야 하고, prices에 없는 "cake"가 주문에 섞여 있어도 그 항목은 0원으로 더합니다. 빈 주문의 총액은 0입니다.

@Hint {
dict.get(키, 기본값)을 쓰면 prices에 없는 항목 때문에 KeyError가 나는 것을 막을 수 있습니다.
}

@Hint {
주문 목록을 for문으로 한 항목씩 돌면서 가격을 total에 더하세요.
}
}

@Quiz(id: quiz-dict-get-vs-bracket, answer: c) {
@Question {
d = {"a": 1} 이 있을 때 d["b"] 와 d.get("b") 의 차이로 올바른 것은?
}

@Choice(id: a) {
둘 다 KeyError를 일으킨다
}

@Choice(id: b) {
둘 다 None을 반환한다
}

@Choice(id: c) {
d["b"]는 KeyError를 일으키고, d.get("b")는 None을 반환한다
}

@Choice(id: d) {
d["b"]는 None을 반환하고, d.get("b")는 KeyError를 일으킨다
}

@Explanation {
대괄호 접근은 키가 없으면 KeyError로 프로그램을 멈추게 하고, get()은 키가 없으면 기본값 인자를 넘기지 않았을 때 None을 돌려준다. 이 차이가 없는 키를 안전하게 다루는 핵심이다.
}
}

@Reflection(id: reflection-dict-vs-list) {
@Prompt(id: p1) {
리스트는 번호(인덱스)로, 딕셔너리는 이름(키)으로 값을 찾는다. 반 친구 각각의 좋아하는 숫자를 저장해야 한다면 두 자료형 중 무엇을 고를지, 그 이유와 함께 적어 보세요.
}

@Prompt(id: p2) {
그 자료에서 무엇이 키가 되고 무엇이 값이 되는지, 그리고 없는 키를 대괄호로 꺼내면 어떤 일이 벌어질지 자기 말로 정리해 보세요.
}
}
