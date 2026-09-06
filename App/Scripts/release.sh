#!/bin/bash
#
# 릴리스 한 번 = 앱 조립 → zip → appcast 갱신 — {#sparkle-appcast}.
#
# 이 스크립트가 끝나면 `$OUTPUT` 은 GitHub Pages 에 **그대로 올리면 되는** 디렉터리다:
#
#   App/.build/release/
#     Polyglot-0.2.0.zip
#     appcast.xml          <- 이 릴리스의 sparkle:edSignature 와 length 가 갱신돼 있다
#     old_updates/         <- generate_appcast 가 밀어낸 옛 아카이브. 올리지 않는다.
#
# 서명 키 — {#sparkle-eddsa-keys}:
#   `generate_appcast` 는 개인키를 **로그인 키체인**에서 꺼낸다(서비스
#   "https://sparkle-project.org", 계정 "ed25519"). 이 저장소에도, 이 스크립트에도,
#   환경 변수에도 개인키는 없다. 키가 없으면 generate_appcast 가 실패하고, 그때
#   `.build/artifacts/sparkle/Sparkle/bin/generate_keys` 를 한 번 돌리면 된다.
#
# 피드 URL 의 단일 출처는 `Resources/Info.plist` 의 `SUFeedURL` 이다.
#   - 다운로드 URL 접두사   = SUFeedURL 의 디렉터리
#   - appcast 파일 이름     = SUFeedURL 의 마지막 경로 요소
#   두 값을 여기서 따로 받지 않는 이유: 앱이 읽는 주소와 appcast 가 광고하는 주소가
#   어긋나면 업데이트는 "받아지긴 하는데 설치가 안 되는" 형태로 조용히 깨진다.
#   `--feed-url` 은 로컬 검증(Scripts/verify-sparkle.sh)에서만 쓴다.
#
# 사용법:
#   Scripts/release.sh --version 0.2.0
#   Scripts/release.sh --version 0.2.0 --build 42 --output /tmp/site
#   echo "$PRIVATE_KEY_SECRET" | Scripts/release.sh --version 0.2.0 --ed-key-file -
#
# 마지막 형태가 CI 용이다 — 개발자 키체인이 없는 러너에서 저장소 시크릿으로 서명한다.
# 키가 파일로도, 인자로도, 로그로도 남지 않는다(표준 입력만 탄다).
#
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHORT_VERSION=""
BUNDLE_VERSION=""
OUTPUT="$APP_DIR/.build/release"
OVERRIDE_PUBLIC_KEY=""
FEED_URL_OVERRIDE=""
PRODUCT_LINK=""
ED_KEY_FILE=""

while [ $# -gt 0 ]; do
	case "$1" in
	--version)
		SHORT_VERSION="${2:-}"
		shift
		;;
	--build)
		BUNDLE_VERSION="${2:-}"
		shift
		;;
	--output)
		OUTPUT="${2:-}"
		shift
		;;
	--feed-url)
		FEED_URL_OVERRIDE="${2:-}"
		shift
		;;
	--link)
		PRODUCT_LINK="${2:-}"
		shift
		;;
	--ed-key-file)
		ED_KEY_FILE="${2:-}"
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

if [ -z "$SHORT_VERSION" ]; then
	echo "사용법: $0 --version <X.Y.Z> [--build <N>] [--output <DIR>] [--feed-url <URL>]" >&2
	exit 2
fi

# CFBundleVersion 은 Sparkle 이 "새 버전인가" 를 판정하는 값이다. 사람이 매번 세지
# 않도록 커밋 수에서 뽑되, 저장소가 아닌 곳에서 돌 수도 있으니 실패하면 1 로 떨어진다.
if [ -z "$BUNDLE_VERSION" ]; then
	BUNDLE_VERSION="$(git -C "$APP_DIR" rev-list --count HEAD 2>/dev/null || echo 1)"
fi

SPARKLE_BIN="$APP_DIR/.build/artifacts/sparkle/Sparkle/bin"
if [ ! -x "$SPARKLE_BIN/generate_appcast" ]; then
	echo "generate_appcast 이 없다. 'swift package resolve --package-path $APP_DIR' 를 먼저 돌려라." >&2
	exit 1
fi

# ── 피드 URL ─────────────────────────────────────────────────────────────
if [ -n "$FEED_URL_OVERRIDE" ]; then
	FEED_URL="$FEED_URL_OVERRIDE"
	echo "!!  피드 URL 을 덮어썼다: $FEED_URL"
	echo "!!  이 산출물은 배포용이 아니다 — 검증용으로만 써라."
else
	FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP_DIR/Resources/Info.plist")"
fi
APPCAST_NAME="${FEED_URL##*/}"
DOWNLOAD_PREFIX="${FEED_URL%/*}/"

