#!/bin/bash
#
# 릴리스 한 번 = 앱 조립 → zip → appcast 갱신 — {#sparkle-appcast}.
#
# 이 스크립트가 끝나면 `$OUTPUT` 은 GitHub Pages 에 **그대로 올리면 되는** 디렉터리다
# (DMG 는 예외 — 아래 {#dmg-notarize} 절 참고, gh-pages 가 아니라 GitHub Release 로 간다):
#
#   App/.build/release/
#     Polyglot-0.2.0.zip
#     Polyglot-0.2.0.dmg    <- 사람이 내려받는 경로. **--notarize 일 때만** 나온다
#     appcast.xml          <- 이 릴리스의 sparkle:edSignature 와 length 가 갱신돼 있다
#     old_updates/         <- generate_appcast 가 밀어낸 옛 아카이브. 올리지 않는다.
#
#   DMG 는 appcast 를 다 구운 **뒤에** 이 디렉터리로 옮겨진다({#dmg-notarize} 의 "2.5"·
#   "5" 단계) — generate_appcast 가 디렉터리를 통째로 스캔해서 안에 있는 zip·dmg 를
#   전부 업데이트 아카이브로 취급하기 때문이다(실측). 그전에 두면 같은 버전이 appcast
#   항목 두 개로 잡힌다.
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
# 공증 — {#notarize-staple-dmg}:
#   `--notarize` 를 주면 앱 조립과 아카이브 **사이**에서 `Codesign/notarize.sh` 가 돈다.
#   그 자리여야 하는 이유는 그 스크립트 헤더의 {#staple-before-zip} 에 적혀 있다.
#   기본값은 끔 — verify-sparkle.sh 의 로컬 검증을 애플 서버 왕복에 묶지 않는다.
#
#   DMG 는 `--notarize` 일 때**만** 만들어진다({#dmg-notarize}) — 실질적으로 CI 에서만.
#   DMG 는 이미 스테이플된 앱을 요구하고(make-dmg.sh 가 강제한다), 스테이플은 공증을
#   거쳐야 나오므로 공증 없이 나온 DMG 는 배포할 수 없는 물건이다. 그래서 만들지
#   않는다 — 로컬 검증 경로가 hdiutil·애플 서버 왕복을 탈 이유도 같이 사라진다.
#   앱과 DMG 는 Gatekeeper 가 검사하는 시점이 서로 다른 별개의 서명 대상이라 — 앱만
#   공증하고 DMG 컨테이너를 빼먹으면 DMG 를 여는 순간에만 경고가 뜬다.
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
NOTARIZE=0

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

if [ -z "$SHORT_VERSION" ]; then
	echo "사용법: $0 --version <X.Y.Z> [--build <N>] [--output <DIR>] [--feed-url <URL>] [--notarize]" >&2
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

	# Info.plist 의 SUFeedURL 은 **아직 아무도 소유하지 않은 추정 주소**다. 원격도
	# Pages 도 없어서 그 주소로 왕복해 본 적이 없다.
	#
	# 이 상태로 배포물을 구우면, 그 호스트를 나중에 가로챈 사람이 우리 앱의 업데이트
	# 피드를 쥔다. EdDSA 서명 검증이 있어 임의 코드를 밀어 넣지는 못하지만, 우리가
	# 서명한 **구버전으로 되돌리거나**(다운그레이드) 업데이트를 막을 수는 있다.
	#
	# 그래서 문서의 경고를 릴리스 시점의 게이트로 바꾼다. 주소를 실제로 확보한 사람이
	# 이 목록에서 호스트를 지우거나, 확인했다고 명시적으로 말해야 한다.
	# 2026-09-07: bunhine0452.github.io 로 확정했다 — 계정 소유자가 그 호스트를 쥐고
	# 있으므로 가로채기 위험이 없다. 목록은 비웠지만 기제는 남긴다. 다음에 또 확보하지
	# 않은 주소를 임시로 박게 되면 여기에 넣어라.
	UNVERIFIED_FEED_HOSTS=""
	FEED_HOST="${FEED_URL#*://}"
	FEED_HOST="${FEED_HOST%%/*}"
	for unverified in $UNVERIFIED_FEED_HOSTS; do
		if [ "$FEED_HOST" = "$unverified" ] && [ "${POLYGLOT_FEED_HOST_VERIFIED:-0}" != "1" ]; then
			echo "피드 호스트 $FEED_HOST 는 아직 확보되지 않은 추정 주소다 — 릴리스를 멈춘다." >&2
			echo "" >&2
			echo "  이 주소로 배포하면 나중에 이 호스트를 가로챈 사람이 업데이트 피드를 쥔다." >&2
			echo "  서명 검증이 임의 코드는 막지만 다운그레이드와 업데이트 차단은 막지 못한다." >&2
			echo "" >&2
			echo "  실제 주소를 확보했다면 Resources/Info.plist 의 SUFeedURL 을 그 주소로 바꾸고" >&2
			echo "  이 스크립트의 UNVERIFIED_FEED_HOSTS 에서 호스트를 지워라." >&2
			echo "  검증 목적이면 --feed-url 로 덮어쓰거나 POLYGLOT_FEED_HOST_VERIFIED=1 을 줘라." >&2
			exit 1
		fi
	done
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

