@Concept(id: nested-data-concept) {
리스트와 딕셔너리는 그 안에 또 다른 리스트나 딕셔너리를 담을 수 있습니다. 리스트 안의 리스트는 이중 인덱스 matrix[1][2]처럼 바깥부터 차례로 꺼내어 접근합니다. 딕셔너리의 리스트는 학생 명단처럼 같은 모양의 데이터를 여러 개 담을 때 자주 쓰이며, for 반복으로 각 딕셔너리를 하나씩 꺼내 f-string으로 출력할 수 있습니다. 반대로 딕셔너리의 값이 리스트라면, menu["items"].append()처럼 그 리스트에 직접 값을 추가할 수도 있습니다.
}

@Example(id: nested-data-example, language: python, expected: expected/python-nested-data-structures.txt) {
구구단 표 같은 이중 리스트와 학생 명단인 딕셔너리의 리스트를 출력하고, 딕셔너리 안의 리스트에 값을 추가해 봅니다.

```python
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
print(matrix[1][2])

students = [
    {"name": "민수", "scores": [90, 85]},
    {"name": "지영", "scores": [78, 92]},
]
for s in students:
    print(f"{s['name']}: {sum(s['scores'])}점")

classroom = {"room": 2, "members": ["민수", "지영"]}
classroom["members"].append("도윤")
print(classroom["members"])
```
}

@Blank(id: nested-data-blank, language: python) {
이중 인덱스로 행렬의 값을 꺼내고, 딕셔너리 안의 리스트에 새 점수를 추가해 보세요.

```python
matrix = [[10, 20], [30, 40]]
print(matrix[1][___1___])

students = [{"name": "철수", "scores": [80, 90]}]
students[___2___]["scores"].___3___(95)
print(students[0]["scores"])
```

@Answer(slot: 1) {
`0`
}

@Answer(slot: 2) {
`0`
}

@Answer(slot: 3) {
`append`
}
}

@Task(id: nested-data-task, language: python, starter: starters/python-nested-data-structures.py, tests: tests/python-nested-data-structures.py, solution: solutions/python-nested-data-structures.py) {
학생 명단 students는 딕셔너리의 리스트이고, 각 딕셔너리는 "name" 키와 "scores" 키를 가집니다. scores는 점수(정수)의 리스트입니다. 함수 total_scores(students)는 명단에 있는 모든 학생의 점수를 전부 더해 반환해야 합니다. 명단이 비어 있으면 0을 반환하고, 어떤 학생의 scores가 빈 리스트일 수도 있습니다.

@Hint {
바깥 for 반복으로 students에서 딕셔너리를 하나씩 꺼냅니다.
}

@Hint {
꺼낸 딕셔너리에서 student["scores"]로 리스트를 가져온 뒤, 안쪽 for 반복으로 점수를 하나씩 더합니다.
}

@Hint {
합계를 담을 변수는 반복이 시작되기 전에 0으로 초기화해야 합니다.
}
}

@Quiz(id: nested-data-quiz, answer: picks-b) {
@Question {
다음 코드를 실행했을 때 출력으로 올바른 것은 무엇입니까?

matrix = [["a", "b"], ["c", "d"]]
print(matrix[0][1])
}

@Choice(id: picks-a) {
a
}

@Choice(id: picks-b) {
b
}

@Choice(id: picks-d) {
d
}

@Choice(id: raises-error) {
IndexError가 발생한다
}

@Explanation {
matrix[0]은 바깥 리스트의 0번 요소인 ["a", "b"]이고, 여기에 [1]을 붙이면 그 안의 1번 요소인 "b"가 됩니다. matrix[1][0]이었으면 "c", matrix[1][1]이었으면 "d"가 나왔을 것입니다.
}
}

@Reflection(id: nested-data-reflection) {
@Prompt(id: prompt-access-order) {
matrix[1][2]에서 첫 번째 인덱스와 두 번째 인덱스는 각각 무엇을 가리키는지, 자기만의 예시를 들어 설명해 보세요.
}

@Prompt(id: prompt-when-to-use) {
딕셔너리의 리스트와 리스트 안의 딕셔너리 아닌 이중 리스트 중, 여러 학생의 이름과 점수를 담을 때 어떤 쪽이 더 읽기 쉬운지 이유와 함께 생각해 보세요.
}

@Prompt(id: prompt-append-chain) {
classroom["members"].append("도윤")처럼 점 두 개를 이어 쓸 수 있는 이유는 무엇일지 추측해 보세요.
}
}
