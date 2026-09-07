---
schema_version: 1
type: feature
slug: "github-repo-and-sql-track"
status: done
difficulty: high
created_at: "2026-09-07T09:14:25+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Content/packs/polyglot-sql"
    op: create
  - path: "tracks/sql.outline.json"
    op: create
  - path: "tracks/sql.notes.txt"
    op: create
  - path: ".github/workflows/pr-checks.yml"
    op: update
  - path: "scripts/ci-assert-toolchain.sh"
    op: create
  - path: "App/Resources/Info.plist"
    op: update
  - path: "App/Scripts/release.sh"
    op: update
  - path: "README.md"
    op: update
related:
  - ref: "20260907/Features_to_add/0719_feature_ci-gate-pr-checks.md"
    kind: "followup"
  - ref: "20260907/Refactors/0913_refactor_sql-cage-write-policy.md"
    kind: "followup"
tags:
  - "github"
  - "ci"
  - "pages"
  - "sparkle"
  - "content"
  - "sql-track"
  - "mcp-tool"
---
[x] GitHub 공개와 SQL 트랙 12편 — CI 가 처음 실제로 돌았다

## 추가 기능

저장소를 **bunhine0452/polyglot-study** 로 공개하고 GitHub Pages(`gh-pages` 루트)를 켰다. SQL 트랙 12편을 굽고 `SUFeedURL` 을 실주소로 확정했다.

## 동작 흐름

**공개 전에 히스토리 전체를 시크릿 스캔했다.** `.env` 는 한 번도 커밋된 적 없고(`.env.example` 만), 실제 키 값이 히스토리·워킹트리에 0건, `BEGIN … PRIVATE KEY` 0건. push 는 되돌릴 수 없으므로 이 순서를 지켰다.

**피드 URL 을 먼저 정했다.** `SUFeedURL` 은 배포된 구버전 앱에 영구히 박혀서, 나중에 바꾸면 이미 나간 버전이 업데이트를 영영 못 받는다. 그래서 저장소 이름을 먼저 확정하고 push 했다. 앞서 걸어 둔 `UNVERIFIED_FEED_HOSTS` 게이트도 이때 해제했다 — 이제 계정 소유자가 그 호스트를 쥐고 있다.

항목 0개짜리 appcast 를 올려 뒀다. 404 와 다르게 업데이터가 "받을 것 없음"으로 정상 종료한다. 앱을 다시 빌드해 헤드리스 프로브를 돌리니 실주소를 읽고 `no-update` 로 끝났다 — 처음엔 **옛 주소로 404** 가 났는데, 번들이 Info.plist 변경 전 빌드였기 때문이다.

## CI 가 처음 돌았고, 두 번 넘어졌다

원격이 없어 검증하지 못했던 부분이 바로 드러났다.

**① 러너 툴체인.** `macos-14` 의 기본 Swift 가 5.10 인데 세 패키지가 모두 tools 6.2 를 요구해 두 게이트가 11초 만에 죽었다. 이미지를 하나씩 바꿔 가며 왕복하지 않고 매트릭스로 한 번에 쟀다 — `macos-14` 5.10 · `macos-15` 6.1.2 · **`macos-26` 6.3.3**(로컬과 동일). `macos-latest` 가 아니라 `macos-26` 을 명시했다. latest 는 언제든 다음 이미지로 옮겨 가고, 그때 조용히 깨지는 것보다 명시적으로 낡는 편이 낫다.

**② 내 편집 실수.** 툴체인 단언 스텝을 자동 삽입하면서 `checkout` 과 그 `with: fetch-depth: 0` 사이를 갈랐고, `with` 가 `run` 스텝에 붙어 워크플로 파일이 통째로 거부됐다. 잡이 하나도 안 뜨니 **로그도 없다**. 되돌린 뒤 파싱해서 "`run` 스텝에 `with` 가 없음"을 단언하고 올렸다.

`packtool validate` 게이트는 첫 PR(README 만 변경)에서 **통과**했는데, 팩 변경 감지가 건너뛴 것이다 — "필수 체크가 영영 대기 중"을 피하려고 넣은 설계가 의도대로 동작했다.

## SQL 트랙

파이썬과 달리 **시드가 필요했다.** `lessongen` 은 에셋을 만들지 않으므로 `assets/shop-seed.sql` 을 직접 쓰고 스키마를 `--notes` 로 프롬프트에 실었다. 트랙이 요구하는 성질을 의도적으로 심었다 — LEFT JOIN 이 의미를 갖도록 주문 없는 고객 둘, NULL 처리를 가르치도록 `city`·`shipped_at`·`category_id` 에 NULL, 창 함수용으로 카테고리별 여러 상품.

미리 확인한 것: 러너가 **실행마다 DB 를 클론**해서 변경 레슨이 다른 레슨을 오염시키지 않는다.

게이트가 10건을 잡았다. 4편은 평범한 결함이라 `repair` 로 고쳤고(`no such column`, SQL 테스트 파일에 파이썬 `import` 가 섞임, 결과셋 불일치), 나머지는 케이지가 막은 것이라 별도 일지로 갔다.

## 업스트림 고정의 효과가 처음 보였다

미고정 실행은 업스트림이 NextBit·Reka 로 갈려 캐시 적중 **2.1%**, `--provider NextBit` 고정 후 **50.3%**. "고정해도 안 붙는다"던 초기 판정이 표본 부족이었음을 다시 확인한다.

## 검증

LearnKit 1058 · Tools 309 통과, 빌드 경고 0. SQL 팩 12편 실패 0건(4단계 전부). Pages `appcast.xml` HTTP 200, 앱이 실주소로 `no-update`. 콘텐츠 누적 비용 약 $0.15.