# 콘텐츠 팩 포맷 v1

Polyglot Study 의 레슨은 앱 바이너리가 아니라 **콘텐츠 팩**으로 배포된다. 이 문서는 팩의
디렉터리 레이아웃, `manifest.json` 스키마, 레슨 디렉티브 문법, 설치 규약을 확정한다.

구현은 `Packages/LearnKit/Sources/ContentKit`, 스펙대로 만든 샘플 팩은
`Content/fixtures/polyglot-mvp` 에 있다. **문서·구현·샘플 팩 셋이 어긋나면 테스트가 깨진다**
(`Tests/ContentKitTests/SamplePackTests.swift`).

---

## 1. 디렉터리 레이아웃

```
<pack>/
  manifest.json          팩 메타데이터. files 에 자기 자신은 넣지 않는다
  manifest.json.sig      정규 매니페스트 바이트에 대한 분리 서명 (packtool sign, 선택)
  stableids.lock         stableID 불변 잠금 파일
  lessons/    <id>.md    디렉티브 마크다운 레슨 본문
  starters/   <path>     과제 시작 코드 — 학습자에게 주어지는 것
  tests/      <path>     숨은 테스트 — 채점기가 돌리는 것
  solutions/  <path>     정답 코드 — 배포 팩에서는 벗겨진다
  expected/   <id>.txt   실행 예제의 기대 stdout
  assets/     <path>     이미지·샘플 DB 등 읽기 전용 자원
```

- `manifest.json` 과 `manifest.json.sig` 를 뺀 **모든** 파일이 `files` 에 등록돼야 한다.
  둘이 예외인 이유는 같다 — 자기 참조라 등록될 수 없다. 매니페스트는 자기 해시를 담을 수
  없고, 서명은 그 매니페스트가 확정된 **다음에야** 만들어진다. 등록되지 않은 파일이
  디스크에 있으면 설치가 거부된다(양방향 대조).
- 위 6개 디렉터리와 루트의 `stableids.lock` 밖에는 아무것도 둘 수 없다.
- `solutions/` 는 `packtool build` 가 배포 팩에서 벗긴다.

### 경로 규칙

경로 조각에 쓸 수 있는 문자는 **ASCII 영숫자와 `.` `-` `_`** 뿐이다. 공백·유니코드·
대문자 제한 없음이지만 공백은 금지다. 다음은 전부 거부된다.

| 형태 | 거부 이유 |
|---|---|
| `/etc/passwd`, `~/x` | 절대경로 |
| `../escape.md`, `lessons/../../x` | 상위 디렉터리 탈출 (정규화로 없애지 않는다 — 시도 자체를 기록해야 한다) |
| `lessons\a.md` | 역슬래시 |
| `lessons/.hidden` | 숨김 조각 |
| `lessons/a b.md` | 허용 문자 밖 |

---

## 2. `manifest.json` 스키마 v1

```json
{
  "schemaVersion": 1,
  "packID": "polyglot-mvp",
  "displayName": "Polyglot MVP 샘플 팩",
  "version": "1.0.0",
  "minAppVersion": "0.1.0",
  "generatedAt": "2026-09-06T00:00:00Z",
  "languages": ["python", "sql", "swift"],
  "lessons": [
    {
      "stableID": "py-0001-fstring",
      "language": "python",
      "title": "f-string 으로 문자열 만들기",
      "order": 1,
      "path": "lessons/py-0001-fstring.md",
      "objectives": ["…"],
      "prerequisites": []
    }
  ],
  "files": [
    { "path": "lessons/py-0001-fstring.md", "sha256": "30020b…", "bytes": 2709 }
  ]
}
```

