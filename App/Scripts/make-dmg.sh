#!/bin/bash
#
# DMG 조립 + 서명 — {#dmg-notarize}.
#
# 이미 조립·서명되고 **공증·스테이플까지 끝난** 앱 번들 하나를 받아 Applications
# 폴더로 드래그하는 표준 DMG 를 만들고, 그 **DMG 컨테이너 자체를 별도로 서명**한다.
# 앱 서명과 DMG 서명은 서로 다른 코드 서명 대상이다 — 서명 안 된 DMG 는 공증에
# 올려도 그 자리에서 거부된다.
#
# 왜 앱과 DMG 를 둘 다 공증·스테이플해야 하는가:
#   Gatekeeper 가 검사하는 시점이 둘이다. 사용자가 DMG 를 열 때(마운트) 보는 것은
#   DMG 자체의 서명·티켓이고, 앱을 Applications 로 옮겨 실행할 때 보는 것은 앱 안의
#   티켓이다. 앱만 공증하고 DMG 컨테이너를 안 하면 DMG 를 여는 순간에만(오프라인이면
#   더 나쁘게, 온라인 조회가 막힌 상태로) 경고가 뜬다 — `stapler validate` 가 **DMG
#   단독으로** 통과해야 한다는 것이 이 항목의 완료 기준인 이유다.
#
# 순서 — Codesign/notarize.sh 의 {#staple-before-zip} 과 같은 이유가 DMG 에도 그대로
# 적용된다: 이 스크립트는 **이미 공증·스테이플된 앱**만 받는다. 서명만 되고 아직
# 스테이플되지 않은 앱을 그대로 넣으면, DMG 는 통과해도 그 안의 앱을 Applications
# 로 옮겨 처음 열 때(오프라인이면) 경고가 뜨는, 재현하기 까다로운 형태로 깨진다 —
# 그래서 아래에서 `stapler validate` 로 **막는다**(가정으로 두지 않는다).
#
# 사용법:
#   Scripts/build-app.sh --release
#   Codesign/notarize.sh App/.build/bundle/Polyglot.app
#   Scripts/make-dmg.sh App/.build/bundle/Polyglot.app --version 0.2.0 --output App/.build/release
#   Scripts/make-dmg.sh App/.build/bundle/Polyglot.app --version 0.2.0 --notarize   # 서명 뒤 바로 공증·스테이플까지
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_BUNDLE="${1:-}"
if [ -z "$APP_BUNDLE" ] || [ ! -d "$APP_BUNDLE" ]; then
	echo "사용법: $0 <APP_BUNDLE> [--version X.Y.Z] [--output DIR] [--notarize]" >&2
	exit 2
fi
shift

VERSION=""
OUTPUT="$APP_DIR/.build/release"
NOTARIZE=0

while [ $# -gt 0 ]; do
	case "$1" in
	--version)
		VERSION="${2:-}"
		shift
		;;
	--output)
		OUTPUT="${2:-}"
		shift
		;;
	--notarize)
		NOTARIZE=1
		;;
	*)
		echo "알 수 없는 인자: $1" >&2
		exit 2
		;;
	esac
	shift
done

# ── 스테이플 확인 ────────────────────────────────────────────────────────
#
# 위 헤더가 "이미 공증·스테이플된 앱을 받는다고 가정한다" 고 적어 놓고 강제하지
# 않던 자리다(실측 2026-09-08: 스테이플 안 된 앱으로도 DMG 가 조용히 만들어졌다).
# 가정은 검사해야 가정이다 — 여기서 막지 않으면 DMG 자체는 `stapler validate` 를
# 통과하는데 그 안의 앱만 티켓이 없는, **오프라인 첫 실행에서만** 드러나는 형태로
# 깨진다. 만든 사람은 온라인이라 못 본다.
#
# 예외를 두지 않는다. DMG 는 사람이 내려받는 배포물이고, 배포물이 아닌 DMG 를 만들
# 이유가 없다 — 로컬에서 앱만 확인할 거면 build-app.sh 의 번들을 그대로 열면 된다.
if ! STAPLE_OUT="$(xcrun stapler validate "$APP_BUNDLE" 2>&1)"; then
	echo "$0: 앱 번들에 공증 티켓이 스테이플되어 있지 않다 — DMG 를 만들지 않는다." >&2
	echo "    $APP_BUNDLE" >&2
	printf '%s\n' "$STAPLE_OUT" | sed 's/^/    /' >&2
	echo "    먼저: Codesign/notarize.sh \"$APP_BUNDLE\"" >&2
	exit 1
fi