# ── 1.5 공증·스테이플 — {#notarize-staple-dmg} ───────────────────────────
#
# **zip 을 만들기 전에** 해야 한다. `stapler` 는 zip 에 스테이플하지 못하고 티켓은
# .app 안으로 들어가므로, 공증이 아카이브 뒤로 밀리면 appcast 가 광고하는
# edSignature·length 가 실제 배포 파일과 어긋난다 — {#staple-before-zip}.
#
# 옵트인인 이유: `Scripts/verify-sparkle.sh` 가 이 스크립트로 검증용 릴리스를 굽는다.
# 공증을 기본값으로 두면 로컬 검증 한 번마다 애플 서버 왕복 몇 분과 자격증명이 필요해진다.
# 실제 배포(태그 푸시)에서는 release 워크플로가 항상 --notarize 를 넘긴다.
if [ "$NOTARIZE" -eq 1 ]; then
	"$APP_DIR/Codesign/notarize.sh" "$APP_BUNDLE" </dev/null
else
	echo "==> 공증 건너뜀 (--notarize 없음) — 이 산출물은 배포용이 아니다"
fi

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

# ── 2.5 DMG — {#dmg-notarize} ─────────────────────────────────────────────
#
# zip 은 Sparkle 자동 업데이트가 쓰고, DMG 는 사람이 내려받는 경로다. 둘 다 나간다 —
# 이미 위에서 공증·스테이플까지 끝난 $APP_BUNDLE 을 그대로 담으므로 앱 쪽의 순서만
# 지켜져 있으면 된다(make-dmg.sh 가 스테이플 여부를 다시 확인하고 아니면 멈춘다).
#
# DMG 컨테이너 자체도 별도로 서명·공증·스테이플해야 한다 — `stapler validate` 가
# **DMG 단독으로** 통과해야 이 항목의 완료 기준을 만족한다. 앱만 공증하고 DMG 를
# 안 하면 DMG 를 열자마자(마운트 시점) Gatekeeper 평가가 온라인 조회를 요구하고,
# 오프라인이면 거기서 막힌다.
#
# **$OUTPUT 이 아니라 별도 스테이징 디렉터리에 만든다** — 실측(2026-09-08): 아래
# `generate_appcast` 는 넘겨받은 디렉터리를 통째로 훑어 그 안의 zip·dmg 를 전부
# "업데이트 아카이브" 로 취급하고 서명까지 시도한다. DMG 를 이 시점에 $OUTPUT 에
# 두면 같은 버전의 zip 과 DMG 가 appcast 에 **항목 두 개**로 잡혀 Sparkle 피드가
# 어떤 item 을 골라야 할지 불분명해진다. appcast 를 다 구운 **뒤에** DMG 를 $OUTPUT
# 으로 옮긴다.
#
# **`--notarize` 일 때만 만든다** — 즉 실질적으로 CI 에서만. DMG 는 스테이플된 앱을
# 요구하고(make-dmg.sh 가 강제한다), 스테이플은 공증을 거쳐야 나온다. 공증 없이
# 만든 DMG 는 배포할 수 없는 물건이라 만들 이유가 없다. 덕분에 로컬 검증 경로
# (verify-sparkle.sh 처럼 --notarize 없이 도는 것들)는 hdiutil 왕복을 타지 않는다.
DMG_STAGE=""
if [ "$NOTARIZE" -eq 1 ]; then
	echo "==> DMG 조립"
	DMG_STAGE="$APP_DIR/.build/release-dmg-stage"
	rm -rf "$DMG_STAGE"
	"$APP_DIR/Scripts/make-dmg.sh" "$APP_BUNDLE" \
		--version "$SHORT_VERSION" --output "$DMG_STAGE" --notarize </dev/null
else
	echo "==> DMG 건너뜀 (--notarize 없음) — 공증 없는 DMG 는 배포물이 아니다"
fi

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

# ── 5. DMG 를 산출물 디렉터리로 ─────────────────────────────────────────────
#
# appcast 를 다 구운 뒤에야 옮긴다 — {#dmg-notarize} 위 "2.5 DMG" 절의 이유 그대로,
# generate_appcast 가 스캔을 끝낸 다음이라 더는 DMG 를 업데이트 아카이브로 착각할
# 일이 없다.
if [ -n "$DMG_STAGE" ]; then
	DMG_PATH="$OUTPUT/Polyglot-$SHORT_VERSION.dmg"
	mv "$DMG_STAGE/Polyglot-$SHORT_VERSION.dmg" "$DMG_PATH"
	rm -rf "$DMG_STAGE"
	echo "==> DMG: $DMG_PATH"
fi

echo "==> 완료. 이 디렉터리를 GitHub Pages 로 올려라 (old_updates/ 와 *.dmg 는 제외):"
echo "    $OUTPUT"
if [ -n "$DMG_STAGE" ]; then
	echo "    DMG($DMG_PATH)는 gh-pages 가 아니라 GitHub Release 자산으로 올려라 —"
	echo "    Sparkle 피드는 zip 만 가리키므로 DMG 를 gh-pages 이력에 반복해서 올릴 이유가 없다."
fi
ls -1 "$OUTPUT"