| 필드 | 규칙 |
|---|---|
| `schemaVersion` | 1 이상의 정수. 앱이 아는 값보다 크면 **설치 거부**(3절) |
| `packID` | 소문자·숫자·하이픈, 1–64자, 하이픈으로 시작·끝 금지 |
| `displayName` | 공백만으로 이루어질 수 없음 |
| `version` / `minAppVersion` | `major.minor.patch[-prerelease]`. 선행 0 금지 |
| `generatedAt` | `YYYY-MM-DDTHH:MM:SSZ` — UTC, 초 정밀도. **git commit date 에서 온다** |
| `languages` | 비어 있을 수 없고 중복 불가 |
| `lessons[].stableID` | `packID` 와 같은 slug 규칙. 팩 안에서 유일 |
| `lessons[].order` | 같은 언어 안에서 유일 |
| `lessons[].path` | `lessons/` 아래여야 하고 `files` 에 등록돼 있어야 함 |
| `lessons[].prerequisites` | 이 팩 안의 `stableID` 만 |
| `files[].sha256` | 소문자 hex 64자 |
| `files[].bytes` | 0 이상 |
| `distribution` | 선택. 배포 팩에서만 `true`. 소스 팩에는 **키 자체가 없다** (6절) |

`PackManifest` 는 **와이어 포맷 그대로**다 — 버전과 경로가 `String` 인 것은 의도한 것이다.
잘못된 semver 가 `Decodable` 단계에서 터지면 "왜 거부됐는지"가 Foundation 의 에러 문자열
안으로 사라진다. 디코딩은 모양만 보고, 내용은 전부 `validate()` 가 본다.

### 깨진 매니페스트 6종과 각각의 에러

| 결함 | `PackManifestError` |
|---|---|
| 중복 `stableID` | `.duplicateLessonID` |
| 레슨이 가리키는 파일이 `files` 에 없음 | `.unregisteredFile` |
| 잘못된 semver | `.invalidVersion(field:raw:reason:)` |
| 경로 탈출 | `.unsafePath(field:raw:reason:)` |
| 빈 `lessons` | `.emptyLessons` |
| `languages` 에 없는 언어 | `.unknownLanguage` |

여섯이 **서로 다른 값이고 서로 다른 메시지**라는 것이 테스트로 고정돼 있다.

### 정규 바이트 규칙

`manifest.json` 은 서명 대상이 되는 바이트열이므로(6절) 인코딩이 결정적이어야 한다.

- UTF-8, LF, 파일 끝에 개행 하나.
- 키는 UTF-8 사전순 정렬, 들여쓰기 2칸.
- `/` 를 이스케이프하지 않는다.
- `files` 는 경로 사전순.
- `generatedAt` 은 **입력**이다. 인코딩 시점에 현재 시각을 읽는 코드는 없다.

같은 값을 몇 번을 구워도 바이트가 같고, 키 순서가 뒤섞인 JSON 을 읽어 다시 구우면
정규형으로 돌아온다. `packtool` 이 붙기 전까지는
`REGEN=1 swift test --filter regenerateSamplePackManifest` 가 샘플 팩의 해시를 갱신한다.

---

## 3. `schemaVersion` · `minAppVersion` 게이트

`PackManifest.checkCompatibility(appVersion:)` 이 판정한다. 실패는 **던지는 에러**이지
크래시가 아니고, 에러가 사용자에게 그대로 보여줄 한국어 문구를 들고 있다.

| 상황 | 에러 | 문구 |
|---|---|---|
| 팩 스키마 > 앱 | `.schemaTooNew` | "‘<팩>’ 팩은 이 앱보다 새로운 형식입니다. 앱을 업데이트한 뒤 다시 시도하세요." |
| 팩 스키마 < 지원 하한 | `.schemaTooOld` | "‘<팩>’ 팩은 더 이상 지원하지 않는 오래된 형식입니다. 새 팩을 내려받으세요." |
| `minAppVersion` > 앱 | `.appTooOld` | "‘<팩>’ 팩에는 앱 <버전> 이상이 필요합니다. 앱을 업데이트한 뒤 다시 시도하세요." |

`minAppVersion` 이 파싱조차 안 되는 매니페스트는 보수적으로 `.appTooOld` 로 판정한다 —
게이트가 "모르겠으면 통과"로 기울면 게이트가 아니다.

---

## 4. `stableids.lock`

```
# polyglot stableids v1
py-0001-fstring	python	lessons/py-0001-fstring.md
sql-0001-aggregate	sql	lessons/sql-0001-aggregate.md
swift-0001-optional	swift	lessons/swift-0001-optional.md
```