APP_NAME="$(basename "$APP_BUNDLE" .app)"
# 버전을 안 줬으면 번들 자체에서 읽는다 — build-app.sh --version 으로 이미 덮어쓴
# Info.plist 가 유일하게 신뢰할 수 있는 값이다(사람이 두 번 세지 않는다).
if [ -z "$VERSION" ]; then
	VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || echo "")"
fi
DMG_BASENAME="${APP_NAME}${VERSION:+-$VERSION}.dmg"

mkdir -p "$OUTPUT"
DMG_PATH="$OUTPUT/$DMG_BASENAME"

# ── 스테이징 ─────────────────────────────────────────────────────────────
#
# hdiutil 은 소스 폴더를 그대로 볼륨 루트로 옮긴다. 앱 하나와 /Applications 심볼릭
# 링크만 담는다 — 배경 이미지·아이콘 배치는 범위 밖이다. 이 항목의 완료 기준은
# "DMG 단독으로 stapler validate 통과" 이지 겉모습이 아니다.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
# ditto 를 쓴다 — cp -R 은 확장 속성·리소스 포크를 놓칠 수 있고, 이 저장소 전체가
# 이미 ditto 를 프레임워크·번들 복사의 표준 도구로 쓰고 있다(build-app.sh 참고).
ditto "$APP_BUNDLE" "$STAGE/$(basename "$APP_BUNDLE")"
ln -s /Applications "$STAGE/Applications"

echo "==> DMG 조립: $DMG_PATH"
rm -f "$DMG_PATH"
# UDZO(압축, 읽기 전용)를 소스 폴더에서 한 번에 만든다. 배경 이미지를 Finder 로
# 배치하려면 UDRW 로 만들어 마운트 상태에서 편집한 뒤 convert 하는 2단계가 필요하지만
# (범위 밖), 지금은 필요 없다.
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"

# ── 서명 ─────────────────────────────────────────────────────────────────
#
# 신원 선택 방식은 build-app.sh 와 같다 — **이름으로** 고른다. 목록 순서에 기대면
# Xcode 로그인이 만든 "Apple Development: ..." 가 먼저 걸릴 수 있고, 그건 배포에 쓸
# 수 없는 신원이다(근거: Scripts/build-app.sh 의 {#codesign-hardened-runtime} 절).
SIGN_IDENTITY="-"
IDENTITY_LINES="$(security find-identity -v -p codesigning 2>/dev/null | grep -E '^[[:space:]]*[0-9]+\)' || true)"
IDENTITY_LINE="$(printf '%s\n' "$IDENTITY_LINES" | grep -F 'Developer ID Application:' | head -1 || true)"
if [ -n "$IDENTITY_LINE" ]; then
	CANDIDATE_HASH="$(printf '%s\n' "$IDENTITY_LINE" | awk '{print $2}')"
	[ -n "$CANDIDATE_HASH" ] && SIGN_IDENTITY="$CANDIDATE_HASH"
fi

TIMESTAMP_FLAG="--timestamp"
if [ "$SIGN_IDENTITY" = "-" ]; then
	# 공증은 보안 타임스탬프를 요구한다. ad-hoc 은 애초에 공증 대상이 아니므로 받을
	# 이유가 없다 — 오프라인 빌드를 네트워크에 묶지 않는다.
	TIMESTAMP_FLAG="--timestamp=none"
	echo "==> DMG 서명: ad-hoc (키체인에 Developer ID Application 없음) — 이 DMG 는 공증 대상이 아니다"
else
	echo "==> DMG 서명: $IDENTITY_LINE"
fi
codesign --force --sign "$SIGN_IDENTITY" $TIMESTAMP_FLAG "$DMG_PATH"

echo "==> 서명 검증"
# DMG 는 번들이 아니라 단일 서명 대상이다 — --deep 은 중첩 코드가 있는 번들에만
# 의미가 있으므로 여기서는 쓰지 않는다.
codesign --verify --strict "$DMG_PATH"
# -E 가 필요하다 — macOS 의 기본 sed(BSD sed)는 `\|` 교차를 기본 정규식에서 지원하지
# 않는다(GNU sed 전용 확장이다). 없이 쓰면 아무 줄도 안 뽑히는 채로 조용히 넘어간다
# (실측).
codesign -dvv "$DMG_PATH" 2>&1 | sed -nE 's/^(TeamIdentifier|Timestamp)=.*/    &/p'

echo "==> 완료: $DMG_PATH"

if [ "$NOTARIZE" -eq 1 ]; then
	echo "==> 공증·스테이플 — {#dmg-notarize}"
	"$APP_DIR/Codesign/notarize.sh" "$DMG_PATH" </dev/null
else
	echo "    공증하려면: NOTARY_PROFILE=<프로파일> Codesign/notarize.sh \"$DMG_PATH\""
fi
