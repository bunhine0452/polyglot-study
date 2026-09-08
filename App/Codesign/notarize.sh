#!/bin/bash
#
# 공증·스테이플 — {#notarize-staple-dmg}.
#
# **.app 번들이든 .dmg 파일이든** 하나를 받아 공증에 제출하고, 티켓을 **그 대상 자체에
# 스테이플**한 뒤 돌아온다. 배포용 아카이브는 만들지 않는다 — 그건 `Scripts/release.sh`
# (앱 zip)와 `Scripts/make-dmg.sh`(DMG)의 일이고, 순서가 전부다:
#
#   build-app.sh(서명) → notarize.sh(공증·스테이플, 앱) → ditto zip → generate_appcast
#   notarize.sh(공증·스테이플, 앱) → make-dmg.sh(DMG 조립·서명) → notarize.sh(공증·스테이플, DMG)
#
# 왜 이 순서인가 — {#staple-before-zip}:
#   `stapler` 는 **zip 에 스테이플하지 못한다**. 티켓은 `.app` 번들 안으로 들어간다.
#   그래서 공증은 배포 zip 을 만들기 **전에** 끝나야 한다. 릴리스를 구운 뒤에 공증을
#   덧붙이면 appcast 가 광고하는 edSignature·length 가 실제 파일과 어긋나고, 업데이트는
#   "받아지긴 하는데 설치가 안 되는" 형태로 조용히 깨진다({#sparkle-appcast} 의 그 함정).
#   같은 이유로 DMG 도 **이미 공증·스테이플된 앱**을 담은 뒤에 자신을 공증·스테이플해야
#   한다 — 앱과 DMG 는 Gatekeeper 가 검사하는 시점이 서로 다른, 별개의 서명 대상이다.
#
#   앱을 제출할 때는 이 스크립트가 임시로 zip 을 하나 만들었다 지운다 — notarytool 은
#   디렉터리를 받지 못하고 zip·pkg·dmg 만 받기 때문이다. DMG 는 이미 그 형태이므로
#   따로 압축하지 않고 그대로 제출한다.
#
# 스테이플이 서명을 깨지 않는 이유: 티켓은 코드 서명이 봉인하는 자원 바깥에 놓인다.
# 그래서 스테이플 뒤에도 서명 검증이 그대로 통과한다 — 이 스크립트 마지막에서
# 실제로 확인한다(앱은 `codesign --verify --deep --strict`, DMG 는 `--strict`만 —
# DMG 는 번들이 아니라 `--deep` 이 의미가 없는 단일 서명 대상이다).
#
# 사용법:
#   Scripts/build-app.sh --release
#   Codesign/notarize.sh App/.build/bundle/Polyglot.app
#   Scripts/make-dmg.sh App/.build/bundle/Polyglot.app --version 0.2.0
#   Codesign/notarize.sh App/.build/release/Polyglot-0.2.0.dmg
#
set -euo pipefail

ARTIFACT="${1:-}"
if [ -z "$ARTIFACT" ]; then
	echo "사용법: $0 <.app 번들 또는 .dmg 파일>" >&2
	exit 2
fi
if [ ! -d "$ARTIFACT" ] && [ ! -f "$ARTIFACT" ]; then
	echo "대상이 없다: $ARTIFACT" >&2
	exit 1
fi
# 이후 전 구간에서 이 값으로 앱 번들(디렉터리)과 DMG(파일)를 가른다.
IS_BUNDLE=0
[ -d "$ARTIFACT" ] && IS_BUNDLE=1

WORK_DIR=""
cleanup() {
	if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
		rm -rf "$WORK_DIR"
	fi
}
trap cleanup EXIT

