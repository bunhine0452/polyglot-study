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
#     Frameworks/Sparkle.framework <- SPM 이 받아 둔 XCFramework 의 macOS 슬라이스({#sparkle-updates})
#     Resources/              <- App/Resources/* (Info.plist 제외). Fonts/ 가 여기 들어간다.
#
# Sparkle 은 SPM 바이너리 타깃이라 `swift build` 는 링크만 하고 번들에 넣어주지 않는다
# (SPM 에 "앱 번들" 개념이 없다). 여기서 직접 복사하고, Package.swift 가 실행 파일에
# `@executable_path/../Frameworks` rpath 를 박아 둔 것과 짝을 이룬다. 프레임워크 안에는
# 실행 파일이 넷 더 있다(Autoupdate · Updater.app · XPCServices 둘). 전부 개별 서명해야
# 하고, 순서는 항상 **안쪽부터**다 — 바깥을 먼저 서명하면 안쪽을 건드리는 순간 봉인이 깨진다.
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
#   Scripts/build-app.sh --version 0.2.0 --build 2   # Info.plist 버전 덮어쓰기(릴리스·검증용)
#   Scripts/build-app.sh --output DIR    # 번들을 다른 곳에 조립(한 머신에서 두 버전을 만들 때)
#   Scripts/build-app.sh --public-key <base64>  # SUPublicEDKey 덮어쓰기
#
# --public-key 는 **배포용 빌드에서 쓰지 않는다.** 두 곳에서만 필요하다:
#   (a) Scripts/verify-sparkle.sh — 개발자의 로그인 키체인을 건드리지 않고 일회용 키로
#       업데이트 왕복을 검증할 때.
#   (b) CI — 서명 키가 개발자 키체인이 아니라 저장소 시크릿에 있을 때
#       (release.sh --ed-key-file - 와 짝).
# 평소에는 Resources/Info.plist 의 값이 유일한 출처다.
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
CONFIGURATION="debug"
RUN_AFTER=0
# 빈 값이면 Resources/Info.plist 에 적힌 값을 그대로 쓴다.
OVERRIDE_SHORT_VERSION=""
OVERRIDE_BUNDLE_VERSION=""
OVERRIDE_OUTPUT=""
OVERRIDE_PUBLIC_KEY=""

while [ $# -gt 0 ]; do
	case "$1" in
	--release) CONFIGURATION="release" ;;
	--debug) CONFIGURATION="debug" ;;
	--run) RUN_AFTER=1 ;;
	--version)
		OVERRIDE_SHORT_VERSION="${2:-}"
		shift
		;;
	--build)
		OVERRIDE_BUNDLE_VERSION="${2:-}"
		shift
		;;
	--output)
		OVERRIDE_OUTPUT="${2:-}"
		shift
		;;
	--public-key)
		OVERRIDE_PUBLIC_KEY="${2:-}"
		shift
		;;
	*)
		echo "알 수 없는 인자: $1" >&2
		exit 2
		;;
	esac
	shift
done

# .build/ 는 .gitignore 에 이미 잡혀 있다 — 번들도 그 밑에 두어 추가 규칙이 필요 없게 한다.
BUNDLE_ROOT="${OVERRIDE_OUTPUT:-$APP_DIR/.build/bundle}"
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
# 버전 덮어쓰기는 **서명 전에** 해야 한다. Info.plist 는 봉인 대상이라 서명 뒤에 고치면
# 그 즉시 서명이 깨진다. 릴리스 스크립트와 Sparkle 검증 하네스가 이 두 플래그를 쓴다.
if [ -n "$OVERRIDE_SHORT_VERSION" ]; then
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $OVERRIDE_SHORT_VERSION" "$CONTENTS/Info.plist"
fi
if [ -n "$OVERRIDE_BUNDLE_VERSION" ]; then
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $OVERRIDE_BUNDLE_VERSION" "$CONTENTS/Info.plist"
fi
if [ -n "$OVERRIDE_PUBLIC_KEY" ]; then
	echo "==> SUPublicEDKey 덮어쓰기 (배포용 빌드가 아니다)"
	/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $OVERRIDE_PUBLIC_KEY" "$CONTENTS/Info.plist"
fi
# APPL???? 는 LaunchServices 가 번들을 애플리케이션으로 인식하는 가장 오래된 신호다.
printf 'APPL????' >"$CONTENTS/PkgInfo"

