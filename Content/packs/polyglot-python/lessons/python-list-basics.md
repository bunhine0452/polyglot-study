@Concept(id: list-basics-concept) {
지금까지 우리는 한 변수에 한 값을 담아 왔다. 그런데 점수 목록이나 할 일 목록처럼 성질이 비슷한 값을 여러 개 묶어 다뤄야 할 때가 있다. 변수를 값 개수만큼 따로 만들면 목록이 길어질수록 코드도 같이 길어지고, 개수가 실행 중에 바뀌면 도무지 대응할 수 없다.

리스트는 값을 줄지어 담는 자료형이다. 대괄호 안에 값을 쉼표로 나열해 만들고, 빈 대괄호를 쓰면 비어 있는 리스트도 만들 수 있다. 리스트에 담긴 값 하나하나를 요소라 부른다. 요소는 담긴 순서대로 번호를 받는데, 이 번호를 인덱스라 하고 0부터 센다. 그래서 todo[0] 이 첫 번째 요소이고 todo[1] 이 두 번째 요소다. 인덱스로 요소를 읽을 수 있을 뿐 아니라, todo[1] = "수정" 처럼 대입하면 그 자리의 값을 바꿀 수도 있다.

리스트는 만들고 난 뒤에도 늘었다 줄었다 할 수 있다. append() 는 받은 값을 맨 뒤에 붙인다. pop() 은 맨 뒤의 요소를 리스트에서 떼어 내면서 그 값을 돌려준다. 돌려준 값을 변수에 담아 두면 방금 무엇이 빠졌는지 추적할 수 있다. len() 은 요소 개수를 알려 주고, in 연산자는 어떤 값이 리스트 안에 들어 있는지 검사해 True 나 False 를 내놓는다.

for 문에 리스트를 그대로 주면 요소를 앞에서부터 하나씩 꺼내며 반복한다. range() 반복이 정해진 횟수를 세는 것이었다면, 리스트 순회는 담긴 값 자체를 하나씩 돌려준다는 점이 다르다. 추가와 삭제와 조회를 섞어 쓰면 목록이 지금 어떤 상태인지를 코드로 따라가며 확인할 수 있다. 이번 레슨에서는 예제를 한 줄씩 실행하며 리스트가 어떻게 변하는지 눈으로 추적해 보자.
}

@Example(id: list-basics-example, language: python, expected: expected/python-list-basics.txt) {
할 일 목록을 만들고, 요소를 추가하고, 한 요소를 바꾸고, 하나를 꺼낸 뒤에 남은 목록을 검사한다. print 로 리스트 자체를 찍으면 대괄호와 쉼표로 감싸인 현재 상태가 그대로 출력된다. 각 줄이 실행될 때마다 목록이 어떻게 변하는지 예상해 본 다음 출력과 대조해 보자.

```python
todo = ["쓰기", "읽기"]
print(len(todo))
print(todo[0])

todo.append("검토")
print(todo)

todo[0] = "제출"
print(todo)

picked = todo.pop()
print(picked)
print(todo)

print("읽기" in todo)
print("자기" in todo)

for item in todo:
    print("할 일:", item)
```
}

@Blank(id: list-basics-blank, language: python) {
아래 코드는 빨강과 파랑이 담긴 리스트를 준비한 뒤, 노랑을 맨 뒤에 붙였다가 다시 하나를 꺼내고, 개수와 포함 여부를 확인한다. 빈칸을 채워 이 코드가 2 와 True 를 차례로 출력하도록 만들어 보자.

```python
colors = ["빨강", "파랑"]
colors.___1___("노랑")
last = colors.___2___()
print(len(___3___))
print("파랑" ___4___ colors)
```

@Answer(slot: 1) {
`append`
}

@Answer(slot: 2) {
`pop`
}

@Answer(slot: 3) {
`colors`
}

@Answer(slot: 4) {
`in`
}
}

@Task(id: list-basics-task, language: python, starter: starters/python-list-basics.py, tests: tests/python-list-basics.py, solution: solutions/python-list-basics.py) {
금지어 목록을 통과하는 단어만 모아 새 리스트를 만드는 함수를 완성한다. words 리스트의 요소를 앞에서부터 하나씩 검사해, banned 리스트에 들어 있지 않은 요소만 결과 리스트에 담는다. words 와 banned 를 함부로 바꾸지 말고 새 리스트를 만들어 반환해야 한다.

@Hint {
빈 리스트는 대괄호만으로 만든다.
}

@Hint {
for 문에 words 리스트를 그대로 주면 각 요소를 하나씩 꺼낼 수 있다.
}

@Hint {
banned 에 없는지 검사할 때는 not in 을 쓸 수 있다.
}
}

@Quiz(id: list-basics-quiz, answer: B) {
@Question {
다음 코드를 실행했을 때 화면에 출력되는 것은 무엇일까?
}

@Choice(id: A) {
2 포도
}

@Choice(id: B) {
3 포도
}

@Choice(id: C) {
2 배
}

@Choice(id: D) {
1 포도
}

@Explanation {
append("포도") 직후 fruits 는 요소 셋을 담고, pop() 이 맨 뒤의 포도를 떼어 내면서 그 값을 돌려주므로 fruits 는 요소 둘이 된다. 따라서 len(fruits) 는 2, last 는 포도다.
}
}

@Reflection(id: list-basics-reflection) {
@Prompt(id: list-basics-reflection-1) {
pop() 은 요소를 리스트에서 빼는 동시에 그 값을 돌려준다. 만약 지우기만 하고 값을 버리는 메서드였다면, 처리해야 할 일을 하나씩 꺼내 오는 대기 목록 코드는 어떻게 달라졌을지 상상해 보자. 꺼낸 값을 다른 곳에 써야 하는 상황을 하나 떠올리고, 그 상황에서 pop() 이 값을 돌려주는 점이 어떻게 도움이 되는지 몇 문장으로 써 보자.
}

@Prompt(id: list-basics-reflection-2) {
오늘 배운 리스트 조작 중에서 append() 와 pop() 은 목록을 변화시키고, in 연산자와 len() 은 목록을 변화시키지 않고 들여다보기만 한다. 이 둘을 구분해두면 코드를 읽을 때 어디서 목록이 바뀌는지 쉽게 찾을 수 있다. 네가 예제를 추적하면서 목록의 상태가 바뀌는 순간과 바뀌지 않는 순간을 각각 어떻게 구별했는지 적어 보자.
}
}