# ── 자격증명 — {#notary-credentials} ──────────────────────────────────────
#
# 애플 ID·앱 암호·API 키가 이 스크립트·인자·로그 어디에도 리터럴로 남지 않는다.
# 두 경로를 지원하고, 환경 변수가 있으면 그쪽을 먼저 쓴다.
#
#   1. 로컬 — notarytool 키체인 프로파일. **한 번만** 저장해 두고 이후로는 이름만 부른다:
#        xcrun notarytool store-credentials "oculpm-notary" \
#          --apple-id "<Apple ID>" --team-id "<TEAM_ID>" --password "<앱 암호>"
#      앱 암호는 appleid.apple.com 에서 만든 app-specific password 다(계정 비밀번호가
#      아니다). 셸 히스토리에 남기기 싫으면 이 명령을 인자 없이 돌려 대화형으로 넣어라.
#
#   2. CI — Apple ID + 앱 전용 암호를 환경 변수로. 헤드리스 러너에서 **키체인 프로파일
#      경로는 쓸 수 없다**: 분리된 프로세스는 승인 대화상자(SecurityAgent)를 띄우지 못해
#      errSecUserCanceled(-128) 로 실패한다(Sparkle EdDSA 키에서 부딪힌 그 벽과 같다).
#      하지만 자격증명을 인자로 직접 주는 경로는 키체인을 아예 타지 않아 멀쩡히 돈다.
#
#      `--password` 가 인자로 들어가므로 같은 머신의 `ps` 에 잠깐 보인다. 러너는 이 잡
#      전용으로 떴다 사라지므로 감수한다 — 로컬에서는 이 경로 대신 1번(키체인 프로파일)을
#      쓴다. 그래서 이 스크립트는 로컬 기본값을 1번으로 두고, 환경 변수가 있을 때만 넘어간다.
#
#   3. CI 대안 — App Store Connect API 키. 2번과 같은 이유로 키체인을 타지 않는다.
#      `.p8` 은 base64 로 환경 변수에 담아 오고, 여기서 0700 임시 디렉터리 안 0600
#      파일로만 풀었다가 종료 시 지운다.
NOTARY_PROFILE="${NOTARY_PROFILE:-oculpm-notary}"
NOTARY_ARGS=()

