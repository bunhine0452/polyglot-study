#!/bin/bash
#
# Sparkle 업데이트 왕복 실측 — {#sparkle-updates} 의 완료 기준을 사람 없이 확인한다.
#
# 무엇을 증명하는가:
#   [1] 구버전 앱이 appcast 를 읽고 → 신버전을 내려받고 → EdDSA 서명을 검증하고 →
#       **자기 자신을 신버전으로 교체**한다. 판정은 설치된 번들의
#       CFBundleShortVersionString 이 바뀌었는지로 한다. 대화상자를 보고 판단하지 않는다.
#   [2] **서명이 틀린 업데이트는 거부된다.** appcast 의 sparkle:edSignature 를 한 글자
#       비틀어 같은 왕복을 다시 돌리고, 앱이 교체되지 **않았음**을 확인한다.
#       (1)만 통과하는 것은 증거가 아니다 — 검증을 통째로 끄면 (1)은 항상 통과한다.
#
# 왜 로컬 HTTP 서버인가: 이 저장소에는 git 원격도 GitHub Pages 도 아직 없다. 실제 피드
# 주소로는 왕복이 불가능하므로 127.0.0.1 에 피드를 세우고 앱의 피드 URL 을
# `POLYGLOT_SPARKLE_FEED_URL` 로 그쪽에 겨눈다. 검증되는 경로(appcast 파싱 · 다운로드 ·
# 서명 검증 · 설치)는 전송 주소와 무관하게 동일하다.
#
# 왜 일회용 키인가: 배포용 개인키는 로그인 키체인에 있고({#sparkle-eddsa-keys}), 거기서
# 꺼내려면 `generate_appcast` 가 키체인 접근 승인 대화상자를 한 번 받아야 한다 — 사람이
# 클릭해야 하는 일이라 자동 검증에 넣을 수 없다. 그래서 이 스크립트는 매번 **버리는**
# ed25519 키를 임시 디렉터리에 만들고, 검증용 빌드의 SUPublicEDKey 를 그 짝으로 덮어쓴다.
# 검증되는 것은 "이 특정 키" 가 아니라 **배선**이다 — 피드·서명·검증·설치의 경로는
# 어떤 키를 쓰든 같다. 배포용 키는 이 스크립트가 읽지도, 쓰지도 않는다.
#
# 사용법:
#   Scripts/verify-sparkle.sh            # 작업 디렉터리를 끝나면 지운다
#   Scripts/verify-sparkle.sh --keep     # 남긴다(로그를 들여다볼 때)
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.polyglotstudy.Polyglot"
OLD_VERSION="0.1.0"
NEW_VERSION="0.2.0"
TIMEOUT_SECONDS=180
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

WORK="$(mktemp -d /tmp/polyglot-sparkle.XXXXXX)"
SITE="$WORK/site"
SERVER_PID=""
APP_PID=""

