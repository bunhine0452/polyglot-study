@Concept(id: word-analyzer-capstone) {
이 레슨은 지금까지 배운 재료를 하나의 프로그램으로 조립하는 마무리 단계다. 텍스트 분석기의 뼈대는 세 단계로 나뉜다. 첫째, 문자열의 split() 으로 문장을 단어 리스트로 쪼개고 dict.get(word, 0) + 1 패턴으로 개수를 센다. 둘째, sorted() 의 key 인자에 람다를 넣어 개수 기준으로 내림차순 정렬한다. 이때 key=lambda item: (-item[1], item[0]) 처럼 튜플을 쓰면 개수가 같은 항목을 단어 이름 순으로 매길 수 있다. 셋째, 슬라이싱으로 상위 몇 개만 골라 파일에 쓰거나 화면에 출력한다. 프로그램이 커지면 이 흐름을 함수 하나씩으로 나눠 쓰는 습관이 중요하다. 각 함수가 입력과 반환값만 명확하면 나중에 테스트하기도, 고치기도 쉬워진다.
}

@Example(id: word-analyzer-example, language: python, expected: expected/python-text-analysis-capstone.txt) {
아래 예제는 세 단계를 순서대로 실행해 상위 단어를 파일에 저장하고 다시 읽어 출력한다.

```python
text = "banana apple banana cherry apple banana"

# 1단계: 단어별 개수 세기
counts = {}
for word in text.split():
    counts[word] = counts.get(word, 0) + 1

# 2단계: 개수 내림차순, 같으면 단어 오름차순으로 정렬
ranked = sorted(counts.items(), key=lambda item: (-item[1], item[0]))

# 3단계: 상위 2개를 파일에 저장
top = ranked[:2]
with open("report.txt", "w", encoding="utf-8") as f:
    for word, cnt in top:
        f.write(f"{word}: {cnt}\n")

# 저장된 결과를 다시 읽어 확인
with open("report.txt", "r", encoding="utf-8") as f:
    print(f.read(), end="")
print(f"서로 다른 단어 수: {len(counts)}")
```
}

@Blank(id: word-analyzer-blank, language: python) {
단어별 개수를 세고 개수 기준으로 정렬하는 핵심 코드에서 빠진 조각을 채워라.

```python
text = "banana apple banana cherry apple banana"
counts = {}
for word in text.split():
    counts[___1___] = counts.get(word, 0) + ___2___
ranked = sorted(counts.items(), key=lambda item: (-item[___3___], item[___4___]))
print(ranked[0])
```

@Answer(slot: 1) {
`word`
}

@Answer(slot: 2) {
`1`
}

@Answer(slot: 3) {
`1`
}

@Answer(slot: 4) {
`0`
}
}

@Task(id: word-analyzer-task, language: python, starter: starters/python-text-analysis-capstone.py, tests: tests/python-text-analysis-capstone.py, solution: solutions/python-text-analysis-capstone.py) {
텍스트 분석기의 핵심 함수 analyze_words 를 완성하라. 이 함수는 문자열 text 와 정수 top_n(기본값 3)을 받아 다음 규칙으로 동작해야 한다. 1) 단어는 text.lower().split() 으로 나누고, 대소문자는 구분하지 않는다. 2) 각 단어의 등장 횟수를 딕셔너리로 센다. 3) (단어, 개수) 튜플의 리스트를 개수 내림차순으로 정렬하되, 개수가 같으면 단어 이름 오름차순으로 매긴다. 4) 상위 top_n 개만 슬라이싱해 반환한다. top_n 이 서로 다른 단어 수보다 크면 전체를 반환한다. 빈 문자열이 들어오면 빈 리스트를 반환한다.

@Hint {
text.lower().split() 으로 소문자 단어 리스트를 만든 다음 dict.get(word, 0) + 1 로 개수를 센다.
}

@Hint {
정렬 key 로 튜플을 반환하면 복합 규칙을 한 번에 표현할 수 있다: key=lambda item: (-item[1], item[0]).
}

@Hint {
리스트 슬라이싱 ranked[:top_n] 은 top_n 이 실제 항목 수보다 커도 오류 없이 전체를 반환한다.
}
}

@Quiz(id: word-analyzer-quiz, answer: count-desc-word-asc) {
@Question {
sorted(counts.items(), key=lambda item: (-item[1], item[0])) 에서 key 로 튜플을 반환하는 이유는 무엇인가?
}

@Choice(id: count-desc-word-asc) {
개수가 많은 순서로 정렬하고, 개수가 같으면 단어 이름이 가나다(알파벳) 순으로 앞서는 것을 먼저 둔다.
}

@Choice(id: count-asc-word-asc) {
개수가 적은 순서로 정렬하고, 개수가 같으면 단어 이름 순으로 정렬한다.
}

@Choice(id: error-negative) {
key 안에서 음수를 쓸 수 없어서 이 코드는 sorted() 를 호출할 때 오류가 난다.
}

@Choice(id: count-only-desc) {
개수 기준으로만 내림차순 정렬하며, 단어 이름은 결과 순서에 아무 영향이 없다.
}

@Explanation {
튜플로 key 를 만들면 첫 원소인 -개수로 내림차순(음수화했으므로 오름차순 정렬이 내림차순이 됨)을 적용하고, 개수가 같은 항목끼리는 두 번째 원소인 단어 이름 오름차순으로 순서가 갈린다. 음수는 정렬 key 로 쓰는 흔하고 올바른 기법이며, 정렬 규칙이 하나가 아니라 두 겹임을 표현하는 방법이다.
}
}

@Reflection(id: word-analyzer-reflection) {
@Prompt(id: prompt-step-split) {
이번 분석기를 세 함수로 나눴는데, 만약 대소문자 무시 대신 구두점 제거 규칙이 추가된다면 어느 함수만 고치면 되는지, 그렇게 나눈 덕에 무엇이 편해지는지 설명해 보라.
}

@Prompt(id: prompt-tie-rule) {
개수가 같은 단어의 순서를 매기는 규칙으로 단어 이름 순 대신 다른 기준을 쓴다면 어떤 기준이 사용자에게 더 유용할지, 실제 단어 빈도 프로그램의 관점에서 생각해 보라.
}

@Prompt(id: prompt-scale) {
파일이 수백 메가바이트로 아주 커진다면 지금 구현의 어느 부분이 병목이 될 것 같은지, 배운 자료구조 중 무엇으로 개선해 볼 수 있을지 적어 보라.
}
}