if [ -n "${NOTARY_APPLE_ID:-}" ] || [ -n "${NOTARY_APPLE_PASSWORD:-}" ]; then
	: "${NOTARY_APPLE_ID:?NOTARY_APPLE_PASSWORD 를 줬으면 NOTARY_APPLE_ID 도 필요하다}"
	: "${NOTARY_APPLE_PASSWORD:?NOTARY_APPLE_ID 를 줬으면 NOTARY_APPLE_PASSWORD 도 필요하다}"
	: "${NOTARY_TEAM_ID:?NOTARY_APPLE_ID 를 줬으면 NOTARY_TEAM_ID 도 필요하다}"
	WORK_DIR="$(mktemp -d)"
	NOTARY_ARGS=(--apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_APPLE_PASSWORD")
	# 암호는 찍지 않는다. 어느 경로로 인증하는지만 남긴다.
	echo "==> 자격증명: Apple ID + 앱 전용 암호 (team $NOTARY_TEAM_ID)"
elif [ -n "${NOTARY_API_KEY_P8_BASE64:-}" ]; then
	: "${NOTARY_API_KEY_ID:?NOTARY_API_KEY_P8_BASE64 를 줬으면 NOTARY_API_KEY_ID 도 필요하다}"
	: "${NOTARY_API_ISSUER_ID:?NOTARY_API_KEY_P8_BASE64 를 줬으면 NOTARY_API_ISSUER_ID 도 필요하다}"
	WORK_DIR="$(mktemp -d)"
	chmod 700 "$WORK_DIR"
	KEY_FILE="$WORK_DIR/AuthKey.p8"
	# umask 로 먼저 좁힌다 — 만들고 나서 chmod 하면 그사이 한 틱이 열려 있다.
	(umask 077; printf '%s' "$NOTARY_API_KEY_P8_BASE64" | base64 --decode > "$KEY_FILE")
	if [ ! -s "$KEY_FILE" ]; then
		echo "NOTARY_API_KEY_P8_BASE64 를 디코드했더니 비어 있다 — base64 가 맞는지 확인해라." >&2
		exit 1
	fi
	NOTARY_ARGS=(--key "$KEY_FILE" --key-id "$NOTARY_API_KEY_ID" --issuer "$NOTARY_API_ISSUER_ID")
	echo "==> 자격증명: App Store Connect API 키 (key-id $NOTARY_API_KEY_ID)"
else
	WORK_DIR="$(mktemp -d)"
	NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
	echo "==> 자격증명: 키체인 프로파일 \"$NOTARY_PROFILE\""
fi

# ── 제출 전 확인 ─────────────────────────────────────────────────────────
#
# 잘못 구운 번들을 그냥 올리면 몇 분 기다린 끝에 Invalid 로 돌아온다. 공증 서버가
# 거절할 것이 확실한 세 가지는 여기서 먼저 막는다.
echo "==> 제출 전 확인"

TEAM_ID="$(codesign -dv "$ARTIFACT" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "not set" ]; then
	echo "이 대상에는 Team ID 가 없다(ad-hoc 서명) — 공증 대상이 아니다." >&2
	echo "Developer ID Application 인증서가 키체인에 있는지 확인하고 다시 서명해라:" >&2
	echo "  security find-identity -v -p codesigning" >&2
	exit 1
fi

# ad-hoc 경로에서만 붙던 예외가 남아 있으면 Hardened Runtime 이 약화된 번들이다.
# build-app.sh 가 Developer ID 로 서명했다면 애초에 붙지 않는다 — 그 불변식을 여기서
# 한 번 더 단언한다({#codesign-hardened-runtime}). DMG 에는 애초에 entitlements 가
# 없으니 이 grep 은 그냥 걸리지 않고 지나간다 — 굳이 IS_BUNDLE 로 가르지 않는다.
#
# `codesign ... | grep -q` 로 쓰지 않는다 — `grep -q` 는 매치하는 순간 종료하면서
# codesign 에 SIGPIPE 를 보내고, 이 스크립트의 `pipefail` 이 그것을 파이프라인 실패로
# 잡는다(실측: 타임스탬프가 **있는데도** 없다고 판정했다). 출력을 먼저 받아 둔다.
ARTIFACT_ENTITLEMENTS="$(codesign -d --entitlements - --xml "$ARTIFACT" 2>/dev/null || true)"
if printf '%s' "$ARTIFACT_ENTITLEMENTS" | grep -q "com.apple.security.cs.disable-library-validation"; then
	echo "com.apple.security.cs.disable-library-validation 이 남아 있다 —" >&2
	echo "ad-hoc 경로로 구운 앱이 들어 있다. 배포용이 아니니 공증에 올리지 않는다." >&2
	exit 1
fi

# 공증은 보안 타임스탬프를 요구한다. `--timestamp=none` 으로 서명된 대상은
# "The signature does not include a secure timestamp" 로 거부된다.
CODESIGN_INFO="$(codesign -dvv "$ARTIFACT" 2>&1 || true)"
if ! printf '%s\n' "$CODESIGN_INFO" | grep -q '^Timestamp='; then
	echo "서명에 보안 타임스탬프가 없다 — --timestamp 로 서명했는지 확인해라." >&2
	exit 1
fi

echo "    OK — Team ID $TEAM_ID · 라이브러리 검증 예외 없음 · 보안 타임스탬프 있음"

# ── 제출 ─────────────────────────────────────────────────────────────────
if [ "$IS_BUNDLE" -eq 1 ]; then
	SUBMIT_TARGET="$WORK_DIR/$(basename "$ARTIFACT" .app)-notarize.zip"
	# Sparkle 과 같은 이유로 ditto 를 쓴다 — /usr/bin/zip 은 심볼릭 링크를 따라가 버려서
	# Sparkle.framework 의 Versions 구조가 뭉개지고, 그러면 압축을 푼 앱의 서명이 깨진다.
	ditto -c -k --sequesterRsrc --keepParent "$ARTIFACT" "$SUBMIT_TARGET"
else
	# DMG 는 이미 notarytool 이 받는 단일 파일 형태다 — 압축해 봐야 한 겹 더 씌우는
	# 것뿐이라 그대로 제출한다.
	SUBMIT_TARGET="$ARTIFACT"
fi

echo "==> 공증 제출 — 심사에 몇 분 걸린다"
SUBMIT_LOG="$WORK_DIR/submit.txt"
# `notarytool submit --wait` 는 심사 결과가 Invalid 여도 0 으로 끝나는 경우가 있다.
# 종료 코드에 기대지 않고 출력의 status 를 직접 읽는다.
set +e
xcrun notarytool submit "$SUBMIT_TARGET" "${NOTARY_ARGS[@]}" --wait 2>&1 | tee "$SUBMIT_LOG"
set -e

STATUS="$(sed -n 's/^[[:space:]]*status:[[:space:]]*//p' "$SUBMIT_LOG" | tail -1)"
SUBMISSION_ID="$(sed -n 's/^[[:space:]]*id:[[:space:]]*//p' "$SUBMIT_LOG" | head -1)"

if [ "$STATUS" != "Accepted" ]; then
	echo "공증 실패 — status=${STATUS:-<판독 불가>}" >&2
	if [ -n "$SUBMISSION_ID" ]; then
		echo "== 심사 로그 (submission $SUBMISSION_ID) ==" >&2
		xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" >&2 || true
	fi
	exit 1
fi
echo "    OK — Accepted (submission $SUBMISSION_ID)"

# ── 스테이플 ─────────────────────────────────────────────────────────────
#
# 티켓을 대상 자체에 박는다(앱이든 DMG 든 — `stapler` 는 둘 다 받는다). 이게 있어야
# **네트워크가 끊긴 맥**에서도 Gatekeeper 가 온라인 조회 없이 통과시킨다. 공증만 하고
# 스테이플을 빼먹으면 오프라인 사용자에게만 경고가 뜨는, 재현하기 까다로운 형태로
# 깨진다.
echo "==> 스테이플"
xcrun stapler staple "$ARTIFACT"

# ── 검증 ─────────────────────────────────────────────────────────────────
#
# 진짜 테스트는 네트워크를 끊은 다른 맥이지만, 여기서 확인할 수 있는 것은 다 한다.
# 앱과 DMG 는 Gatekeeper 평가 타입이 다르다 — 앱은 "실행형"(execute), DMG 는 "연
# 파일"(open)이다. 잘못된 타입으로 assess 하면 통과해야 할 것도 판정이 어긋난다.
echo "==> 검증"
xcrun stapler validate "$ARTIFACT"
# 공증 전에는 "rejected / source=Unnotarized Developer ID" 였다. 여기서는
# "accepted / source=Notarized Developer ID" 여야 한다.
if [ "$IS_BUNDLE" -eq 1 ]; then
	spctl --assess --type execute -vv "$ARTIFACT"
	# 스테이플이 봉인을 건드리지 않았는지 — 이게 깨지면 zip 을 푼 앱이 실행되지 않는다.
	codesign --verify --deep --strict "$ARTIFACT"
else
	spctl --assess --type open --context context:primary-signature -vv "$ARTIFACT"
	# DMG 는 번들이 아니라 단일 서명 대상이므로 --deep 은 쓰지 않는다(중첩 코드가 없다).
	codesign --verify --strict "$ARTIFACT"
fi

echo "==> 완료: $ARTIFACT 공증·스테이플됨"
if [ "$IS_BUNDLE" -eq 1 ]; then
	echo "    이제 release.sh 가 이 번들을 zip 으로 묶거나 make-dmg.sh 로 DMG 에 담으면 된다."
else
	echo "    DMG 배포 준비 완료 — GitHub Release 자산으로 올리면 된다."
fi
