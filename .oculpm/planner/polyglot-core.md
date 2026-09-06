---
oculpm_plan: v1
id: polyglot-core
title: "Polyglot Study 코어 — 영속화·스케줄링·실행기"
status: active
created: 2026-09-06
updated: 2026-09-06
owner: claude-code
---

되돌리기 가장 비싼 계층부터. review_log 스키마와 FSRS 퍼즈 봉인은 첫 리뷰가 쌓이기 전에 굳어야 하고, CodeRunner 백엔드는 콘텐츠 검증 게이트의 전제다. 표면 계층은 polyglot-surface 플랜.

## 영속화 계층 — LearnPersistence {#persistence-layer}
- [ ] GRDB.swift 를 upToNextMinor(7.11.1) 로 핀하고 LearnPersistence 타깃을 coreSettings 로 신설 — 완료: swift build 통과 + public import GRDB 가 0건 {#grdb-pin}
  - [x] 부팅 시 fts5_version·journal_mode·foreign_keys 를 실측하는 EnvironmentProbe 추가, fts5 없으면 명확한 에러로 중단 {#fts5-probe}
- [ ] LearnDatabase 조립 루트 — 파일은 DatabasePool(WAL), 테스트는 in-memory DatabaseQueue 를 any DatabaseWriter 로 주입 — 완료: 같은 테스트 스위트가 두 주입 모두에서 통과 {#learn-database}
  - [x] DB 경로를 Application Support 아래 learn.sqlite 로 고정하고 iCloud·Dropbox 동기 폴더 금지를 주석과 테스트로 못박기 {#db-location}
- [ ] 영속화 DTO 6종과 리포지토리 프로토콜 5종을 LearnCore 에 두어 GRDB 를 LearnPersistence 안에 가둠 — 완료: LearnCore 가 GRDB 없이 컴파일되고 in-memory 페이크 구현 존재 {#core-contracts}
  - [x] ReviewLogStore·CardStateStore·SubmissionStore·MistakeNoteStore·LessonProgressStore 다섯으로 자름 — 테이블 단위가 아니라 애그리게이트 단위 {#repo-protocols}
  - [x] GRDB 행 구조체를 LearnPersistence 안에 따로 두고 DTO 와 명시적으로 매핑 — retroactive 준수 회피 + 컬럼명 드리프트 허용 {#row-mapping}
- [ ] DatabaseMigrator 위에 번호 붙은 불변 마이그레이션 정책 확정 + 골든 스키마 스냅샷 — 완료: 전체 마이그레이션 후 schema 덤프가 체크인 픽스처와 바이트 일치 {#migration-policy}
  - [x] 출시된 마이그레이션 클로저 수정 금지, 변경은 항상 새 번호 — eraseDatabaseOnSchemaChange 는 DEBUG 에서도 금지하고 CI grep 으로 차단 {#migration-rules}
  - [x] 파생 테이블(card_state·FTS 섀도)에 한해 drop → recreate → replay 재구축 관용구 허용, review_log 행 수 불변을 단언 {#derived-rebuild-idiom}
- [ ] 마이그레이션 001 — review_log 를 append-only 진실의 원천으로 만들고 UPDATE·DELETE 를 트리거로 봉인 — 완료: 두 연산이 SQLITE_CONSTRAINT 로 ABORT {#m001-review-log}
  - [x] 컬럼 확정 — card_id·reviewed_at(epoch ms UTC)·rating(1..4)·state_before·elapsed_days·scheduled_days·review_duration_ms·scheduler_id·parameter_set_id·source, CHECK 6종 {#review-log-columns}
  - [x] 콘텐츠 팩이 삭제돼도 이력이 남도록 review_log 에서 팩 소유 테이블로 나가는 외래키를 의도적으로 두지 않음 {#review-log-no-fk}
  - [x] 인덱스 (card_id, reviewed_at, id) 리플레이용과 (reviewed_at) 통계용 두 개 — EXPLAIN QUERY PLAN 에 SCAN 없음 {#review-log-indexes}
  - [x] scheduler_parameters 소형 테이블 — 어떤 w 로 스케줄됐는지 소급 설명용, 활성 세트가 정확히 1개임을 부분 유니크 인덱스로 강제 {#scheduler-parameters}
- [ ] 마이그레이션 002 — card_state 를 언제든 버리고 재생성 가능한 파생 캐시로 — 완료: 통째 DELETE 후 재구축하면 이전과 동일한 행이 나옴 {#m002-card-state}
  - [x] 컬럼 — stability·difficulty·due_at·last_reviewed_at·state·reps·lapses·scheduled_days·derived_from_log_id·parameter_set_id·rebuilt_at 및 stale 판정 헬퍼 {#card-state-columns}
  - [x] 인덱스 (language_id, due_at) — 트랙별 독립 학습이라 큐 쿼리는 항상 언어로 먼저 좁힘 {#card-state-index}
- [ ] 마이그레이션 003 — 제출 이력과 정규화된 진단을 한 트랜잭션으로 기록 — 완료: GradeResult 하나가 submission 1행 + diagnostic N행으로 원자적 기록 {#m003-submission}
  - [x] submission 컬럼 — passed·source_code·stdout·stderr·exit_code·duration_ms·presenter·runner_backend·toolchain_version·failure_kind, presenter 4종이 rawValue 와 일치 {#submission-columns}
  - [x] diagnostic — submission_id ON DELETE CASCADE + ordinal(배열 순서 보존) + severity CHECK, PRAGMA foreign_keys=ON 확인 {#diagnostic-columns}
  - [x] stdout·stderr 를 쓰기 시점에 64KB 로 절단(ResourceLimits.outputBytes 는 1MB), 실패 제출은 레슨·블록당 최근 20건만 유지 {#submission-retention}
- [ ] 마이그레이션 004 — 오답 노트 본문과 FTS5 external-content 인덱스를 GRDB synchronize 로 연결 — 완료: 삽입·수정·삭제 후 검색 결과가 즉시 일관 {#m004-mistake-note}
  - [x] 토크나이저를 trigram 으로 — 한국어 부분어와 snake_case 식별자 조각을 둘 다 잡아야 하고 unicode61 은 둘 다 놓침 {#fts-tokenizer}
  - [x] bm25 정렬 + snippet 하이라이트를 반환하는 search 메서드를 MistakeNoteStore 에 노출, GRDB Row 가 클로저 밖으로 새지 않게 {#fts-search-api}
- [ ] 마이그레이션 005 — 6블록 시퀀스 진도를 팩·레슨 단위로 기록 — 완료: 블록 6개 순차 완료 시 in_progress 에서 completed 로 전이 {#m005-lesson-progress}
  - [x] PK(pack_id, lesson_id) + status CHECK 4종 + completed_blocks(json_valid) + current_block_index + 시각 3종, 시도 횟수는 submission 집계로 대체 {#lesson-progress-columns}
- [ ] 리포지토리 GRDB 구현 5종 작성 + Swift 6 DB 접근 경계를 테스트로 강제 — 완료: Database·Row·Statement 가 read/write 클로저 밖으로 나가는 코드 0건 {#repo-impl}
  - [x] 리포지토리를 actor 로 감싸지 않음 — GRDB 7 writer 는 이미 Sendable·스레드 안전이라 actor 는 홉만 늘리고 재진입 위험을 만듦 {#no-actor-wrapping}
  - [x] ValueObservation 기반 관찰 API 를 AsyncSequence 로 노출해 SwiftUI 글루 요구를 GRDB 자체 기능으로 충족 {#value-observation}
- [ ] SQLiteData 도입을 보류로 확정 — 최신 1.12.0 이 swift-tools-version 6.4 라 설치된 Swift 6.3.3 으로 해석 자체가 불가 {#sqlitedata-defer}
  - [x] 재검토 조건 둘 — UI 단계 진입, 또는 매니페스트 tools-version 이 설치 툴체인 이하로 하향. 도입하더라도 Features 타깃에만 {#sqlitedata-revisit}

## 복습 스케줄링 — LearnScheduling {#review-scheduling}
- [ ] swift-fsrs 를 커밋 4fbaf20 기준으로 Vendor/FSRS 에 벤더링 — 완료: MIT 사본과 upstream URL·SHA·수정목록을 담은 VENDORING.md 존재 {#fsrs-vendor}
  - [x] 태그를 쓰지 않는 이유 명시 — 최신 태그 v5.0.0 에는 FSRS-6(BasicSchedulerV6, 21-length defaultWv6)이 아예 없음 {#fsrs-sha-rationale}
  - [x] V6 전용으로 좁혀 FSRSReschedule 과 v4/v5 BasicScheduler 제외 — 실제 벤더링 표면은 200줄이 아니라 약 2,600줄 {#fsrs-vendor-trim}
- [ ] ReviewScheduler 프로토콜을 LearnCore 에 두고 벤더 FSRS 를 완전히 은닉 — 완료: LearnCore·LearnPersistence 시그니처에 FSRS 타입 0건 {#scheduler-protocol}
  - [x] preview 메서드가 4개 rating 별 다음 간격을 한 번에 반환 — 복습 UI 의 버튼 4개가 10분/1일/4일/9일 을 미리 보여줘야 함 {#scheduler-preview}
  - [x] 시각은 주입 클록으로 받아 epoch ms UTC 로 저장, 하루 경계는 사용자 설정 롤오버(기본 04:00 로컬)로 계산 {#scheduler-clock}
- [ ] 업스트림 참조 벡터 테스트를 이식해 벤더 포크가 ts-fsrs 와 수치까지 일치함을 고정 — 완료: V6 스위트 전체 녹색, 실패 시 어긋난 오라클이 메시지에 표시 {#fsrs-reference-vectors}
  - [x] 출처는 FSRSV6Tests·FSRSGeneratorParametersV6Tests·FSRSLongTermSchedulerTests (MIT), 오라클 값의 원본은 ts-fsrs 의 FSRS-6 테스트 {#vector-provenance}
  - [x] 2단계 옵티마이저 fsrs-rs 는 BSD-3-Clause 라 MIT 인 이 앱과 고지 방식이 다름 — 리뷰 1,000건 이후 도입 조건과 함께 기록 {#optimizer-license-note}
- [ ] replay 를 DB 를 모르는 순수 함수로 만들고 결정성 확보 — 완료: 같은 로그를 100회 replay 해도 결과 스냅샷이 바이트 단위로 동일 {#replay-determinism}
  - [x] FSRS 퍼즈를 끄거나 card_id 해시로 시드 고정 — 켠 채로 첫 리뷰가 쌓이면 이후 어떤 replay 도 원본과 영영 불일치. 첫 리뷰 전에 정해야 하는 유일한 항목 {#fuzz-seal}
- [ ] review_log 에서 card_state 전체 재구축 경로 + 골든 리플레이 회귀 방지 — 완료: 체크인된 200건 로그 재구축 결과가 기대 card_state 와 완전 일치 {#card-state-rebuild}
  - [x] 카드별 스트리밍 처리 후 한 트랜잭션 안에서 스왑 — 도중 실패해도 기존 캐시가 그대로 남아야 함 {#rebuild-transactional}
  - [x] 파라미터 세트가 바뀌면 자동으로 재구축 예약 — card_state.parameter_set_id 가 활성 세트와 다른 카드를 stale 로 집계 {#rebuild-on-param-change}
- [ ] 트랙별 due 큐 쿼리 확정 + 22.8만 행 규모 실측 — 완료: 언어 하나의 due 카드 50개 조회가 5ms 이하이고 전체 스캔 없음 {#due-queue-benchmark}
  - [ ] 신규·학습중·복습 혼합 비율과 일일 상한을 큐 쿼리 안에서 결정 — 앱 레이어에서 자르지 않음 {#queue-mixing}

## 격리 기반과 툴체인 감지 {#isolation-and-toolchain}
- [ ] C 런처 헬퍼 — setsid 후 setrlimit(CPU/NPROC/FSIZE) 걸고 execv, 부모는 데드라인에 killpg — 완료: 무한루프가 SIGXCPU 로, sleep 60 이 2초 내 프로세스 그룹째 소멸 {#launcher-core}
  - [x] 인자·종료코드·status fd 규약 확정 — 자식 정상종료는 코드 그대로 전달, 시그널 종료는 raise 로 재현, 런처 자신의 실패만 fd 3 에 쓰고 125 로 종료 {#launcher-abi}
  - [x] fd 3 에 SPAWNED·TIMEOUT·EXIT·SIGNAL 라인을 흘려 부모가 사인을 구분 — 벽시계 초과와 사용자 코드의 자체 SIGKILL 을 구별 {#launcher-deadline}
- [ ] 런처를 SPM C executableTarget 과 Xcode 헬퍼 타깃 양쪽에서 같은 main.c 로 빌드해 Contents/Helpers 에 서명 포함 복사 — 완료: codesign 이 앱과 같은 Team ID 를 보고 {#launcher-build}
  - [x] LauncherLocator 가 환경변수 → Bundle.main 보조 실행파일 → 실행파일 형제 순으로 탐색하고 실패 시 toolchainMissing 을 던짐 {#launcher-locator}
- [x] proc_listpids 로 프로세스 그룹 전체를 열거해 ri_phys_footprint 를 합산하고 초과 시 killpg — RLIMIT_AS·RLIMIT_DATA 가 macOS 에서 EINVAL 이라 유일한 길 {#memory-poller}
- [x] zsh -lic 에 센티널을 씌워 로그인 PATH 수확, stderr 폐기·3초 타임아웃·실패 시 관례 경로 폴백 — 완료: p10k 가 rc 에서 에러를 뱉어도 오염 없는 PATH {#path-harvest}
- [ ] PATH 와 관례 경로의 모든 후보를 열거해 각각 --version 을 2초 상한으로 실행하고 PATH 순서가 아니라 버전 정책으로 선택 — 완료: 3.9.6 이 아니라 3.13 대 python3 이 선택됨 {#toolchain-probe}
  - [x] 관례 경로에 miniconda3/bin·.local/bin·.cargo/bin·mise shims·pyenv shims·homebrew/bin 과 xcrun --find 포함 {#probe-search-paths}
  - [x] xcode-select -p 를 선행 게이트로 — 활성 개발자 디렉터리가 없으면 usr/bin 개발도구를 실행하지 않고 stub 처리해 CLT 설치 다이얼로그 회피 {#clt-dialog-guard}
  - [x] 판정 규칙 고정 — 종료코드 0 + 버전 정규식 매치 + 스텁 메시지 비매치만 ready, java 스텁은 stub, 동작하나 최소 버전 미달은 unsupported {#availability-mapping}
- [x] 프로브 캐시 키를 스키마 버전·툴 id·절대경로·inode 메타·PATH·OS 빌드·xcode-select 경로·앱 버전 해시로 정의하고 24시간 TTL — 완료: 툴체인 교체 시 자동 무효화 {#probe-cache}
- [x] 실행마다 고유 임시 워크스페이스를 만들고 SourceFile.path 의 절대경로·상위 참조를 스폰 전에 거부, 네 종료 경로 모두에서 정리 — 완료: 100회 반복 후 잔여 디렉터리 0 {#run-workspace}
- [ ] sandbox-exec 프로파일 v1 — 네트워크 전면 차단 + 쓰기는 워크스페이스와 TMPDIR 한정 + 읽기 관대, 부재나 거부 시 런처 단독 격리로 자동 강등 {#sandbox-profile}
- [x] RunnerContractTests 하네스와 ContractSupport 옵션셋, 언어별 픽스처 카탈로그(무한루프·fork bomb·출력폭주·거대 단일행·비UTF8·손자 프로세스·stdin echo) 구축 {#contract-harness}

## 실행 백엔드와 채점 {#backends-and-grading}
- [x] RunnerKit 타깃 신설 + swift-subprocess 1.0.0 고정 의존 — 완료: Subprocess 모듈과 SubprocessFoundation trait 사용 가능. 저장소 README 의 0.4.0 표기는 낡은 문서 {#runnerkit-target}
- [ ] SubprocessRunner 가 클로저 폼 run 을 AsyncThrowingStream 으로 브리지하고 teardownSequence 를 프로세스 그룹 대상으로 — 완료: 3갈래 동시 소비에 교착 없고 취소 시 1초 내 그룹 소멸 {#subprocess-runner}
  - [ ] 출력 상한을 limit 계열 API 가 아니라 Buffer 를 직접 세어 강제 — limit 은 초과 시 throw 하고 버리며 strings 는 128KB 단일행에서 throw {#output-cap}
  - [ ] TerminationStatus 와 런처 status 라인을 조합해 finished·wallClockExceeded·memoryExceeded·cancelled 로 매핑, SubprocessError 는 RunFailure.backend 로만 노출 {#termination-mapping}
  - [x] RunFailure 에 cpuExceeded 케이스 추가 — SIGXCPU(코드가 느리다)와 벽시계 초과(코드가 멈췄다)는 사용자에게 완전히 다른 의미 {#contract-cpu-exceeded}
- [ ] swiftc 를 diagnostic-style llvm + no-color + print-diagnostic-groups 로 돌려 텍스트 진단을 파싱 — swiftc 에 JSON 진단은 없음, fdiagnostics-format json 은 clang 전용 {#swift-compile}
- [ ] 예열된 SwiftPM 템플릿에 사용자 코드와 숨은 테스트만 갈아끼워 event-stream-output-path 로 JSON Lines 수집 — 완료: 예열 후 2회차 실행이 5초 이내 {#swift-testing-grade}
- [ ] Python 실행을 python3 -I -B 로 확정해 사용자 site-packages 와 PYTHON 계열 환경변수 차단하고 stdin 연결 — 완료: input 을 쓰는 프로그램이 정답을 냄. Pyodide 는 MVP 에서 제외 {#python-run}
- [ ] 표준 unittest 위에 JSON Lines 를 뱉는 60줄 하네스를 번들 — 완료: pytest 미설치 머신에서 통과·실패·에러 3종이 구분되고 사용자 stdout 이 테스트 JSON 을 오염시키지 않음 {#python-grade}
- [ ] InProcessRunner 가 copyfile CLONE 으로 매 실행 DB 를 복제하고 READONLY + query_only + authorizer + hard_heap_limit 으로 가둠 — 완료: 원본 db 파일의 mtime 이 어떤 실행 후에도 불변 {#sql-inprocess}
  - [x] sqlite3_progress_handler 데드라인 콜백과 취소 핸들러의 sqlite3_interrupt 로 무한 쿼리 차단, sqlite3_error_offset 을 행·열로 환산해 Diagnostic 생성 {#sql-diagnostics}
- [x] 결과셋 비교 채점기 — 참조 해답은 별도 클론에서 실행, 정렬 요구는 orderMatters 메타데이터로 분기 — 완료: INTEGER 10 과 REAL 10.0 은 같고 NULL·빈문자열·0 은 다르며 중복 행 개수까지 일치해야 통과 {#sql-resultset-grading}
- [x] table 프리젠터용 결과셋 diff 산출 — 누락 행·초과 행·첫 불일치 셀 좌표를 각각 50개 상한으로 — 완료: 1만 행 오답에서도 100ms 내 {#sql-result-diff}
- [ ] 계약 스위트 전 케이스를 세 백엔드에 통과시키고 병렬·누수 항목 추가 — 완료: 8개 동시 실행 무간섭, fork bomb 실행 후 잔존 프로세스 0, CI 그린 {#contract-suite-full}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
| 2026-09-06T15:33:00+09:00 | #fts5-probe | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #db-location | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #repo-protocols | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #row-mapping | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #migration-rules | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #derived-rebuild-idiom | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #review-log-columns | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #review-log-no-fk | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #review-log-indexes | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #scheduler-parameters | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #card-state-columns | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #card-state-index | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #submission-columns | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #diagnostic-columns | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #submission-retention | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #fts-tokenizer | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #fts-search-api | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #lesson-progress-columns | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #no-actor-wrapping | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #value-observation | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #sqlitedata-revisit | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #fsrs-sha-rationale | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #fsrs-vendor-trim | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #scheduler-preview | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #scheduler-clock | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #vector-provenance | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #optimizer-license-note | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #fuzz-seal | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 퍼즈 봉인 — FuzzSeal 에 disabled 케이스만 두고 파라미터 세트 해시에 포함 |
| 2026-09-06T15:33:00+09:00 | #rebuild-transactional | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #rebuild-on-param-change | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #launcher-abi | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | setsid 를 자식이 부르도록 반전 — 런처가 세션 리더면 killpg 가 자신을 죽임 |
| 2026-09-06T15:33:00+09:00 | #launcher-deadline | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #launcher-locator | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #memory-poller | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #path-harvest | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #probe-search-paths | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #clt-dialog-guard | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #availability-mapping | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | java 스텁을 종료코드 1 로 판별, 10개 트랙 실측 완료 |
| 2026-09-06T15:33:00+09:00 | #probe-cache | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #run-workspace | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #contract-harness | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #runnerkit-target | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #contract-cpu-exceeded | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #sql-diagnostics | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | no such table 은 error_offset 이 -1 이라 위치 없는 진단 경로 필수 |
| 2026-09-06T15:33:00+09:00 | #sql-resultset-grading | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
| 2026-09-06T15:33:00+09:00 | #sql-result-diff | claude-code | [ ]→[x] | journal/20260906/Features_to_add/1533_feature_parallel-core-implementation.md | 병렬 세션 4개 병합, 316 테스트 통과 |
<!-- oculpm:plan-log end -->