# Info.plist 를 뺀 나머지 리소스(폰트 등)를 Resources 로. 아직 없을 수 있다.
for entry in "$APP_DIR"/Resources/*; do
	[ -e "$entry" ] || continue
	[ "$(basename "$entry")" = "Info.plist" ] && continue
	cp -R "$entry" "$CONTENTS/Resources/"
done

# ── Sparkle.framework 임베드 — {#sparkle-updates} ────────────────────────
#
# SPM 이 받아 둔 XCFramework 에서 macOS 슬라이스만 꺼내 온다. 슬라이스 디렉터리 이름
# (`macos-arm64_x86_64`)은 Sparkle 이 어떤 아키텍처로 굽느냐에 따라 바뀔 수 있으므로
# 글롭으로 찾고, 못 찾으면 조용히 넘어가지 않고 죽는다 — 프레임워크 없이 조립된 번들은
# 실행되는 순간 dyld 에서 죽고, 그건 여기서 실패하는 것보다 훨씬 늦게 알게 된다.
SPARKLE_SLICE=""
for candidate in "$APP_DIR"/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-*/Sparkle.framework; do
	[ -d "$candidate" ] || continue
	SPARKLE_SLICE="$candidate"
	break
done
if [ -z "$SPARKLE_SLICE" ]; then
	echo "Sparkle.xcframework 의 macOS 슬라이스를 찾지 못했다. 'swift package resolve --package-path $APP_DIR' 를 먼저 돌려라." >&2
	exit 1
fi

echo "==> Sparkle 임베드: $(basename "$(dirname "$SPARKLE_SLICE")")"
mkdir -p "$CONTENTS/Frameworks"
# ditto 는 심볼릭 링크(Versions/Current, 최상위 Sparkle 등)를 링크 그대로 옮긴다.
# `cp -R` 로도 되지만 프레임워크 복사의 표준 도구는 ditto 다.
ditto "$SPARKLE_SLICE" "$CONTENTS/Frameworks/Sparkle.framework"
SPARKLE_FW="$CONTENTS/Frameworks/Sparkle.framework"
# 버전 디렉터리 이름은 Sparkle 이 정한다(현재 "B"). 심볼릭 링크에서 읽어 고정하지 않는다.
SPARKLE_VERSION_DIR="$SPARKLE_FW/Versions/$(readlink "$SPARKLE_FW/Versions/Current")"

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

EFFECTIVE_ENTITLEMENTS="$ENTITLEMENTS"
if [ "$SIGN_IDENTITY" = "-" ]; then
	echo "==> 서명: ad-hoc (개발자 인증서 없음 — security find-identity -v -p codesigning 결과 0건)"

	# ── ad-hoc + Hardened Runtime + 동적 프레임워크 = 라이브러리 검증 충돌 ──
	#
	# 실측한 사실이다. Hardened Runtime 은 **라이브러리 검증**을 함께 켠다: 프로세스에
	# 로드되는 코드는 플랫폼 바이너리이거나 **같은 Team ID** 로 서명돼 있어야 한다.
	# ad-hoc 서명에는 Team ID 가 아예 없어서, 앱과 Sparkle.framework 를 같은 명령으로
	# ad-hoc 서명해도 dyld 가 이렇게 거부하고 앱이 즉사한다:
	#
	#   Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
	#   ... code signature ... not valid for use in process:
	#       mapping process and mapped file (non-platform) have different Team IDs
	#
	# Developer ID 로 서명하면 앱과 프레임워크가 같은 Team ID 를 갖게 되므로 이 문제는
	# 사라진다. 그래서 예외는 **ad-hoc 일 때만** 넣는다 — 배포 빌드의 Hardened Runtime
	# 을 개발 편의 때문에 영구히 약화시키지 않는다.
	#
	# 이 예외가 붙은 번들은 배포용이 아니다. 공증도 통과시키지 마라.
	EFFECTIVE_ENTITLEMENTS="$BUNDLE_ROOT/Polyglot.adhoc.entitlements"
	cp "$ENTITLEMENTS" "$EFFECTIVE_ENTITLEMENTS"
	/usr/libexec/PlistBuddy \
		-c "Add :com.apple.security.cs.disable-library-validation bool true" \
		"$EFFECTIVE_ENTITLEMENTS" >/dev/null
	echo "    + com.apple.security.cs.disable-library-validation (ad-hoc 한정)"
