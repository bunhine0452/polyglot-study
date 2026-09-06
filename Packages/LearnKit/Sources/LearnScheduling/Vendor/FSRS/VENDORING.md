# 벤더링 기록 — swift-fsrs (FSRS-6)

`{#fsrs-vendor}` `{#fsrs-sha-rationale}` `{#fsrs-vendor-trim}` `{#optimizer-license-note}`

| 항목 | 값 |
|---|---|
| Upstream | <https://github.com/open-spaced-repetition/swift-fsrs> |
| 커밋 SHA | `4fbaf20184d62f82a9f44f343337c61a2c5483e9` |
| 커밋 날짜 | 2026-05-25 (`Merge pull request #32 from bootuz/refactor/swift-testing-migration`) |
| 복사 날짜 | 2026-09-06 |
| 라이선스 | MIT (아래 전문) |
| 복사 파일 | 11개 / 2,092줄 (`Sources/FSRS/` 14개 중 3개 제외) |

## 왜 태그가 아니라 커밋 SHA 인가

**최신 릴리스 태그 `v5.0.0` 에는 FSRS-6 이 아예 없다.**

- `Scheduler/BasicSchedulerV6.swift` — main 브랜치에만 존재
- 21개짜리 `FSRSDefaults.defaultWv6` — main 브랜치에만 존재 (태그에는 19개 `defaultW` 뿐)
- `FSRSAlgorithmVersion` 버전 디스패치(`sMin`, `decay`, `factor`, `nextShortTermStability` 의
  v6 분기), 설정 가능한 `learningSteps`/`relearningSteps` — 전부 main 에만 존재

이 앱은 FSRS-6 을 쓰기로 했으므로(2025년 말 출시, Anki 25.07 부터 기본) 태그를 쓸 수 없다.
누군가 "최신 릴리스로 정리하자" 며 태그로 되돌리면 `FSRSVendorPinTests` 가 즉시 실패한다 —
`defaultWv6.count == 21` 과 `BasicSchedulerV6.swift` 파일 존재를 단언으로 박아뒀다.

패키지 의존성 대신 벤더링을 택한 이유는 별개다. 이 저장소는 스케줄 계산을 **소급 재현**해야
하고(`review_log` → `card_state` 재구축), 그러려면 알고리즘 소스가 커밋에 고정돼 있어야 한다.
SPM 의 `.exact` 핀은 태그를 옮길 수 있는 업스트림을 완전히 막지 못한다.

## 복사한 파일 (11개, 2,092줄)

```
Algorithm/FSRS.swift              379   (upstream 433 — reschedule 제거)
Algorithm/FSRSAlgorithm.swift     335
Helper/FSRSAlea.swift             137
Helper/FSRSHelper.swift           161
Helper/FSRSSteps.swift            117
Models/FSRSDefaults.swift         229
Models/FSRSModels.swift           282
Models/FSRSTypes.swift             35   (upstream 77 — Reschedule 타입 제거)
Scheduler/AbstractScheduler.swift  86
Scheduler/BasicSchedulerV6.swift  157
Scheduler/LongTermScheduler.swift 174
```

`LongTermScheduler` 는 v5·v6 공용이다(`enableShortTerm == false` 일 때 w17/w18 이 0 으로
접혀 두 버전이 같은 경로를 탄다). 그래서 V6 전용으로 좁히면서도 남겼다.

## 삭제한 파일

| 파일 | 줄 | 이유 |
|---|---|---|
| `Scheduler/BasicScheduler.swift` | 211 | v4/v5 전용 단기 스케줄러(하드코딩 1m/5m/10m). 이 앱은 FSRS-6 전용이라 도달 경로가 없다. |
| `Scheduler/FSRSReschedule.swift` | 193 | 업스트림의 이력 재계산 헬퍼. `LearnScheduling` 은 `ReviewScheduler.replay(_:)` 로 자체 리플레이를 하므로 두 번째 재생 경로를 두지 않는다. |
| `Tests/` 전체 | 2,738 | 참조 벡터만 골라 `Tests/LearnSchedulingTests/FSRS*ReferenceVectorTests.swift` 로 이식했다. |