`stableID` 사전순, 탭 3필드, LF, 끝에 개행 하나. JSON 이 아닌 이유는 이 파일이 **사람이
읽는 diff** 이기 때문이다 — 레슨이 하나 늘면 한 줄이 늘고, 그게 리뷰에 보여야 한다.

학습 진도는 `(PackID, LessonID)` 로 매달려 있다. id 가 흔들리면 진도가 고아가 되고,
그 사실을 아무도 모른다. 그래서 **추가만 허용한다.**

### 위반 3종과 기대 에러 메시지

**1. 삭제** — 잠금에 있던 id 가 매니페스트에서 사라졌다.

```
stableID 삭제는 허용되지 않는다: py-0002-b (python lessons/py-0002-b.md)
학습 진도가 이 id 로 매달려 있다. 레슨을 없애려면 팩에서 빼지 말고 manifest 에 남긴 채 lessons 목록에서 감춰라.
```

**2. 개명** — 같은 레슨 파일의 id 가 바뀌었다. (경로가 같은데 id 가 다르면 삭제가 아니라 개명이다.)

```
stableID 개명은 허용되지 않는다: py-0002-b → py-0002-renamed (lessons/py-0002-b.md)
같은 파일의 id 를 바꾸면 그 레슨의 진도·복습 카드가 전부 고아가 된다. 원래 id py-0002-b 를 되돌려라.
```

**3. 재할당** — 같은 id 가 다른 레슨(다른 경로 또는 다른 언어)을 가리킨다.

```
stableID 재사용은 허용되지 않는다: py-0002-b 가 python lessons/py-0002-b.md 에서 python lessons/py-0009-other.md 로 옮겨갔다
같은 id 가 다른 레슨을 가리키면 기존 진도가 엉뚱한 레슨에 붙는다. 새 레슨에는 새 id 를 줘라.
```

---

## 5. 레슨 디렉티브 문법

