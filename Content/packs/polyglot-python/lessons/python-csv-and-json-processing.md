@Concept(id: csv-json-basics) {
CSV는 값을 쉼표로 구분한 표 형식의 텍스트이고, JSON은 딕셔너리와 리스트 구조를 그대로 텍스트로 옮긴 형식이다. 둘 다 표준 라이브러리 모듈이 있다 — `import csv` 와 `import json` 이다.

`csv.reader()` 는 CSV를 한 줄씩 읽어 각 행을 **문자열 리스트**로 돌려준다. 숫자로 보이는 값도 문자열이다. 반대로 `csv.writer()` 는 리스트 하나를 CSV 한 줄로 써 준다.

`json.dumps()` 는 파이썬 객체를 JSON 문자열로 바꾸고, `json.loads()` 는 그 반대다. `json` 은 CSV와 달리 타입을 기억하므로 `dumps` 로 내보낸 정수는 `loads` 로 읽으면 다시 정수다. 한국어를 그대로 두고 싶으면 `ensure_ascii=False` 를 넘겨라 — 기본값은 `김` 같은 이스케이프로 바꾼다.

실제 파일 대신 `io.StringIO` 를 쓰면 문자열을 파일처럼 다룰 수 있어 연습하기 좋다.
}

@Example(id: csv-json-roundtrip, language: python, expected: expected/python-csv-and-json-processing.txt) {
메모리 속 파일에 CSV를 읽고 쓴 다음, 같은 데이터를 JSON으로 내보냈다가 다시 읽어 온다. 마지막 줄이 무엇을 말하는지 눈여겨보자 — JSON은 타입을 잃지 않는다.

```python
import csv
import io
import json

text = "이름,점수\n김철수,90\n이영희,85"
rows = list(csv.reader(io.StringIO(text)))
print(rows[1][0], rows[1][1])

buf = io.StringIO()
writer = csv.writer(buf)
writer.writerow(["이름", "점수"])
writer.writerow(["박민수", 77])
print(buf.getvalue().strip())

record = {"이름": "김철수", "점수": [90, 85]}
text_out = json.dumps(record, ensure_ascii=False)
print(text_out)

back = json.loads(text_out)
print(back["점수"][0], type(back["점수"][0]).__name__)
```
}

@Blank(id: csv-json-blank, language: python) {
CSV를 행 리스트로 읽고, 딕셔너리를 JSON 문자열로 내보냈다가 다시 읽어 오는 코드를 완성하자.

```python
import csv
import io
import json

text = "name,score\nAmy,90\nBo,85"
rows = ___1___(csv.reader(io.StringIO(text)))
print(rows[1][0])

data = {"names": ["Amy", "Bo"], "count": 2}
line = json.___2___(data)
print(line)

back = json.___3___(line)
print(back["count"] + 1)
```

@Answer(slot: 1) {
`list`
}

@Answer(slot: 2) {
`dumps`
}

@Answer(slot: 3) {
`loads`
}
}

@Task(id: csv-to-json-task, language: python, starter: starters/python-csv-and-json-processing.py, tests: tests/python-csv-and-json-processing.py, solution: solutions/python-csv-and-json-processing.py) {
첫 줄이 헤더인 CSV 문자열을 받아 JSON 문자열로 바꾸는 함수 `csv_to_json(text)` 를 완성하세요. 데이터 행 하나가 딕셔너리 하나가 되고, 헤더의 각 열 이름이 키가 됩니다. 그 딕셔너리들의 리스트를 `json.dumps(..., ensure_ascii=False)` 로 내보내 반환하세요. 값은 `csv.reader` 가 준 문자열 그대로 담습니다. 데이터 행이 하나도 없으면(빈 문자열이거나 헤더만 있으면) `"[]"` 를 반환하세요.

@Hint {
`list(csv.reader(io.StringIO(text)))` 로 감싸면 모든 행이 리스트의 리스트로 나옵니다.
}

@Hint {
`rows[0]` 이 헤더이고 `rows[1:]` 가 데이터 행입니다. 행 하나에서 `header[i]` 를 키로, `row[i]` 를 값으로 넣으세요.
}

@Hint {
`ensure_ascii=False` 를 빠뜨리면 한국어가 `김` 같은 형태로 나갑니다.
}
}

@Quiz(id: csv-value-types, answer: all-strings) {
@Question {
`csv.reader()` 로 읽은 행의 값들은 어떤 타입으로 나올까요? 예를 들어 CSV에 25라는 숫자가 있었다면?
}

@Choice(id: all-strings) {
헤더든 숫자든 모두 문자열로 나온다
}

@Choice(id: auto-converted) {
csv.reader가 알아서 판단해 숫자는 int로 바꿔 준다
}

@Choice(id: header-only-strings) {
헤더만 문자열이고 데이터는 항상 숫자 타입이다
}

@Explanation {
CSV는 타입 정보를 담지 않는 순수 텍스트이므로 `csv.reader()` 는 모든 값을 문자열로 돌려준다. 숫자로 셈하려면 `int()` 나 `float()` 로 직접 바꿔야 한다. `json.loads()` 가 정수를 정수로 돌려주는 것과 대비되는 지점이다 — JSON은 형식 안에 타입이 들어 있다.
}
}

@Reflection(id: csv-json-reflection) {
@Prompt(id: csv-vs-json-when) {
표 형태의 데이터에는 CSV가, 중첩된 구조의 데이터에는 JSON이 어울립니다. 두 형식을 나눠 담는 기준을 자신의 말로 설명해 보세요.
}

@Prompt(id: string-conversion) {
CSV에서 읽은 "90"은 문자열이라 `int("90")` 으로 바꿔야 셈을 할 수 있습니다. 언제 변환하는 것이 좋을까요? 읽는 즉시 할지, 계산이 필요할 때 할지 생각해 보세요.
}

@Prompt(id: ensure-ascii) {
`ensure_ascii=False` 없이 한국어를 `json.dumps` 하면 `김` 처럼 나옵니다. 둘 다 같은 JSON인데, 어느 쪽을 파일로 남기고 싶은지와 그 이유를 적어 보세요.
}
}