## 로컬 수정 사항

1. **`public` 전면 제거** (11개 파일 전부, 기계적 치환)
   `LearnScheduling` 이 라이브러리 프로덕트라서 벤더의 `public` 은 곧 앱 전체의 공개 API 가
   된다. `import LearnScheduling` 한 코드가 `Card`·`Rating`·`FSRS` 를 볼 수 있으면
   "`ReviewScheduler` 프로토콜 뒤에 완전히 은닉" 이 성립하지 않는다. 전부 `internal` 로
   내려 모듈 밖에서 보이지 않게 했다. 테스트는 `@testable import` 로 접근한다.

2. **`Algorithm/FSRS.swift` — `reschedule(currentCard:reviews:options:)` 제거**
   `FSRSReschedule.swift` 를 벤더링하지 않았으므로 함께 제거. 자리에 이유를 주석으로 남겼다.

3. **`Models/FSRSTypes.swift` — `RescheduleOptions`, `IReschedule` 제거**
   위와 같은 이유. `IPreview` 와 `IScheduler` 는 남았다.

4. **`Algorithm/FSRS.swift` — `scheduler(for:reviewTime:)` 를 `throws` 로 변경**
   업스트림은 `v5 + enableShortTerm` 을 `BasicScheduler` 로 보냈다. 그 파일이 없으므로
   해당 분기는 이제 `FSRSError(.invalidParam)` 을 던진다. **조용히 다른 알고리즘으로
   스케줄되는 것보다 실패하는 편이 낫다** — 그런 행이 `review_log` 에 섞이면 리플레이가
   원본과 어긋난다. 호출부 두 곳(`repeat`, `next`)에 `try` 를 붙였다.

그 밖의 알고리즘 코드는 한 글자도 바꾸지 않았다. 참조 벡터 스위트가 그것을 증명한다.

## 퍼즈 봉인 `{#fuzz-seal}`

**FSRS 퍼즈는 이 앱에서 켤 수 없다.** `LearnScheduling/FSRSParameterSet.swift` 의 `FuzzSeal`
enum 은 케이스가 `.disabled` 하나뿐이고, `FSRSReviewScheduler.init` 이 생성된 엔진의
`enableFuzz` 를 실측해 참이면 `ReviewSchedulingError.fuzzNotSealed` 를 던진다.

이유는 `AbstractScheduler` 의 시드 유도식에 있다.

```swift
seed = "\(reviewTime.timeIntervalSince1970)_\(current.reps)_\(current.difficulty * current.stability)"
```

`timeIntervalSince1970` 은 `Double` 초다. 실제 리뷰는 나노초 정밀도 `Date()` 로 스케줄되는데
`review_log.reviewed_at` 은 **밀리초 정수**로 저장된다. 즉 원본 시드 문자열은 로그에 남지
않는다 — 서브밀리초 자릿수가 잘리고, 잘린 시각으로 돌린 replay 는 다른 시드·다른 난수·다른
간격을 낸다. 퍼즈를 켠 채 첫 리뷰가 기록되는 순간부터 `card_state` 는 **영원히 재구축
불가능한 원본 데이터**가 되고, "card_state 는 버릴 수 있는 캐시" 라는 영속화 설계 전제가
통째로 무너진다.

대안이었던 "`card_id` 해시로 시드 고정" 은 채택하지 않았다 — 같은 카드의 모든 리뷰가 같은
난수를 쓰게 되어 퍼즈의 목적(같은 날 카드 분산)이 사라지고, 벤더 트리를 더 깊이 수정해야
한다. MVP 규모에서 하루 복습량이 몰려 문제가 될 여지도 없다.

봉인 상태는 코드 밖에도 남는다. `FSRSParameterSet.identifier` 가 `fuzz=disabled` 를 해시에
포함하므로 모든 `review_log.parameter_set_id` 와 `scheduler_parameters` 행이 "퍼즈 봉인
세트로 스케줄됐음" 을 증언한다. 나중에 누가 퍼즈를 켜면 파라미터 세트 id 부터 달라진다.

## 2단계 옵티마이저 — fsrs-rs 는 라이선스가 다르다 `{#optimizer-license-note}`