레슨 본문은 [swift-markdown](https://github.com/swiftlang/swift-markdown) 의 블록 디렉티브
문법을 쓰는 마크다운이다. 레슨 하나는 **정확히 6블록, 정해진 순서**다.

```
@Concept → @Example → @Blank → @Task → @Quiz → @Reflection
```

최상위에는 이 여섯 디렉티브 말고 아무것도 올 수 없다 — 제목도, 문단도. 레슨 제목은
매니페스트의 `title` 이다.

### 5.1 인자는 식별자·열거 토큰·경로·정수 넷뿐

**자유 텍스트를 인자에 실을 수 없다.** 라이브러리 제약이지 취향이 아니다.

- 값 렉서는 `:` `,` `)` `{` **공백** 을 만나면 거기서 값을 끊는다. 에러도 경고도 없다.
  `@X(id: a:b)` 는 조용히 `id = "a"` 가 되고 `:b` 는 사라진다.
- 따옴표를 씌워도 값에 따옴표를 쓸 수 없는 것은 같다.
- 역슬래시는 **언이스케이프되지 않고** 값에 그대로 남는다. `expected\run.txt` 는
  역슬래시가 포함된 파일 이름이 된다.

그래서 파서는 파싱된 인자를 정규형으로 되짚어 원문과 대조하고, 한 글자라도 어긋나면
거부한다. 조용히 잘린 값이 통과하는 경로가 없다.

| 종류 | 문법 | 쓰는 곳 |
|---|---|---|
| 식별자 | `[A-Za-z][A-Za-z0-9_-]*`, 64자 이하 | `id`, `answer` |
| 열거 토큰 | `[a-z][a-z0-9-]*`, 32자 이하 | `language` |
| 경로 | 팩 상대 경로, 지정된 디렉터리 아래 | `expected`, `starter`, `tests`, `solution` |
| 정수 | 선행 0 없는 10진수 | `slot` |

자유 텍스트는 전부 **본문 하위 디렉티브**나 **사이드카 파일**로 뺀다.

- 빈칸 정답 → `@Answer` 본문
- 기대 stdout → `expected/<id>.txt`
- 퀴즈 질문·선택지·해설 → `@Question` / `@Choice` / `@Explanation` 본문

### 5.2 중괄호 본문은 반드시 여러 줄

한 줄 본문 `@X { y }` 는 **줄 끝의 `}` 까지 본문으로 삼킨다.** `@X { y } z }` 는 `y } z` 가
본문이 된다. 닫힌 것처럼 보이지만 아니다. 그래서 파서가 거부한다.

중괄호 **없는** 디렉티브 뒤 같은 줄의 텍스트는 조용히 버려진다. 이것도 거부한다.

렉시컬 사전 검사(`DirectiveSourceLint`)가 트리를 보기 전에 네 가지를 잡는다.

| 위반 | 예 |
|---|---|
| 한 줄 중괄호 본문 | `@Concept(id: a) { 본문 }` |
| 중괄호 없는 디렉티브 뒤 텍스트 | `@Concept(id: a) 버려질 텍스트` |
| 인자 목록이 다음 줄로 넘어감 | `@Example(id: a,` ⏎ `  language: swift)` |
| 닫는 `}` 가 줄을 독차지하지 않음 | `} 꼬리` |

펜스 코드 블록(```` ``` ````, `~~~`) 안은 검사하지 않는다. 디렉티브 이름은 **대문자로
시작**해야 한다 — 그래야 산문의 `@user` 나 코드의 `@dataclass` 를 오탐하지 않는다.

### 5.3 블록별 문법

#### `@Concept(id:)`

산문만. 코드 블록을 넣어도 산문의 일부다.

```
@Concept(id: fstring-basics) {
파이썬의 f-string 은 문자열 리터럴 앞에 `f` 를 붙이는 서식 문법이다.

중괄호 안에는 임의의 식이 들어간다.
}
```

#### `@Example(id:, language:, expected:)`

읽고 실행하는 예제. 본문에 펜스 코드 블록이 **정확히 하나** 있어야 하고, 그것이 실행
대상이다. 기대 stdout 은 `expected/` 아래 사이드카 파일이다.

```
@Example(id: fstring-run, language: python, expected: expected/py-0001-fstring-run.txt) {
아래 코드를 실행해 f-string 이 값을 어떻게 끼워 넣는지 확인한다.

```python
name = "polyglot"
count = 3
print(f"{name} has {count} tracks")
```
}
```

- `language` 는 `python | sql | swift` (MVP 3종).
- `expected` 는 `expected/` 아래여야 한다.

#### `@Blank(id:, language:)` + `@Answer(slot:)`

빈칸 채우기. 코드 안의 표식은 `___N___` (밑줄 셋 + 번호 + 밑줄 셋)이고, 정답은
`@Answer` 본문의 **평문**이다(인라인 코드의 백틱은 벗겨진다).

```
@Blank(id: fstring-blank, language: python) {
리스트의 합을 구해 f-string 으로 출력하려 한다. 두 칸을 채워라.

```python
values = [1, 2, 3]
total = ___1___(values)
print(f"total={___2___}")
```

@Answer(slot: 1) {
`sum`
}

@Answer(slot: 2) {
`total`
}
}
```

표식 번호와 `@Answer` 슬롯은 `1..n` 을 빠짐없이 덮어야 한다. 어긋나면 거부된다.

#### `@Task(id:, language:, starter:, tests:, solution:)` + `@Hint`

편집하고 채점받는 과제. 세 경로는 각각 `starters/` `tests/` `solutions/` 아래여야 한다.

```
@Task(id: initials, language: python, starter: starters/py-0001-initials.py, tests: tests/py-0001-initials.py, solution: solutions/py-0001-initials.py) {
공백으로 나뉜 이름의 이니셜을 돌려주는 `initials(full_name)` 를 완성해라.

@Hint {
`str.split()` 은 인자 없이 부르면 연속된 공백을 하나로 묶는다.
}
}
```

`@Hint` 는 0개 이상이고 문서 순서대로 1번부터 번호가 매겨진다.

#### `@Quiz(id:, answer:)` + `@Question` / `@Choice(id:)` / `@Explanation`

`answer` 는 선택지 id 를 가리키는 식별자다. 선택지는 2개 이상이어야 하고, 정답 키가
실제 선택지에 없으면 파싱 단계에서 거부된다.

```
@Quiz(id: fstring-quiz, answer: repr-conversion) {
@Question {
f-string 안에서 `!r` 변환 플래그는 무엇을 하는가?
}

@Choice(id: repr-conversion) {
값을 `repr()` 로 변환해 끼워 넣는다.
}

@Choice(id: rounding) {
소수점 이하를 반올림한다.
}

@Explanation {
`f"{value!r}"` 은 `repr(value)` 의 결과를 넣는다.
}
}
```

`@Explanation` 은 선택이다.

#### `@Reflection(id:)` + `@Prompt(id:)`

채점하지 않는 열린 질문. `@Prompt` 가 1개 이상 있어야 한다.

```
@Reflection(id: fstring-reflect) {
@Prompt(id: readability) {
같은 출력을 `%` 서식과 `str.format()` 으로도 써 보고 어느 쪽이 잘 읽히는지 판단해라.
}

@Prompt(id: injection) {
사용자 입력을 f-string 으로 SQL 에 넣으면 왜 위험한가?
}
}
```

### 5.4 파싱 결과

`LessonParser.parse(source:path:)` → `[LessonBlock]`. 여섯 개, 순서 고정.

`LessonBlock` 은 값 타입 6종(`ConceptBlock` `ExampleBlock` `BlankBlock` `TaskBlock`
`QuizBlock` `ReflectionBlock`)의 합이고 전부 `Sendable` 이다. **`Markup` 트리는 파싱
경계 밖으로 나가지 않는다** — `Markup` 은 `Sendable` 이 아니라서 nonisolated 코어와 UI 가
값으로 들고 다닐 수 없다. 산문은 마크다운 **소스 문자열**로, 위치는 `SourcePosition`
(swift-markdown 의 `SourceRange` 가 아니라 자체 타입)으로 옮겨 담는다.

모든 파싱 에러는 `LessonParseError` 하나이고 `line:column` 을 반드시 들고 있다.
파일 경로가 주어지면 `lessons/x.md:12:3: …` 형태로 접두사가 붙는다.

---

## 6. 배포 팩 — `packtool build` · `sign` · `verify`

배포되는 것은 소스 팩이 아니라 **배포 팩**이다. 다른 점은 셋뿐이다.

- `solutions/` 가 없다 (`PackLayout.strippedInDistribution`).
- 매니페스트에 `"distribution": true` 가 있다. 소스 팩에는 이 키가 **아예 없다** —
  `nil` 은 인코딩되지 않으므로 이미 구워진 팩의 정규 바이트가 이 필드 때문에 바뀌지 않는다.
- `manifest.json.sig` 가 있을 수 있다.

`distribution` 을 명령행 플래그가 아니라 매니페스트에 두는 이유는 서명이다. 서명이 정규
매니페스트 바이트에 걸리므로 "이 팩은 solutions 가 없는 것이 정상" 이라는 사실도 함께
서명된다. 플래그였다면 검증기를 부르는 쪽이 게이트를 끌 수 있었을 것이다.

### 굽는 순서 — 뒤집을 수 없다

```
packtool validate <소스>     실행 게이트까지 (solutions 가 있어야 돌아간다)
packtool build <소스> --sign  solutions 를 벗기고 해시 재계산 → 서명 → tar
packtool verify <배포 팩>     서명 + 해시
```

구운 뒤에는 `solutions/` 가 없어 실행 게이트를 돌릴 수 없다. 그래서 검증이 먼저다.
배포 팩에 `validate` 를 걸면 정적 세 단계만 돌고 `stagesRun` 에서 `execution` 이 빠진다 —
**돌지 않은 것을 통과로 적지 않는다.**

`build` 는 굽기 전에 구조·문법·의미 세 단계를 스스로 돌리고, 하나라도 실패하면 굽지 않는다.

### 재현성

같은 소스를 두 번 구우면 **tar 바이트가 같다.** tar 를 직접 쓰는 이유가 이것이다 —
`/usr/bin/tar` 는 mtime·uid·gid·uname·gname 을 파일 시스템에서 읽어 헤더에 싣는다.

| 필드 | 값 |
|---|---|
| mtime | `manifest.generatedAt` (빌드 시각이 아니다) |
| uid · gid | 0 |
| uname · gname | 빈 문자열 |
| mode | 파일 `0644` · 디렉터리 `0755` |
| 엔트리 순서 | 경로 사전순 |
| 최상위 | `<packID>-<version>/` 하나 |

gzip 을 걸지 않는 것도 같은 이유다(gzip 헤더에 압축 시각이 들어간다). ustar 의 name
필드가 100바이트라 그보다 긴 경로는 조용히 잘리지 않고 **거부**된다.

**예외는 서명 파일 하나다.** Apple 의 CryptoKit 은 Ed25519 논스에 난수를 섞는다 —
같은 키로 같은 바이트에 두 번 서명하면 다른 64바이트가 나오고 둘 다 유효하다(실측).
그래서 재현성 계약의 대상은 `manifest.json.sig` 를 뺀 트리 전부다.

### 서명

분리 서명이고 대상은 `manifest.json` **바이트 그대로**다. 매니페스트가 나머지 전부를
sha256 으로 덮고 있으므로 그 한 파일이면 충분하다 — 파일을 바꾸면 해시가 어긋나고,
해시를 맞추려면 매니페스트를 고쳐야 하고, 그러면 서명이 깨진다.

```
polyglot-pack-signature v1
algorithm: ed25519
publicKey: <base64 32B>
signature: <base64 64B>
```

서명이 자기 공개키를 들고 다니는 것은 **"다른 키로 서명됐다" 와 "변조됐다" 를 갈라서
보고**하기 위해서다. 신뢰의 근거는 아니다 — 검증기는 `POLYGLOT_PACK_PUBLIC_KEY` 와
대조하고, 다르면 서명을 계산해 보지도 않는다.

`verify` 는 **서명과 해시를 둘 다** 본다. 서명만 보면 레슨 본문이 바뀐 팩을 통과시킨다
(매니페스트를 손대지 않았으니 서명은 유효하다). 그 변조를 잡는 것은 `files[].sha256`
대조이고, 그 대조표가 진짜인지를 보장하는 것이 서명이다. 둘은 한 쌍이다.

| 상황 | 판정 |
|---|---|
| 서명 파일 없음 | `.missing` — 없으면 통과가 아니다 |
| 다른 키로 서명 | `.publicKeyMismatch(expected:actual:)` |
| 매니페스트 변조 | `.signatureInvalid` |
| 매니페스트가 정규형이 아님 | `.manifestNotCanonical` |
| 레슨·사이드카 변조 | `ContentPackError.checksumMismatch` / `.sizeMismatch` |
| 대조할 공개키가 망가짐 | `.expectedPublicKeyMalformed` (팩이 아니라 부르는 쪽의 문제) |

키는 **환경변수에서만** 읽는다 — 개인키는 `POLYGLOT_PACK_SIGNING_KEY`, 공개키는
`POLYGLOT_PACK_PUBLIC_KEY`. 플래그로 받으면 셸 히스토리와 `ps` 출력과 CI 로그에 남는다.
키 쌍은 `packtool keygen --private-key-out <파일>` 로 만들고, 개인키는 0600 파일로만
나간다 — **stdout 에는 공개키만 찍힌다.**

---

## 7. 설치

```
<Application Support>/ContentPacks/
  <packID>/
    1.0.0/               버전 디렉터리 — 한 번 놓이면 내용이 바뀌지 않는다
    1.1.0/
    current -> 1.1.0     심볼릭 링크 포인터
    .staging-<uuid>/     설치 중인 임시 디렉터리
```

`PackInstaller.install(from:appVersion:activate:)` 의 순서.

1. **검증** — 매니페스트 디코딩 → 선언된 경로 검사 → `validate()` → 버전 게이트 →
   소스 트리 스캔 → 매니페스트와 디스크 양방향 대조. 여기까지 디스크에 **아무것도 쓰지 않는다.**
2. **스테이징** — `.staging-<uuid>/` 에 등록된 파일만 하나씩 복사한다(트리 통째 복사가
   아니다 — 등록되지 않은 파일이 딸려 들어갈 수 없다).
3. **해시 대조** — 스테이징 안의 실제 바이트로 크기와 sha256 을 확인한다.
4. **버전 디렉터리로 `rename(2)`** — 원자적.
5. **`current` 교체** — 임시 이름으로 심볼릭 링크를 만들고 `rename(2)` 으로 덮는다.

`FileManager` 에는 "심볼릭 링크를 원자적으로 교체"가 없다. 지우고 다시 만들면 그 사이에
`current` 가 **없는** 순간이 생기고, 하필 그때 죽으면 팩이 통째로 사라진 것처럼 보인다.

**계약: 어느 시점에 프로세스가 죽어도 `current` 는 유효한 팩을 가리킨다.** 1–4 단계 중
어디서 죽어도 `current` 는 건드려지지 않았고, 5는 커널이 원자적으로 처리한다.

강제 종료가 남긴 `.staging-*` 는 다음 설치가 시작될 때 쓸어낸다. 설치 경로가 스스로
정리하려 애쓰지 않는 이유는, 프로세스가 죽으면 정리 코드도 함께 죽기 때문이다.

### 경로 하드닝

설치 **전에** 거부하고 디스크에 잔여물을 남기지 않는다. 스토어 루트조차 만들지 않는다.

| 악성 입력 | 잡는 곳 | 에러 |
|---|---|---|
| `files[].path == "../escape.md"` | `validateDeclaredPaths` | `.unsafeEntry(reason: .parentEscape)` |
| `files[].path == "/etc/passwd"` | `validateDeclaredPaths` | `.unsafeEntry(reason: .absolute)` |
| `files[].path == "lessons/../../escape.md"` | `validateDeclaredPaths` | `.unsafeEntry(reason: .parentEscape)` |
| 디스크의 심볼릭 링크 | `PackSourceScan.scan` | `.symbolicLink(path:)` |
| 레이아웃 밖 파일 | `PackSourceScan.scan` | `.fileOutsideLayout(path:)` |

디렉터리를 훑을 때 `FileManager.enumerator(at:)` 를 쓰지 않는다. enumerator 는 베이스
경로의 심볼릭 링크를 해석해 버려서(`/var` → `/private/var`) 접두사를 잘라 상대 경로를
얻는 방식이 **조용히 0개를 반환하며** 무너진다. 대신 재귀하며 `lastPathComponent` 를
이어 붙이고, 링크를 만나면 내려가지 않는다.

---

## 8. 공개 API 요약

`packtool` 과 앱이 쓰는 표면.

| 타입 | 역할 |
|---|---|
| `PackManifest` (+ `LessonEntry`, `FileEntry`) | 스키마 v1 Codable 모델 |
| `PackManifest.validate() throws(PackManifestError)` | 매니페스트 자체 일관성 |
| `PackManifest.checkCompatibility(appVersion:…)` | 스키마·앱 버전 게이트 |
| `PackManifestBuilder` | `files` 재계산, 정규 바이트로 쓰기 |
| `CanonicalJSON` | 정규 인코딩·디코딩, 정규 타임스탬프 |
| `StableIDLock` | 잠금 파싱·직렬화·위반 검사 |
| `SemanticVersion`, `PackRelativePath`, `PackLayout` | 값 타입과 레이아웃 상수 |
| `LessonParser` | 마크다운 → `[LessonBlock]` / `LessonDocument` |
| `LessonBlock` 외 6종, `SourcePosition`, `SourceSpan` | 파싱 결과 값 타입 |
| `DirectiveSourceLint` | 렉시컬 사전 검사 (`packtool` 의 문법 단계) |
| `ContentPack` | 디스크의 팩 하나 — 레슨 읽기, 해시 대조, 참조 검사 |
| `PackStore`, `PackInstaller`, `PackSourceScan` | 설치·롤백·경로 하드닝 |
| `PackSignature`, `PackSigning` | 서명 파일 형식, Ed25519 서명·검증 |
| `PackSignatureVerification` | 디스크의 팩 하나를 서명 + 해시로 검증 |
