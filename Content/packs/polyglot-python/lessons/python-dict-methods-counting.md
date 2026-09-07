@Concept(id: dict-get-items-counting-concept) {
딕셔너리에서 존재하지 않는 키를 대괄호로 꺼내면 KeyError가 나지만, get()은 키가 없을 때 정해준 기본값을 돌려준다. items()는 키와 값이 짝지어진 쌍을 하나씩 돌려주므로 for 문에서 튜플 언패킹으로 두 값을 동시에 받아 순회할 수 있다. setdefault()는 키가 없으면 기본값을 저장하고 그 값을 돌려주므로, 새 키를 처음 만나는 상황을 자연스럽게 처리한다. 이 세 가지를 조합하면 반복을 돌며 같은 값이 몇 번 나왔는지 세는 코드를 짧고 안전하게 작성할 수 있다.
}

@Example(id: dict-get-items-counting-example, language: python, expected: expected/python-dict-methods-counting.txt) {
아래 예제는 get()으로 없는 키를 안전하게 꺼내고, items()로 키와 값을 함께 출력하며, 반복을 돌아 과일 개수를 세는 과정을 보여준다.

```python
scores = {"철수": 90, "영희": 85}

# 없는 키를 대괄호로 꺼내면 KeyError지만, get은 기본값을 돌려준다
print(scores.get("민수", 0))
print(scores.get("철수", 0))

# items()로 키와 값을 동시에 순회한다
for name, score in scores.items():
    print(f"{name}: {score}")

# setdefault(): 키가 없으면 기본값을 저장하고 그 값을 돌려준다
stock = {"사과": 3}
stock.setdefault("배", 0)
print(stock)

# 반복을 돌며 개수 세기
words = ["사과", "배", "사과", "포도", "배", "사과"]
counts = {}
for w in words:
    counts[w] = counts.get(w, 0) + 1
print(counts)
```
}

@Blank(id: dict-get-items-counting-blank, language: python) {
리스트에 담긴 과일 이름이 각각 몇 번 나왔는지 세어 출력하는 코드다. 빈칸을 채워 완성하라.

```python
fruits = ["사과", "배", "사과", "포도"]
counts = {}
for f in fruits:
    counts[f] = counts.___1___(f, 0) + ___2___
for name, num in counts.___3___():
    print(f"{name}: {num}")
```

@Answer(slot: 1) {
`get`
}

@Answer(slot: 2) {
`1`
}

@Answer(slot: 3) {
`items`
}
}

@Task(id: dict-get-items-counting-task, language: python, starter: starters/python-dict-methods-counting.py, tests: tests/python-dict-methods-counting.py, solution: solutions/python-dict-methods-counting.py) {
count_elements(items) 함수를 완성하라. items는 해시 가능한 값들이 담긴 리스트이고, 각 값이 몇 번 나왔는지를 키와 값으로 담은 딕셔너리를 돌려야 한다. 빈 리스트를 받으면 빈 딕셔너리를 돌려야 하고, 딕셔너리에 키가 처음 등장할 때도 오류 없이 처리해야 한다. counts.get(값, 0) 또는 counts.setdefault(값, 0)을 활용하라.

@Hint {
빈 딕셔너리 counts = {} 로 시작해서 리스트를 for 문으로 순회하세요.
}

@Hint {
counts.get(item, 0)은 item이 아직 딕셔너리에 없어도 0을 돌려주므로, 여기에 1을 더해 저장하면 개수 세기가 됩니다.
}

@Hint {
마지막에 counts를 return 하는 것을 잊지 마세요.
}
}

@Quiz(id: dict-get-items-counting-quiz, answer: returns-default-safely) {
@Question {
scores = {"철수": 90} 일 때, scores.get("민수", 0) 을 실행하면 어떤 일이 일어나는가?
}

@Choice(id: returns-default-safely) {
"민수"라는 키가 없으므로 KeyError 대신 기본값 0을 돌려준다.
}

@Choice(id: raises-keyerror) {
키가 없으므로 get()도 KeyError를 일으켜 프로그램이 멈춘다.
}

@Choice(id: adds-key-with-default) {
0을 돌려줄 뿐 아니라 scores에 "민수": 0 키-값 쌍을 새로 저장한다.
}

@Explanation {
get()은 키가 없을 때 지정한 기본값을 그냥 돌려줄 뿐, 딕셔너리를 바꾸지도 않고 오류를 일으키지도 않는다. 반면 대괄호로 scores["민수"] 를 꺼내면 KeyError가 나고, 새 키까지 저장하려면 setdefault()를 써야 한다.
}
}

@Reflection(id: dict-get-items-counting-reflection) {
@Prompt(id: get-vs-bracket) {
대괄호로 직접 꺼내는 것과 get()으로 꺼내는 것 중, 어떤 상황에서는 오히려 대괄호 쪽이 더 나은 선택일까요? 이유를 생각해 보세요.
}

@Prompt(id: counting-elsewhere) {
일상 속에서 무언가의 개수를 세는 일을 예로 들고, 그것을 딕셔너리로 어떻게 표현할 수 있을지 설명해 보세요.
}

@Prompt(id: get-vs-setdefault) {
get()과 setdefault()는 키가 없을 때 기본값을 다룬다는 점에서 비슷해 보입니다. 두 메서드의 차이는 무엇이고, 각각 언제 쓰면 좋을까요?
}
}