개인화 파라미터 최적화(`w` 21개를 사용자 이력으로 재학습)는 Swift 구현이 없다. 유일한
현실적 경로는 `open-spaced-repetition/fsrs-rs` 를 XCFramework 로 감싸는 것인데, **fsrs-rs 는
BSD-3-Clause 이고 이 앱과 벤더링한 swift-fsrs 는 MIT 다.**

| | swift-fsrs (지금 벤더링) | fsrs-rs (2단계 후보) |
|---|---|---|
| 라이선스 | MIT | BSD-3-Clause |
| 고지 의무 | 저작권 표시 + 라이선스 사본 | 저작권 표시 + 라이선스 사본 + **무보증 조항 전문** |
| 추가 제약 | 없음 | **3항 — 기여자 이름을 파생물 홍보에 쓸 수 없음** |

둘 다 MIT 앱에 담을 수 있고 호환되지만 **고지 방식이 같지 않다.** MIT 사본 하나로 뭉뚱그릴
수 없고, 앱의 "오픈소스 라이선스" 화면에 두 항목을 따로, 각자의 전문으로 실어야 한다.
BSD 3항 때문에 마케팅 문구에 fsrs-rs 기여자·프로젝트 이름을 추천사처럼 쓸 수도 없다.

도입 조건: **리뷰 1,000건 이상 축적 후.** 그 전에는 개인화된 `w` 가 기본값보다 나쁘다.
도입 시점에 필요한 것 — (a) 라이선스 화면에 BSD-3-Clause 전문 별도 등재, (b) 새 `w` 를
새 `scheduler_parameters` 행으로 추가(기존 행 수정 금지), (c) `card_state` 전체 재구축 예약
(`{#rebuild-on-param-change}`).

---

## MIT License 사본 (swift-fsrs)

```
MIT License

Copyright (c) 2023 Ben Smiley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 참조 벡터의 출처 사슬 `{#vector-provenance}`

`Tests/LearnSchedulingTests/FSRS*ReferenceVectorTests.swift` 의 오라클 숫자는 우리가 만든
값이 아니다.

1. **원본** — `open-spaced-repetition/ts-fsrs` 의 `__tests__/FSRS-6.test.ts` (MIT).
   FSRS-6 레퍼런스 구현의 테스트이고, 이 값들이 사실상 FSRS-6 의 정의다.
2. **1차 이식** — `swift-fsrs@4fbaf20` 의 `Tests/FSRSTests/FSRSV6Tests.swift`,
   `FSRSGeneratorParametersV6Tests.swift`, `FSRSLongTermSchedulerTests.swift` (MIT).
   업스트림이 ts-fsrs 값을 verbatim 으로 옮겼다.
3. **2차 이식 (여기)** — 벤더 포크가 그 상태에서 표류하지 않았음을 우리 CI 에서 증명한다.

스위트가 녹색이면 `우리 벤더 트리 == swift-fsrs@4fbaf20 == ts-fsrs FSRS-6` 이다.

이식하지 않은 업스트림 케이스는 하나다 — `FSRSLongTermSchedulerTests.stateSwitching` 은
v5 `w` + `enableShortTerm: true` 를 섞어 쓰는데, 그 조합은 벤더링하지 않은
`BasicScheduler` 로 간다. 해당 경로가 조용히 넘어가지 않고 실패한다는 사실은
`FSRSVendorPinTests.v5ShortTermIsRejected` 가 대신 못박는다.

## 업스트림 갱신 절차

1. 새 커밋 SHA 를 정하고 임시 디렉터리에 clone → checkout.
2. 위 "복사한 파일" 11개를 덮어쓴다.
3. "로컬 수정 사항" 4개를 다시 적용한다 (1번은 기계적 치환, 2~4번은 이 문서의 설명대로).
4. `swift test --filter Reference` 를 돌린다. 오라클이 어긋나면 업스트림이 알고리즘을
   바꾼 것이므로, 올리기 전에 **기존 `review_log` 리플레이 결과가 달라지는지** 부터 본다.
5. 이 문서의 SHA·날짜·줄 수를 갱신한다.
