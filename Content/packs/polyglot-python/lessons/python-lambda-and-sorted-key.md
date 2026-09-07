@Concept(id: lambda-sorted-key-concept) {
리스트를 정렬할 때는 **sorted()** 함수를 쓴다. sorted()는 원본 리스트를 건드리지 않고 정렬된 **새 리스트**를 돌려준다. 반면 **list.sort()** 메서드는 원본 리스트 자체를 제자리에서 바꾼다. 두 방법 모두 reverse=True를 넘기면 내림차순으로 정렬한다.그런데 정렬 기준을 내가 정하고 싶을 때가 많다. 이때 쓰는 것이 **key 인자**다. key에는 '각 원소를 이 값으로 바꿔서 비교하라'는 함수를 넣는다. 예를 들어 key=len을 넘기면 각 문자열의 길이를 기준으로 정렬한다.기준 함수를 매번 def로 정의하기는 번거롭다. **lambda**는 이름 없는 한 줄짜리 함수를 그 자리에서 만드는 문법이다. lambda 매개변수: 표현식 형태로 쓰고, return문 없이 표현식의 결과가 그대로 반환된다. sorted(학생들, key=lambda s: s['score'])처럼 lambda를 key에 바로 넣으면, 점수·이름·글자 수 등 원하는 기준대로 정렬할 수 있다.
}

@Example(id: lambda-sorted-key-example, language: python, expected: expected/python-lambda-and-sorted-key.txt) {
점수가 담긴 튜플 리스트를 점수 내림차순으로 정렬하고, 이름들을 글자 수 기준으로 정렬해 본다.

```python
students = [("민수", 82), ("지우", 95), ("하늘", 88)]

by_score = sorted(students, key=lambda s: s[1], reverse=True)
for name, score in by_score:
    print(f"{name}: {score}")

names = ["김철수", "이", "박영희", "철수"]
print(sorted(names, key=len))
```
}

@Blank(id: lambda-sorted-key-blank, language: python) {
lambda를 key에 넣어 단어를 길이 기준 오름차순으로 정렬해 본다.

```python
words = ["banana", "kiwi", "apple", "fig"]
shortest = ___1___(words, ___2___=lambda w: ___3___)
print(shortest)
```

@Answer(slot: 1) {
`sorted`
}

@Answer(slot: 2) {
`key`
}

@Answer(slot: 3) {
`len(w)`
}
}

@Task(id: lambda-sorted-key-task, language: python, starter: starters/python-lambda-and-sorted-key.py, tests: tests/python-lambda-and-sorted-key.py, solution: solutions/python-lambda-and-sorted-key.py) {
학생 딕셔너리 리스트를 받아 정렬하는 함수 sort_students를 완성하라. 각 딕셔너리는 'name'과 'score' 키를 가진다. 결과는 점수 내림차순이고, 점수가 같으면 이름 오름차순이어야 한다. 원본 리스트는 바꾸지 말고 새 리스트를 반환해야 한다.

@Hint {
sorted()의 key에는 각 학생 딕셔너리에서 비교에 쓸 값을 꺼내는 lambda를 넣는다.
}

@Hint {
내림차순과 오름차순을 섞으려면 reverse=True 대신 점수를 음수로 바꿔 튜플 (-score, name)을 기준으로 삼는 방법이 있다. 튜플은 앞 원소부터 차례로 비교된다.
}

@Hint {
sorted()는 항상 새 리스트를 반환하므로 원본은 그대로 유지된다.
}
}

@Quiz(id: lambda-sorted-key-quiz, answer: last-char) {
@Question {
words = ["apple", "kiwi", "fig"] 일 때 sorted(words, key=lambda w: w[-1]) 의 결과는 무엇인가?
}

@Choice(id: last-char) {
각 단어의 마지막 글자를 기준으로 정렬한 ['fig', 'apple', 'kiwi']
}

@Choice(id: length) {
단어의 길이를 기준으로 정렬한 ['fig', 'kiwi', 'apple']
}

@Choice(id: reverse-alpha) {
단어를 내림차순으로 정렬한 ['kiwi', 'fig', 'apple']
}

@Explanation {
lambda w: w[-1]은 각 단어의 마지막 글자를 반환한다. apple→e, kiwi→i, fig→g 이므로 이 글자들을 오름차순(e, g, i)으로 비교해 fig, apple, kiwi 순이 된다. 길이 기준은 key=len이었을 것이고, 내림차순은 reverse=True가 필요하다.
}
}

@Reflection(id: lambda-sorted-key-reflection) {
@Prompt(id: sort-vs-sorted) {
원본 리스트가 바뀌어도 상관없는 상황과 원본을 반드시 지켜야 하는 상황의 예를 하나씩 떠올려 보고, 각각 sort()와 sorted() 중 무엇을 쓰겠는지 설명해 보라.
}

@Prompt(id: key-tuple) {
과제에서 점수 내림차순과 이름 오름차순을 한 번에 처리하기 위해 튜플 (-score, name)을 key로 썼다. 내가 원하는 다른 복합 기준(예: 나이 내림차순, 같으면 가입일 오름차순)이라면 key를 어떻게 만들겠는지 말해 보라.
}

@Prompt(id: lambda-vs-def) {
lambda는 언제 편하고, 언제는 오히려 def로 이름 붙인 함수가 더 읽기 좋을까? 본인의 기준을 정해 보라.
}
}
