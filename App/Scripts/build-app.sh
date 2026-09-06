#!/bin/bash
#
# Polyglot.app 번들 조립 + 서명.
#
# Xcode 프로젝트 없이 `.app` 을 만든다. 판단 근거는 App/Package.swift 상단에 있다.
# 산출물 레이아웃은 Xcode 가 만드는 것과 동일하므로 codesign · notarytool · stapler ·
# ATSApplicationFontsPath 가 전부 그대로 먹는다.
#
#   Polyglot.app/Contents/
#     Info.plist
#     PkgInfo
#     MacOS/Polyglot          <- SPM 실행 산출물을 CFBundleExecutable 이름으로 복사
#     Helpers/learn-launcher  <- LearnKit 의 C 런처. 앱과 별도로 서명한다({#helper-signing}).
#     Resources/              <- App/Resources/* (Info.plist 제외). Fonts/ 가 여기 들어간다.
#
# 서명 — {#codesign-hardened-runtime} {#helper-signing}:
#   Hardened Runtime 을 켜고(`--options runtime`) App Sandbox 는 켜지 않는다
#   (`Codesign/Polyglot.entitlements` 에 `com.apple.security.app-sandbox` 키 자체가 없다).
#   개발자 인증서가 있으면 그 Team ID 로, 없으면 **ad-hoc(`-`) 으로** 앱과 헬퍼를 같은
#   신원으로 서명한다 — 어느 쪽이든 둘은 항상 같은 identity 를 쓴다. `--deep` 은 쓰지
#   않는다: 헬퍼를 먼저 개별 서명해 번들에 넣고, 그다음 바깥 `.app` 을 서명한다(중첩
#   서명을 건드리지 않는 표준 순서 — leaf 먼저, 컨테이너 나중).
#
# 공증({#notarize-staple-dmg})은 이 스크립트가 하지 않는다 — `Codesign/notarize.sh` 참고.
#
# 사용법:
#   Scripts/build-app.sh                 # debug 빌드
#   Scripts/build-app.sh --release       # release 빌드
#   Scripts/build-app.sh --run           # 빌드 후 실행
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
CONFIGURATION="debug"
RUN_AFTER=0

for arg in "$@"; do
	case "$arg" in
	--release) CONFIGURATION="release" ;;
	--debug) CONFIGURATION="debug" ;;
	--run) RUN_AFTER=1 ;;
	*)
		echo "알 수 없는 인자: $arg" >&2
		exit 2
		;;
	esac
done

# .build/ 는 .gitignore 에 이미 잡혀 있다 — 번들도 그 밑에 두어 추가 규칙이 필요 없게 한다.
BUNDLE_ROOT="$APP_DIR/.build/bundle"
APP_BUNDLE="$BUNDLE_ROOT/Polyglot.app"
CONTENTS="$APP_BUNDLE/Contents"
EXECUTABLE_NAME="Polyglot"
HELPER_NAME="learn-launcher"
ENTITLEMENTS="$APP_DIR/Codesign/Polyglot.entitlements"

echo "==> swift build ($CONFIGURATION)"
swift build --package-path "$APP_DIR" -c "$CONFIGURATION"
BIN_PATH="$(swift build --package-path "$APP_DIR" -c "$CONFIGURATION" --show-bin-path)"

echo "==> learn-launcher 빌드 (LearnKit 실행 타깃 — 앱 산출물엔 링크되지 않고 헬퍼로만 번들된다)"
swift build --package-path "$REPO_ROOT/Packages/LearnKit" --product "$HELPER_NAME" -c "$CONFIGURATION"
LAUNCHER_BIN_PATH="$(swift build --package-path "$REPO_ROOT/Packages/LearnKit" --product "$HELPER_NAME" -c "$CONFIGURATION" --show-bin-path)"

echo "==> 번들 조립: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Helpers"

cp "$BIN_PATH/PolyglotApp" "$CONTENTS/MacOS/$EXECUTABLE_NAME"
cp "$LAUNCHER_BIN_PATH/$HELPER_NAME" "$CONTENTS/Helpers/$HELPER_NAME"
cp "$APP_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
# APPL???? 는 LaunchServices 가 번들을 애플리케이션으로 인식하는 가장 오래된 신호다.
printf 'APPL????' >"$CONTENTS/PkgInfo"

# Info.plist 를 뺀 나머지 리소스(폰트 등)를 Resources 로. 아직 없을 수 있다.
for entry in "$APP_DIR"/Resources/*; do
	[ -e "$entry" ] || continue
	[ "$(basename "$entry")" = "Info.plist" ] && continue
	cp -R "$entry" "$CONTENTS/Resources/"
done

# Info.plist 를 바꾼 뒤 LaunchServices 캐시가 옛 값을 들고 있으면 창 제목·프로세스 이름이
# 어긋난다. 번들을 다시 등록해 준다.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP_BUNDLE" || true

# ── 서명 ─────────────────────────────────────────────────────────────────
#
# 개발자 인증서가 이 머신에 없을 수 있다({#codesign-hardened-runtime} 확인 사항).
# `security find-identity` 가 유효 신원을 하나도 못 찾으면 있는 척하지 않고 ad-hoc
# 으로 떨어진다 — 그 사실을 표준 출력에 남긴다.
SIGN_IDENTITY="-"
# 형식: `  1) <SHA1 40자> "<Common Name>"`. 유효 신원이 없으면 이 패턴의 줄 자체가 없다
# ("0 valid identities found" 만 남는다).
IDENTITY_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep -E '^[[:space:]]*[0-9]+\)' | head -1 || true)"
if [ -n "$IDENTITY_LINE" ]; then
	CANDIDATE_HASH="$(echo "$IDENTITY_LINE" | awk '{print $2}')"
	if [ -n "$CANDIDATE_HASH" ]; then
		SIGN_IDENTITY="$CANDIDATE_HASH"
	fi
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
	echo "==> 서명: ad-hoc (개발자 인증서 없음 — security find-identity -v -p codesigning 결과 0건)"
else
	echo "==> 서명: $IDENTITY_LINE"
fi

# 1) 헬퍼를 먼저 개별 서명한다. --deep 은 쓰지 않는다 — 이건 단일 실행 파일이라
#    상관없지만, 습관을 여기서부터 지킨다.
codesign --force --options runtime --sign "$SIGN_IDENTITY" --timestamp=none \
	"$CONTENTS/Helpers/$HELPER_NAME"

# 2) 바깥 .app 을 서명한다. 헬퍼는 이미 서명됐으므로 --deep 없이도 그 서명이 보존된다
#    (top-level 서명은 Contents/Helpers 의 이미 서명된 바이너리를 재서명하지 않고
#    CodeResources 해시로만 봉인한다).
codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
	--sign "$SIGN_IDENTITY" --timestamp=none "$APP_BUNDLE"

echo "==> 서명 검증"
codesign --verify --deep --strict "$APP_BUNDLE"
echo "    OK — codesign --verify --deep --strict 통과 (헬퍼 포함)"

echo "==> 완료: $APP_BUNDLE"

if [ "$RUN_AFTER" -eq 1 ]; then
	echo "==> 실행"
	open -n "$APP_BUNDLE"
fi
