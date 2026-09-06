---
oculpm_plan: v1
id: polyglot-tutor
title: "Polyglot Study 튜터 — 로컬 검색과 옵트인 생성"
status: active
created: 2026-09-06
updated: 2026-09-06
owner: claude-code
---

macOS 14 하한 확정. 검색 계층은 기본(FTS5 + CJK 벡터 융합), 생성 계층은 옵트인(MLX 4B, macOS 26+ 는 FoundationModels 선택). 한국어 질의와 영어 문서는 벡터 공간이 달라 역할을 언어로 가른다 — 언어 장벽은 Diagnostic 의 영문 메시지가 건넌다. 거부가 기본값인 것이 이 기능의 안전 조건이다.

## macOS 14 검색 계층 — MVP {#search-layer-mvp}
- [ ] NLContextualEmbedding CJK 실측 스파이크 — 이 계층의 존폐가 여기서 갈린다 — 완료: 한국어 오답 노트 50건에 대해 평균 풀링 512차원 검색의 recall@10 과 FTS5 trigram 단독을 나란히 측정한 수치가 문서에 존재 {#nl-embedding-spike}
  - [ ] hasAvailableAssets 가 false 인 상태를 재현해 requestAssets 실패 경로와 실제 다운로드 용량(CJK 88MB · Latin 111MB)을 기록 {#nl-asset-download-probe}
  - [ ] CJK 모델에 영어 문자열을 넣었을 때 유의미한 벡터가 나오는지 판정 — 안 되면 영문 문서는 벡터 검색 대상에서 제외 {#cjk-english-probe}
- [ ] 임베딩 게이트웨이 — 백엔드 교체 가능한 얇은 프로토콜, 기본 구현은 NLContextualEmbedding CJK — 완료: 임베딩 차원·리비전·모델 식별자가 벡터와 함께 저장되고 백엔드 교체 시 기존 벡터가 자동 무효화됨 {#embedding-backend}
  - [ ] 256 서브워드 토큰 상한에 맞춰 청크 상한을 정하고 초과분은 잘리는 게 아니라 분할되도록 강제 {#nl-embedding-token-cap}
  - [ ] revision 을 벡터 행에 박고 OS 업데이트로 리비전이 바뀌면 인덱스를 재생성 {#embedding-revision-pin}
- [ ] 벡터 저장·검색 — BLOB 컬럼 + Accelerate 전수 탐색, 외부 확장 0 — 완료: 10만 청크 × 512차원 top-20 검색이 50ms 이내이고 swift build 만으로 빌드됨 {#vector-store}
  - [ ] 마이그레이션 008 — doc_source·doc_chunk·doc_vector 를 재생성 가능한 파생 캐시로, 골든 스키마 스냅샷 갱신 {#m004-doc-index}
  - [ ] Apple 시스템 SQLite 는 확장 로드가 불가해 sqlite-vec 이 커스텀 SQLite 빌드를 요구한다는 판정을 주석으로 남김 {#sqlite-ext-verdict}
- [ ] 코퍼스 수집 — 공식 배포 아카이브만, 크롤러 없이 — 완료: Python·SQLite·Swift 3종 코퍼스가 재실행 시 동일 체크섬으로 재현되고 네트워크 크롤링 코드가 0줄 {#doc-ingest}
  - [ ] 생성된 한국어 레슨 팩을 같은 인덱스에 넣음 — 단일 언어라 벡터 검색이 확실히 작동하는 유일한 코퍼스 {#lesson-pack-index}
  - [ ] 언어별 라이선스 판정표와 NOTICE 자동 생성, CC BY-SA 와 Oracle 계열은 원천 배제하고 링크만 {#doc-license-notice}
- [ ] 청킹 정책 — 섹션 헤딩 1차, 함수·메서드 시그니처 2차, 코드 예제는 분할 금지 — 완료: 골든 20문항에서 정답 청크가 잘려 문맥을 잃은 사례 0건 {#chunking-policy}
  - [ ] 청크마다 앵커 URL·소스·버전·상위 헤딩 경로를 메타로 붙여 인용에 그대로 사용 {#chunk-anchor-metadata}
- [ ] 하이브리드 검색 — 영문 문서는 FTS5, 한국어 노트·레슨은 벡터, RRF 로 융합 — 완료: 골든 질의 recall@10 이 FTS5 단독·벡터 단독 양쪽보다 높고 언어별 경로 선택이 테스트로 고정됨 {#hybrid-retrieval}
  - [ ] Diagnostic.message 와 ruleID 로 검색 질의를 증강 — 컴파일러 영문 메시지가 영문 문서의 언어 장벽을 우회하는 유일한 다리 {#diagnostic-query-expansion}
- [ ] 오답 노트 검색 융합 — 2자 한국어 질의를 벡터 경로로 구제 — 완료: 튜플·참조 같은 2자 질의가 결과를 내고 minimumQueryLength 계약이 금지에서 벡터 전용 경로로 갱신되며 기존 테스트가 함께 수정됨 {#korean-two-char-rescue}
- [ ] 인용 검색 UI — 생성 없이 근거만 보여주는 독립 기능 — 완료: 결과가 항상 소스·버전·앵커를 달고 나오며 클릭 시 원문이 열리고 어떤 화면에도 AI 생성 문장이 없음 {#cited-search-ui}
  - [ ] 인덱스 빌드는 백그라운드·취소 가능, 에셋 미다운로드 상태에서는 FTS5 전용으로 열화 동작 {#first-run-indexing}
- [ ] ProseRenderer 자체 구현 — Textual 을 의존에서 제거하고 macOS 14 를 지키며 블록 레이아웃만 직접 그린다 — 완료: 레퍼런스 레슨의 산문이 렌더되고 패키지 하한이 macOS 14 로 유지됨 {#prose-renderer}
  - [ ] 인라인은 AttributedString(markdown:options:) 의 inlineOnlyPreservingWhitespace 에 위임(macOS 12+) — 강조·코드스팬·링크가 공짜 {#inline-via-attributedstring}
  - [ ] 코드블록은 AttributedString 경로에 넣지 말고 전용 뷰로 빼야 폰트·스크롤이 산다 {#codeblock-separate-view}

## 생성 계층 — 옵트인 {#generation-layer}
- [ ] TutorProvider 프로토콜 — 백엔드 0개가 정상 상태 — 완료: LearnCore 가 MLX·FoundationModels 어느 것도 임포트하지 않고 컴파일되며 백엔드 0개일 때 검색 계층이 그대로 동작 {#tutor-provider-contract}
  - [ ] 미가용을 에러가 아니라 TutorAvailability 값으로 노출 — 미설치·미다운로드·하드웨어 부족을 구분 {#tutor-availability}
- [ ] TutorContext — lessonID·블록 인덱스·에디터 코드·Diagnostic 배열·최근 실패 제출을 Sendable 값 하나로 — 완료: GradeResult 하나에서 조립하는 순수 함수가 있고 예산 초과 시 결정적 순서로 잘림 {#tutor-context}
  - [ ] 토큰 예산 배분을 상수로 고정 — 진단 우선, 코드는 진단 줄 상하 20행 창으로만 {#context-token-budget}
- [ ] MLX 백엔드 — mlx-swift-lm 3.31.4 exact 핀, 사용자가 4B 급 모델을 명시적으로 내려받아야 활성 — 완료: macOS 14 타깃에서 빌드되고 4B 모델로 생성 1회 성공, 모델 미다운로드 상태에서 앱이 정상 기동 {#mlx-backend}
  - [ ] 3.31.4 에는 traits 블록도 MLXFoundationModels 도 MLXGuidedGeneration 도 없다는 사실과 main 승격 조건을 주석에 명시 {#mlx-pin-3-31-4}
  - [ ] 모델 카탈로그와 하드웨어 게이트 — 8/16/32GB 각각에서 후보 목록이 다르고 필요 용량이 다운로드 전에 표시됨. Qwen3-Coder-30B-A3B 는 17.5GB 라 32GB 맥 옵트인 전용 {#model-catalog}
- [ ] Metal 산출물 패키징 — xcodebuild 경로와 mlx-swift_Cmlx.bundle 번들·서명 — 완료: 공증한 앱을 다른 맥에서 실행해 MLX 추론이 동작하고 codesign --verify --strict 통과 {#mlx-metallib-packaging}
  - [ ] swift build 로는 셰이더가 안 만들어지므로 CI 게이트를 xcodebuild 로 이원화 {#swiftpm-metal-limitation}
- [ ] 메모리 중재자 — 컴파일 시작 직전 모델을 내리는 단일 조정 지점 — 완료: swiftc 서브프로세스 시작 직전 ModelContainer 참조가 해제되고 rusage 폴링에서 상주 메모리가 가중치 크기만큼 실제로 떨어짐 {#mlx-memory-arbiter}
  - [ ] WiredBudgetPolicy 와 reservation·active 티켓으로 가중치·KV·워크스페이스를 분리 예산 {#wired-memory-policy}
- [ ] 근거 강제 — 3.31.4 에 문법 제약이 없으므로 스키마 파서 + 재시도 + 후검증 3중으로 — 완료: 인용 없는 응답이 파서에서 거부되고 정해진 횟수 재시도 후에도 실패하면 답변이 폐기됨 {#grounded-answer-schema}
  - [ ] 모델이 뱉은 청크 id 가 실제 검색 결과에 없으면 환각으로 판정해 폐기 {#citation-verification}
  - [ ] 검색 점수 하한 미달이면 생성 자체를 건너뛰고 검색 결과만 반환 {#refusal-threshold}
- [ ] 튀터 EVALS — 골든 질문 세트로 인용 정확도·거부 정확도·지연을 채점 — 완료: swift test 로 돌고 코퍼스에 없는 주제 10문항이 전부 생성 없이 거부됨 {#tutor-evals}
- [ ] 튀터 UI — 레슨·에디터 화면의 사이드 패널, 맥락 배지, 인용 클릭 시 원문 열기 — 완료: 패널이 어떤 맥락을 보냈는지 사용자에게 보이고 백엔드 미가용 3상태가 각각 다른 안내로 렌더 {#tutor-ui-panel}
- [ ] (선택) FoundationModels 백엔드 — macOS 26+ 에서만 활성, 가중치 다운로드 0 — 완료: macOS 26 에서 Generable 구조화 답변 1회 성공하고 macOS 14~25 빌드에서 이 파일이 컴파일 대상에서 통째 빠짐 {#fm-backend}
  - [ ] macOS 26 컨텍스트가 4,096 토큰(세션 전체 공유)임을 계약에 못박고 tokenCount(for:) 로 사전 검사 {#fm-context-4096}

<!-- oculpm:plan-log begin v1 -->
| 시각 | 항목 | 에이전트 | 변화 | 일지 | 메모 |
|---|---|---|---|---|---|
<!-- oculpm:plan-log end -->
