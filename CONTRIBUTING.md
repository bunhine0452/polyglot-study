# 기여하기

Polyglot Study 는 아직 초기 단계다(README 의 "지금 어디까지 왔는가" 참고) — 큰 기능보다는
작고 검증 가능한 변경을 환영한다.

## 환경

- macOS 14 이상, Swift 6.3 / Xcode 26.6 이상 (`swift --version` 으로 확인).
- MVP 트랙(Python·SQL·Swift)만 건드릴 거라면 추가 툴체인 설치가 필요 없다 — `python3`,
  `sqlite3`, `swiftc` 는 macOS 에 기본으로 있거나 Xcode 가 가져온다.
- 다른 트랙(Rust·Go·Java 등)의 실행 백엔드를 만지려면 해당 툴체인이 필요하다. 앱의 툴체인
  화면(`OnboardingFeature`)이 무엇이 설치돼 있는지 실측해 보여준다.

## 시작하기

```bash
git clone <repo-url>
cd project08
swift test --package-path Packages/LearnKit   # 870개, 경고 0 이어야 한다
swift test --package-path Tools               # 139개
App/Scripts/build-app.sh --run                # 앱이 실제로 떠야 한다
```

`Tools/lessongen` 을 쓰려면 `.env.example` 을 `.env` 로 복사하고 OpenRouter 키를 채운다 —
`.env` 는 커밋되지 않는다. **API 키·토큰을 로그·테스트·픽스처·커밋 메시지 어디에도 남기지
않는다.**

## 저장소 구조와 책임 경계

| 경로 | 무엇 | 건드릴 때 |
|---|---|---|
| `Packages/LearnKit/` | 코어 라이브러리 12개 타깃 — 스케줄러·실행·영속화·디자인시스템·화면 | 대부분의 로직이 여기 있다. 타깃 경계를 넘는 의존을 새로 만들기 전에 기존 타깃 그래프(`Package.swift`)를 먼저 읽는다. |
| `Tools/` | `packtool`·`lessongen` CLI. 별도 SPM 패키지인 이유는 `ArgumentParser` 를 앱 산출물에 링크하지 않기 위해서다 | CLI 동작만 바꾼다 — 앱이 이 패키지에 의존하면 안 된다. |
| `App/` | SwiftUI 앱 셸, 번들 조립, 서명 스크립트 | 화면 로직은 여기 두지 않는다 — `PolyglotApp.swift` 는 조립만 한다. |
| `Content/packs/` | 콘텐츠 팩(레슨·과제) | 포맷은 `docs/pack-format.md` 가 정답. 스키마를 벗어나면 `ContentKit` 파싱이 throw 한다. |
| `Vendor/` | 벤더링한 서드파티 소스 | 각 디렉터리의 `VENDORING.md` 없이 임의로 고치지 않는다 — 업스트림과의 diff 를 그 문서가 추적한다. |
| `design/` | 화면 디자인 근거(스위스 그리드 아트보드) | 새 화면을 만들 때 색·타입·간격은 여기서 나온 `DesignSystem` 토큰을 거친다. |

## 코드 스타일

- **KISS / DRY / YAGNI.** 조기 반환으로 깊은 중첩을 피한다. 파일은 200~400줄이 보통이고
  800줄이 한계다.
- **주변 코드의 관용구를 따른다.** 이 저장소는 값 타입·`Sendable` 경계를 기본으로 하고,
  UI 타깃은 `@MainActor` 기본 격리(`uiSettings`), 코어 타깃은 `nonisolated` 기본
  (`coreSettings`)이다 — 타깃을 넘나드는 코드를 쓸 때 그 경계를 존중한다.
- **디자인 토큰을 거친다.** 화면 코드에 색 리터럴(`Color(hex:)`)이나 `cornerRadius`·
  `shadow` 를 직접 쓰지 않는다 — `DesignSystem` 의 `Palette`/프리미티브를 쓴다. 이 규칙은
  grep 테스트로 고정돼 있다(`DesignSystemTests`).
- **정책 grep 테스트를 깨지 않는다.** 예: `LearnPersistence` 밖에서 `import GRDB` 금지,
  `eraseDatabaseOnSchemaChange` 사용 금지, 마이그레이션 `001`~`007` 수정 금지(변경은 항상
  새 번호로). 이런 규칙이 왜 있는지는 각 테스트 파일 주석과 `HANDOFF.md` 를 참고한다.

## 커밋

`<type>(<scope>): <설명>` — `feat`·`fix`·`refactor`·`docs`·`test`·`chore`·`perf`·`ci`.
예: `fix(runner): sandbox-exec 규칙 경로를 realpath 로 정규화`.

커밋 전에 확인한다:

- 하드코딩된 키·토큰·비밀번호가 없다.
- `.env` 내용이 로그·일지·커밋 메시지·테스트 인자 어디에도 실리지 않는다.
- 관련 테스트 스위트(`swift test --package-path Packages/LearnKit` 그리고/또는
  `--package-path Tools`)가 그린이다.

## PR

- 무엇을 바꿨고 **왜** 바꿨는지, 어떻게 검증했는지(어떤 테스트를 돌렸는지, 필요하면 스크린샷)
  를 설명에 적는다.
- 요청받지 않은 범위 확장(테스트 커버리지 일괄 추가, 포매팅 일괄 변경, 관련 없는 리팩터)은
  피한다 — 리뷰가 어려워지고 diff 가 논지를 잃는다.
- 콘텐츠 팩(`Content/packs/`)을 바꾼다면 지금은 `packtool validate` 가 스텁이라(README 참고)
  자동 게이트가 없다 — PR 설명에 수동으로 어떻게 확인했는지 적는다.

## 참고

이 저장소는 ocul-pm 워크플로(`.oculpm/`)로 개발 이력을 기록해 왔다 —
일지·계획이 `.oculpm/journal/`·`.oculpm/planner/` 에 쌓여 있다. 사람 기여자가 이 도구를 직접
쓸 필요는 없다 — 과거 결정의 근거가 필요하면 그냥 읽으면 된다. `AGENTS.md` 는 그 기록
규칙이고, `HANDOFF.md` 는 세션 간 인수인계 문서다.