else
	echo "==> 서명: $IDENTITY_LINE"
fi

# 1) Sparkle 안쪽부터. XPC 서비스 둘 → Autoupdate → Updater.app → 프레임워크 버전
#    디렉터리 순. `--preserve-metadata=entitlements` 가 필요한 이유: Autoupdate 는
#    `com.apple.application-identifier` entitlement 를 달고 오는데, 그냥 재서명하면
#    그게 사라진다(실측: codesign -d --entitlements 로 확인). 나머지는 entitlement 가
#    비어 있어 이 플래그가 무해하다.
for component in \
	"$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc" \
	"$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc" \
	"$SPARKLE_VERSION_DIR/Autoupdate" \
	"$SPARKLE_VERSION_DIR/Updater.app"; do
	[ -e "$component" ] || continue
	codesign --force --options runtime --preserve-metadata=entitlements \
		--sign "$SIGN_IDENTITY" --timestamp=none "$component"
done
# 버전 디렉터리를 서명한다(`Sparkle.framework` 가 아니라). 버전 있는 프레임워크에서
# 봉인 대상은 Versions/<X> 이고, 최상위는 그 안을 가리키는 심볼릭 링크 모음일 뿐이다.
codesign --force --options runtime --sign "$SIGN_IDENTITY" --timestamp=none "$SPARKLE_VERSION_DIR"

# 2) 헬퍼를 개별 서명한다. --deep 은 쓰지 않는다 — 이건 단일 실행 파일이라
#    상관없지만, 습관을 여기서부터 지킨다.
codesign --force --options runtime --sign "$SIGN_IDENTITY" --timestamp=none \
	"$CONTENTS/Helpers/$HELPER_NAME"

# 3) 바깥 .app 을 서명한다. 헬퍼·Sparkle 은 이미 서명됐으므로 --deep 없이도 그 서명이
#    보존된다 (top-level 서명은 이미 서명된 중첩 코드를 재서명하지 않고 CodeResources
#    해시로만 봉인한다).
codesign --force --options runtime --entitlements "$EFFECTIVE_ENTITLEMENTS" \
	--sign "$SIGN_IDENTITY" --timestamp=none "$APP_BUNDLE"

echo "==> 서명 검증"
codesign --verify --deep --strict "$APP_BUNDLE"
echo "    OK — codesign --verify --deep --strict 통과 (헬퍼 · Sparkle 포함)"
# rpath 가 실제로 박혔는지 확인한다. 이게 없으면 앱은 조립까지 성공하고 실행 순간 죽는다.
if ! otool -l "$CONTENTS/MacOS/$EXECUTABLE_NAME" | grep -q "@executable_path/../Frameworks"; then
	echo "실행 파일에 @executable_path/../Frameworks rpath 가 없다 — Package.swift 의 linkerSettings 를 확인해라." >&2
	exit 1
fi
echo "    OK — @executable_path/../Frameworks rpath 확인"

# ad-hoc 인데 라이브러리 검증 예외가 없으면 이 번들은 실행 순간 dyld 에서 죽는다.
# 앱을 띄워 보는 것이 가장 확실하지만 빌드마다 창이 뜨는 대가가 크다 — 대신 위에서
# 실측으로 알아낸 규칙을 서명에 대고 그대로 단언한다. 진짜 로드는
# Scripts/verify-sparkle.sh 가 앱을 실제로 띄워 확인한다.
TEAM_ID="$(codesign -dv "$APP_BUNDLE" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [ "$TEAM_ID" = "not set" ]; then
	if ! codesign -d --entitlements - --xml "$APP_BUNDLE" 2>/dev/null |
		grep -q "com.apple.security.cs.disable-library-validation"; then
		echo "Team ID 없이(ad-hoc) Hardened Runtime 을 켰는데 라이브러리 검증 예외가 없다 —" >&2
		echo "이 번들은 실행 순간 Sparkle.framework 로드에 실패한다." >&2
		exit 1
	fi
	echo "    OK — ad-hoc(Team ID 없음) + 라이브러리 검증 예외 확인"
else
	echo "    OK — Team ID $TEAM_ID 로 앱과 Sparkle 이 같은 신원"
fi

echo "==> 완료: $APP_BUNDLE"

if [ "$RUN_AFTER" -eq 1 ]; then
	echo "==> 실행"
	open -n "$APP_BUNDLE"
fi
