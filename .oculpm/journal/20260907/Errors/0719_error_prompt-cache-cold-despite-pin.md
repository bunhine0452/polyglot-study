---
schema_version: 1
type: error
slug: "prompt-cache-cold-despite-pin"
status: done
difficulty: medium
created_at: "2026-09-07T07:19:46+09:00"
session_id: "20260907-002"
agent:
  id: "claude-code"
  version: "Claude Opus 5 (1M context)"
  session: "4bf27fbf-e40b-4759-bdaf-d90ea158e178"
language: "ko"
verified_by_user: false
files_touched:
  - path: "Tools/Sources/OpenRouterKit/UpstreamPin.swift"
    op: update
related:
  - ref: "20260907/Features_to_add/0656_feature_openrouter-upstream-pin.md"
    kind: "followup"
tags:
  - "openrouter"
  - "prompt-caching"
  - "measurement"
  - "cost"
  - "mcp-tool"
---
[x] 업스트림을 고정해도 프롬프트 캐시가 붙지 않는다 — 실측과 판정

`{#lessongen-prompt-caching}` 의 완료 기준("2회차부터 `cached_tokens` 가 0 이 아님")을 닫으려고 실왕복을 태웠다. **닫지 못했고, 왜 못 닫는지가 이 일지의 내용이다.**

## 발생 원인

가설은 "업스트림이 갈려서 캐시가 차갑다" 였다. 그래서 `--provider` 로 고정하고 다시 쟀다.

**고정은 지켜졌는데 캐시는 여전히 0이었다.**

| 실행 | 고정 | 답한 업스트림 | 호출 | 입력 토큰 | `cachedInputTokens` |
|---|---|---|---|---|---|
| A | 없음 | Wafer | 2 | 5,951 | **0** |
| B | Wafer | Wafer | 3 | 7,970 | **0** |

실행 B 는 `--concurrency 1` 로 순차였고 세 호출이 모두 같은 업스트림에 갔다(`pinnedProviders == upstreamProviders == ["Wafer"]`). 호출 간격은 약 277초와 60초로 통상적인 캐시 TTL 안이다.

## 원인이 우리 쪽이 아님을 확인했다 (무료로)

두 가지를 크레딧 없이 확인했다.

1. **접두사 바이트 일치** — 서로 다른 두 레슨을 `--dry-run` 으로 찍어 `system` 메시지를 비교했다. **5,527바이트로 완전히 동일**하다. 가변부는 전부 `messages[1]`(user)에 있고 시스템은 `messages[0]` 이다. 캐시가 요구하는 모양 그대로다.
2. **공급자가 캐싱을 게시하는가** — `GET /api/v1/models/z-ai/glm-5.3-flash/endpoints` (인증 불필요, 무료)로 23개 엔드포인트 전부가 0이 아닌 `input_cache_read` 가격을 게시하고 `input_cache_write` 는 없음(무료)임을 확인했다. 플래너에 적힌 "자동 캐싱(쓰기 무료·읽기 0.2배)" 전제와 일치한다.

즉 접두사도 안정적이고, 업스트림도 고정됐고, 가격표상 캐싱도 존재하는데 `usage.prompt_tokens_details.cached_tokens` 가 0으로 온다. 남은 설명은 공급자 쪽이다 — Wafer 가 캐시를 실제로 안 쓰거나, 최소 접두사 길이가 우리 1,995 입력 토큰보다 크거나, 캐시는 쓰되 usage 에 보고하지 않거나.

## 해결 방법 — 고치지 않고 멈춘 이유

**여기서 더 태우지 않기로 판단했다. 비용 구조가 이 항목의 가치를 작게 만든다.**

실측 호출 하나의 비용 분해: `in=1995 out=3625 cost=$0.001468`. **출력이 비용을 지배한다.** 입력 캐시가 완벽하게 붙어도(읽기 0.2배) 총액에서 아끼는 몫은 대략 15~20% 수준이고, 그마저 업스트림을 하나로 묶는 대가(폴백 금지 → 가용성 하락)와 맞바꾸는 것이다. 23곳 중 다른 업스트림을 하나씩 태워 보는 탐색은 이 이득에 비해 값이 맞지 않는다.

배선 자체는 남는다 — `--provider` 고정, 안정 접두사, 그리고 실행 로그가 "고정 지켜짐 / 고정이 새었다"와 캐시 적중률을 찍는 관측 장치. 캐싱이 필요해지는 날(더 비싼 모델, 더 긴 접두사) 측정 도구는 이미 서 있다.

## 검증

이번 조사에 쓴 실왕복 총액 **$0.007446** (호출 5건, 실패 0건). 접두사 비교와 엔드포인트 조회는 무료였다. 생성물 자체는 정상이었다 — packB 에 레슨 2편이 실제로 만들어졌고 하나는 2차 시도에서 통과했다.

## 메모

부수적으로 잡은 것: 모델이 `@Choice` 본문을 비운 채 내놓아 직렬화가 거부한 사례가 1건 있었다(`lessons/...md:68:1: @Choice 의 본문이 비어 있다`). `serializeChecked` 가 디스크에 쓰이기 전에 잡았고 2차 시도에서 통과했다 — 게이트가 의도대로 동작한다는 증거지만, 팬아웃 시 재시도 예산에 영향을 준다.