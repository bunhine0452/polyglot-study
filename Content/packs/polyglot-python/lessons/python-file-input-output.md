@Concept(id: concept-01) {
프로그램이 계산한 값은 변수에 담긴다. 그런데 변수는 프로그램이 끝나는 순간 함께 사라진다. 같은 프로그램을 다시 실행하면 어제 저장해 둔 값이 아니라 언제나 처음부터 다시 시작한다. 프로그램이 꺼진 뒤에도 남아 있어야 하는 데이터, 예를 들어 할 일 목록이나 사용자가 입력한 메모는 변수가 아니라 파일에 기록해야 한다.

파일을 다루려면 먼저 열어야 한다. `open(파일이름, 모드)` 함수는 파일을 열어 파일 객체를 돌려준다. 모드 `"w"`는 쓰기 모드다. 파일이 없으면 새로 만들고, 이미 있으면 기존 내용을 모두 지우고 처음부터 다시 쓴다. 모드 `"r"`은 읽기 모드로, 저장된 내용을 읽어 올 때 쓴다. 존재하지 않는 파일을 읽기 모드로 열려고 하면 `FileNotFoundError`가 난다. 앞 레슨에서 배운 `try`와 `except`로 이 오류를 잡을 수 있다.

파일은 열면 반드시 닫아야 한다. 이 규칙을 사람 대신 지켜 주는 것이 `with` 블록이다. `with open(...) as f:` 형태로 쓰면 블록 안에서는 파일 객체를 `f`라는 이름으로 사용하고, 블록이 끝나는 순간 실행 중에 오류가 나더라도 파일이 자동으로 닫힌다. 닫는 것을 깜빡해서 파일이 잠기거나 데이터가 유실되는 일을 막아 주므로, 파일을 다룰 때는 항상 `with` 블록을 쓰는 습관을 들이는 것이 좋다.

쓰기에는 `write()`를 쓴다. `write()`는 문자열 하나를 인자로 받아 파일에 그대로 기록하는데, 줄바꿈을 자동으로 넣어 주지 않는다. 줄을 바꾸고 싶으면 문자열 끝에 직접 `"\n"`을 붙여야 한다. 이 점이 출력마다 줄바꿈을 넣어 주는 `print()`와 다르다.

읽기에는 `read()`를 쓴다. `read()`는 파일의 전체 내용을 줄바꿈 문자까지 포함해 문자열 하나로 돌려준다. 이 문자열을 `print()`로 출력하면 여러 줄처럼 보이지만, 실체는 줄바꿈 문자가 섞인 문자열 하나다. `read` 뒤에 괄호를 붙여 호출해야 결과가 돌아온다는 점도 잊지 말라. 괄호를 빼면 함수 그 자체를 가져올 뿐 파일 내용은 읽히지 않는다.

`splitlines()`는 이 문자열을 줄바꿈 문자를 기준으로 잘라 줄 단위 리스트로 만들어 준다. 잘라 낸 각 원소에는 줄바꿈 문자가 남지 않는다. 덕분에 파일 끝이 줄바꿈으로 끝나더라도 마지막에 빈 문자열이 끼어 있지 않다. 파일을 읽어 와서 줄별로 처리할 때는 `read()`로 전체를 읽은 다음 `splitlines()`로 나누는 흐름이 기본형이다.
}

@Example(id: example-01, language: python, expected: expected/python-file-input-output.txt) {
메모 세 줄을 파일에 쓰고, 같은 파일을 다시 열어 내용을 읽어 온다. `read()`가 돌려준 문자열을 그대로 출력하면 어떤 모습인지, `splitlines()`로 나누면 어떻게 달라지는지 출력으로 확인한다.

```python
memo_path = "memo.txt"

with open(memo_path, "w", encoding="utf-8") as f:
    f.write("아침: 물 한 잔\n")
    f.write("점심: 산책\n")
    f.write("저녁: 독서")

with open(memo_path, "r", encoding="utf-8") as f:
    content = f.read()

print(f"파일 전체 내용: {content}")
print(f"글자 수: {len(content)}")

lines = content.splitlines()
print(f"줄 개수: {len(lines)}")
for i in range(len(lines)):
    print(f"{i + 1}번째 줄: {lines[i]}")
```
}