cleanup() {
	[ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null || true
	pkill -f "$WORK/installed" 2>/dev/null || true
	[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
	if [ "$KEEP" -eq 1 ]; then
		echo "작업 디렉터리를 남긴다: $WORK"
	else
		rm -rf "$WORK"
	fi
}
trap cleanup EXIT

mkdir -p "$SITE"

# ── 1. 일회용 서명 키 ────────────────────────────────────────────────────
echo "==> [1/5] 일회용 EdDSA 키 생성"
KEY_DIR="$WORK/key"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
openssl genpkey -algorithm ed25519 -outform DER -out "$KEY_DIR/pkcs8.der"
chmod 600 "$KEY_DIR/pkcs8.der"
# PKCS#8 로 감싼 ed25519 개인키 DER 은 48바이트 고정이고 **마지막 32바이트가 시드**다.
# Sparkle 이 --ed-key-file 로 기대하는 값이 정확히 그 시드의 base64 다
# (common_cli/Secret.swift 의 secretUsesRegularSeed: secret.count == 32).
tail -c 32 "$KEY_DIR/pkcs8.der" | base64 >"$KEY_DIR/ed_private"
chmod 600 "$KEY_DIR/ed_private"
# 공개키는 SubjectPublicKeyInfo DER(44바이트)의 마지막 32바이트.
TEST_PUBLIC_KEY="$(openssl pkey -inform DER -in "$KEY_DIR/pkcs8.der" -pubout -outform DER |
	tail -c 32 | base64)"
echo "    일회용 공개키: $TEST_PUBLIC_KEY"

# ── 2. 구버전 조립 ───────────────────────────────────────────────────────
echo "==> [2/5] 구버전 $OLD_VERSION 조립"
"$APP_DIR/Scripts/build-app.sh" --release --version "$OLD_VERSION" --build 1 \
	--public-key "$TEST_PUBLIC_KEY" --output "$WORK/pristine" >"$WORK/build-old.log" 2>&1 ||
	{ tail -20 "$WORK/build-old.log"; exit 1; }

# ── 3. 신버전 릴리스 + 피드 ──────────────────────────────────────────────
PORT="$(python3 -c 'import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()')"
FEED_BASE="http://127.0.0.1:$PORT"

echo "==> [3/5] 신버전 $NEW_VERSION 릴리스 + 로컬 피드 ($FEED_BASE)"
# 릴리스 경로를 **그대로** 탄다 — 검증 스크립트가 따로 zip 을 만들면 릴리스 스크립트의
# 결함을 못 잡는다. 로컬로 돌리는 것은 피드 URL 과 서명 키뿐이다.
"$APP_DIR/Scripts/release.sh" --version "$NEW_VERSION" --build 2 \
	--output "$SITE" --feed-url "$FEED_BASE/appcast.xml" \
	--public-key "$TEST_PUBLIC_KEY" --ed-key-file "$KEY_DIR/ed_private" \
	>"$WORK/release.log" 2>&1 ||
	{ tail -30 "$WORK/release.log"; exit 1; }
grep -E '확인|URL' "$WORK/release.log" || true

# 서명을 비튼 사본. base64 한 글자만 바꾼다 — 길이도 형식도 그대로라 Sparkle 이
# "형식이 이상하다" 가 아니라 "서명이 맞지 않는다" 로 거부해야 한다.
python3 - "$SITE/appcast.xml" "$SITE/appcast-tampered.xml" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()

def flip(match):
    value = match.group(1)
    first = "B" if value[0] != "B" else "C"
    return 'sparkle:edSignature="%s"' % (first + value[1:])

out, count = re.subn(r'sparkle:edSignature="([^"]+)"', flip, text)
if count == 0:
    sys.exit("appcast 에 sparkle:edSignature 가 없다 — 비틀 대상이 없다.")
open(dst, "w", encoding="utf-8").write(out)
print("    서명을 비튼 사본 %d건: appcast-tampered.xml" % count)
PY

python3 -m http.server --bind 127.0.0.1 --directory "$SITE" "$PORT" >"$WORK/http.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do
	curl -fsS "$FEED_BASE/appcast.xml" -o /dev/null 2>/dev/null && break
	sleep 0.2
done
curl -fsS "$FEED_BASE/appcast.xml" -o /dev/null || { echo "로컬 피드가 뜨지 않았다." >&2; exit 1; }

# ── 3. 왕복 한 번을 돌리는 함수 ──────────────────────────────────────────
#
# $1 = 피드 URL, $2 = 로그 이름. 끝나면 설치된 번들의 버전을 표준 출력에 남긴다.
INSTALLED_PLIST="$WORK/installed/Polyglot.app/Contents/Info.plist"

run_round() {
	local feed="$1" name="$2" log="$WORK/$2.probe.log"

	# 매번 깨끗한 구버전에서 시작한다. 이전 라운드가 앱을 갈아치웠을 수 있다.
	rm -rf "$WORK/installed"
	mkdir -p "$WORK/installed"
	ditto "$WORK/pristine/Polyglot.app" "$WORK/installed/Polyglot.app"
	# Sparkle 이 사용자 기본값에 남긴 상태(마지막 검사 시각·건너뛴 버전)를 지운다.
	defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
	: >"$log"

	POLYGLOT_SPARKLE_PROBE=1 \
		POLYGLOT_SPARKLE_FEED_URL="$feed" \
		POLYGLOT_SPARKLE_PROBE_LOG="$log" \
		"$WORK/installed/Polyglot.app/Contents/MacOS/Polyglot" >"$WORK/$name.stdio.log" 2>&1 &
	APP_PID=$!

	local waited=0
	while [ "$waited" -lt "$TIMEOUT_SECONDS" ]; do
		local current
		current="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_PLIST" 2>/dev/null || echo "?")"
		[ "$current" = "$NEW_VERSION" ] && break
		# 프로브가 종료 상태를 찍었으면 더 기다릴 이유가 없다.
		grep -q "SPARKLE-PROBE exit" "$log" && break
		# 앱이 죽었으면 타임아웃까지 기다리는 것은 시간 낭비다. dyld 실패처럼 프로브가
		# 한 줄도 못 찍고 죽는 경우가 실제로 있었다 — 그때 stdio 로그가 유일한 단서다.
		kill -0 "$APP_PID" 2>/dev/null || break
		sleep 1
		waited=$((waited + 1))
	done

	kill "$APP_PID" 2>/dev/null || true
	pkill -f "$WORK/installed" 2>/dev/null || true
	APP_PID=""
	sleep 1

	echo "--- $name 프로브 로그 ---"
	if [ -s "$log" ]; then
		cat "$log"
	else
		echo "(비어 있다 — 앱이 프로브를 시작하기도 전에 죽었다. stdio:)"
		head -6 "$WORK/$name.stdio.log"
	fi
	echo "--- 설치된 번들 버전: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_PLIST" 2>/dev/null || echo '?') ---"
}

FAILURES=0

# ── 4. 정상 왕복 ─────────────────────────────────────────────────────────
echo "==> [4/5] 정상 왕복 — 구버전이 신버전을 받아 설치하는가"
run_round "$FEED_BASE/appcast.xml" "valid"
INSTALLED="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_PLIST" 2>/dev/null || echo '?')"
if [ "$INSTALLED" = "$NEW_VERSION" ]; then
	echo "PASS  구버전 $OLD_VERSION → $INSTALLED 설치 완료"
else
	echo "FAIL  설치 후에도 버전이 $INSTALLED 다 (기대: $NEW_VERSION)"
	FAILURES=$((FAILURES + 1))
fi

# ── 5. 서명이 틀린 업데이트는 거부돼야 한다 ──────────────────────────────
echo "==> [5/5] 거부 왕복 — 서명이 비틀린 업데이트를 물리치는가"
run_round "$FEED_BASE/appcast-tampered.xml" "tampered"
INSTALLED="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_PLIST" 2>/dev/null || echo '?')"
if [ "$INSTALLED" = "$OLD_VERSION" ] && grep -q "SPARKLE-PROBE updater-error" "$WORK/tampered.probe.log"; then
	echo "PASS  서명 불일치로 거부됐고 앱은 $INSTALLED 그대로다"
else
	echo "FAIL  거부되지 않았다 — 버전 $INSTALLED, 프로브가 updater-error 를 찍지 않았다"
	FAILURES=$((FAILURES + 1))
fi

echo
if [ "$FAILURES" -eq 0 ]; then
	echo "==> 전부 통과"
else
	echo "==> 실패 $FAILURES 건"
fi
exit "$FAILURES"
