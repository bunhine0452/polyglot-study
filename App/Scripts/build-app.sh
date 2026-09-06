#!/bin/bash
#
# Polyglot.app 번들 조립.
#
# Xcode 프로젝트 없이 `.app` 을 만든다. 판단 근거는 App/Package.swift 상단에 있다.
# 산출물 레이아웃은 Xcode 가 만드는 것과 동일하므로 codesign · notarytool · stapler ·
# ATSApplicationFontsPath 가 전부 그대로 먹는다.
#
#   Polyglot.app/Contents/
#     Info.plist
#     PkgInfo
#     MacOS/Polyglot          <- SPM 실행 산출물을 CFBundleExecutable 이름으로 복사
#     Resources/              <- App/Resources/* (Info.plist 제외). Fonts/ 가 여기 들어간다.
#
# 사용법:
#   Scripts/build-app.sh                 # debug 빌드
#   Scripts/build-app.sh --release       # release 빌드
#   Scripts/build-app.sh --run           # 빌드 후 실행
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

echo "==> swift build ($CONFIGURATION)"
swift build --package-path "$APP_DIR" -c "$CONFIGURATION"
BIN_PATH="$(swift build --package-path "$APP_DIR" -c "$CONFIGURATION" --show-bin-path)"

echo "==> 번들 조립: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN_PATH/PolyglotApp" "$CONTENTS/MacOS/$EXECUTABLE_NAME"
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

# 애드혹 서명. 배포 서명({#codesign-hardened-runtime})은 별도지만, 서명이 아예 없으면
# 로컬 실행에서도 TCC 프롬프트와 캐시 문제가 생긴다.
codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null 2>&1 || {
	echo "경고: 애드혹 서명 실패 — 실행은 되지만 권한 프롬프트가 반복될 수 있다" >&2
}

echo "==> 완료: $APP_BUNDLE"

if [ "$RUN_AFTER" -eq 1 ]; then
	echo "==> 실행"
	open -n "$APP_BUNDLE"
fi