@Blank(id: blank-01, language: python) {
할 일 두 줄을 파일에 기록하고, 같은 파일을 다시 열어 읽어 오는 코드다. 빈칸에 알맞은 코드를 채워라. 다 채워 넣고 실행하면 `할 일 개수: 2`와 첫 번째 할 일이 차례로 출력된다.

```python
path = "todo.txt"

with ___1___(path, ___2___, encoding="utf-8") as f:
    f.write("쓰레기 버리기\n")
    f.write("방 청소\n")

with open(path, "r", encoding="utf-8") as f:
    content = f.___3___()

todo = content.___4___
print(f"할 일 개수: {len(todo)}")
print(todo[0])
```

@Answer(slot: 1) {
`open`
}

@Answer(slot: 2) {
`"w"`
}

@Answer(slot: 3) {
`read`
}

@Answer(slot: 4) {
`splitlines()`
}
}

@Task(id: task-01, language: python, starter: starters/python-file-input-output.py, tests: tests/python-file-input-output.py, solution: solutions/python-file-input-output.py) {
함수 `save_and_load(lines, filename)`를 완성하라. `lines`는 문자열들의 리스트다. 각 문자열을 한 줄로 해서 `filename` 파일에 저장한 뒤, 같은 파일을 다시 열어 읽어 들이고 줄 단위 리스트로 돌려줘야 한다. 파일에는 줄 사이에만 줄바꿈을 넣고 마지막 줄 끝에는 줄바꿈을 넣지 않는다. `lines`가 빈 리스트이면 빈 파일을 만들고 빈 리스트를 돌려준다.

@Hint {
저장할 때는 open()과 with 블록으로 filename을 "w" 모드로 열고, "\n".join(lines)의 결과를 write()로 기록한다.
}

@Hint {
읽어 올 때는 같은 파일을 "r" 모드로 다시 열어 read()로 전체 내용을 문자열로 받는다.
}

@Hint {
받은 문자열에 splitlines()를 적용하면 줄 단위 리스트가 되고, 이것을 return 한다.
}
}

@Quiz(id: quiz-01, answer: B) {
@Question {
파일을 열 때 `with` 블록을 쓰는 이유로 알맞은 것은?
}

@Choice(id: A) {
with 블록 안에서는 write()만 쓸 수 있고 read()는 쓸 수 없다
}

@Choice(id: B) {
with 블록이 끝나는 순간 파일이 오류가 나도 자동으로 닫힌다
}

@Choice(id: C) {
with 블록 안의 코드는 블록이 끝날 때 여러 번 반복 실행된다
}

@Choice(id: D) {
with 블록을 쓰면 write()가 줄 끝에 자동으로 줄바꿈을 붙여 준다
}

@Explanation {
`with` 블록의 역할은 파일을 확실히 닫아 주는 것이다. 쓰기와 읽기는 모드 선택에 따라 블록 안에서 둘 다 가능하고, 반복과 무관하며, 줄바꿈은 여전히 직접 "\n"으로 넣어야 한다.
}
}

@Reflection(id: reflection-01) {
@Prompt(id: prompt-01) {
여러분이 만들고 싶은 프로그램 하나를 정하고, 그 프로그램이 꺼진 뒤에도 남아 있어야 하는 데이터를 한 가지 골라 적어 보세요.

그 데이터를 파일에 저장한다면 어떤 줄들로 기록할지 줄 예시를 두세 개 직접 만들어 적어 보세요. 각 줄의 끝에는 write()가 자동으로 줄바꿈을 넣어 주지 않는다는 점도 함께 생각해 보세요.
}

@Prompt(id: prompt-02) {
지금까지 배운 개념 중에서 파일 입출력과 결합하면 쓸모가 커질 것 같은 것은 무엇인가요? 예를 들어 반복, 조건문, 리스트와 파일 읽기·쓰기를 어떻게 엮을 수 있을지 한 문장으로 적어 보세요.
}
}