echo "==> 릴리스 $SHORT_VERSION (CFBundleVersion $BUNDLE_VERSION)"
echo "    피드      : $FEED_URL"
echo "    다운로드  : ${DOWNLOAD_PREFIX}Polyglot-$SHORT_VERSION.zip"

# ── 1. 앱 조립 ───────────────────────────────────────────────────────────
STAGE="$APP_DIR/.build/release-stage"
rm -rf "$STAGE"
BUILD_ARGS=(--release --version "$SHORT_VERSION" --build "$BUNDLE_VERSION" --output "$STAGE")
if [ -n "$OVERRIDE_PUBLIC_KEY" ]; then
	BUILD_ARGS+=(--public-key "$OVERRIDE_PUBLIC_KEY")
fi
# 표준 입력을 막는다 — `--ed-key-file -` 로 넘어온 키를 build-app.sh 가 삼키면 안 된다.
"$APP_DIR/Scripts/build-app.sh" "${BUILD_ARGS[@]}" </dev/null

APP_BUNDLE="$STAGE/Polyglot.app"
BUILT_PLIST="$APP_BUNDLE/Contents/Info.plist"

# EdDSA 공개키가 없는 앱은 이 피드를 영영 못 읽는다(Sparkle 이 시작 단계에서 거부한다).
# 릴리스를 굽고 나서 알면 늦다.
PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$BUILT_PLIST" 2>/dev/null || true)"
if [ -z "$PUBLIC_KEY" ]; then
	echo "조립된 번들에 SUPublicEDKey 가 없다 — Resources/Info.plist 를 확인해라." >&2
	exit 1
fi
echo "    공개키    : $PUBLIC_KEY"

# ── 2. 아카이브 ──────────────────────────────────────────────────────────
#
# Sparkle 이 기대하는 zip 형태는 `ditto -c -k --sequesterRsrc --keepParent` 다.
# `/usr/bin/zip` 은 심볼릭 링크를 따라가 버려서 Sparkle.framework 의 Versions 구조가
# 뭉개지고, 그러면 압축을 푼 앱의 코드 서명이 깨진다.
mkdir -p "$OUTPUT"
ARCHIVE="$OUTPUT/Polyglot-$SHORT_VERSION.zip"
rm -f "$ARCHIVE"
echo "==> 아카이브: $ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"

# ── 3. appcast ───────────────────────────────────────────────────────────
if [ -n "$ED_KEY_FILE" ]; then
	echo "==> appcast 생성 (개인키: --ed-key-file $ED_KEY_FILE)"
else
	echo "==> appcast 생성 (개인키는 로그인 키체인에서 읽는다)"
fi
GENERATE_ARGS=(--download-url-prefix "$DOWNLOAD_PREFIX" -o "$OUTPUT/$APPCAST_NAME")
if [ -n "$PRODUCT_LINK" ]; then
	GENERATE_ARGS+=(--link "$PRODUCT_LINK")
fi
if [ -n "$ED_KEY_FILE" ]; then
	GENERATE_ARGS+=(--ed-key-file "$ED_KEY_FILE")
fi
"$SPARKLE_BIN/generate_appcast" "${GENERATE_ARGS[@]}" "$OUTPUT"

# ── 4. 확인 ──────────────────────────────────────────────────────────────
#
# "릴리스 1회로 서명과 길이가 갱신" 이 이 항목의 완료 기준이다. 사람이 XML 을 눈으로
# 보는 대신 여기서 단언한다 — 서명이 비어 있거나 length 가 실제 파일 크기와 다르면
# 릴리스는 실패다.
python3 - "$OUTPUT/$APPCAST_NAME" "$ARCHIVE" "$SHORT_VERSION" <<'PY'
import sys, os, xml.etree.ElementTree as ET

appcast, archive, version = sys.argv[1], sys.argv[2], sys.argv[3]
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
root = ET.parse(appcast).getroot()

for item in root.iter("item"):
    short = item.findtext("sparkle:shortVersionString", namespaces=ns)
    enclosure = item.find("enclosure")
    if short != version or enclosure is None:
        continue
    signature = enclosure.get("{%s}edSignature" % ns["sparkle"]) or ""
    length = enclosure.get("length") or ""
    actual = str(os.path.getsize(archive))
    if not signature:
        sys.exit("appcast 항목 %s 에 sparkle:edSignature 가 없다." % version)
    if length != actual:
        sys.exit("appcast 의 length(%s) 가 실제 파일 크기(%s)와 다르다." % (length, actual))
    print("    확인      : %s  length=%s  edSignature=%s…(%d자)"
          % (version, length, signature[:16], len(signature)))
    print("    URL       : %s" % enclosure.get("url"))
    break
else:
    sys.exit("appcast 에 %s 항목이 없다." % version)
PY

echo "==> 완료. 이 디렉터리를 GitHub Pages 로 올려라 (old_updates/ 는 제외):"
echo "    $OUTPUT"
ls -1 "$OUTPUT"
