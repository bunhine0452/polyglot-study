#!/bin/bash
#
# App/Pages/index.html 의 치환 자리를 실제 릴리스 값으로 채워 gh-pages 용 index.html 을 만든다.
#
# 랜딩 페이지가 저장소 밖(gh-pages)에만 살면 릴리스마다 다운로드 링크가 낡는다 — 실제로
# 0.1.0-alpha.1 을 올린 뒤 그 자리가 고정 문자열로 남아 있었다. 그래서 원본은 main 에 두고
# 버전·크기·레슨 수는 **산출물에서 읽어** 채운다. 사람이 세지 않는다.
#
# 사용법: Scripts/render-page.sh --version 0.2.0 --archive path/to/Polyglot-0.2.0.zip \
#           --packs Content/packs --out site/index.html
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"
VERSION=""; ARCHIVE=""; PACKS="$REPO_ROOT/Content/packs"; OUT=""

while [ $# -gt 0 ]; do
	case "$1" in
	--version) VERSION="${2:-}"; shift ;;
	--archive) ARCHIVE="${2:-}"; shift ;;
	--packs)   PACKS="${2:-}"; shift ;;
	--out)     OUT="${2:-}"; shift ;;
	*) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
	esac
	shift
done

if [ -z "$VERSION" ] || [ -z "$ARCHIVE" ] || [ -z "$OUT" ]; then
	echo "사용법: $0 --version <X.Y.Z> --archive <zip> --out <index.html> [--packs <dir>]" >&2
	exit 2
fi
[ -f "$ARCHIVE" ] || { echo "아카이브가 없다: $ARCHIVE" >&2; exit 1; }

SIZE_MB="$(python3 -c "import os,sys;print(round(os.path.getsize(sys.argv[1])/1048576))" "$ARCHIVE")"

# 레슨 요약은 매니페스트에서 읽는다. 트랙 이름은 packID 의 접미사를 그대로 쓰지 않고
# 매니페스트의 displayName 을 쓴다 — 화면에 보이는 이름과 같아야 한다.
LESSON_SUMMARY="$(python3 - "$PACKS" <<'PY'
import json, os, sys
root = sys.argv[1]
parts, total = [], 0
for name in sorted(os.listdir(root)):
    manifest = os.path.join(root, name, "manifest.json")
    if not os.path.isfile(manifest):
        continue
    d = json.load(open(manifest))
    n = len(d.get("lessons", []))
    total += n
    parts.append("%s %d편" % (d.get("displayName") or name, n))
print(" · ".join(parts) + (" (총 %d편)" % total if parts else "콘텐츠 없음"))
PY
)"

python3 - "$APP_DIR/Pages/index.html" "$OUT" "$VERSION" "$SIZE_MB" "$LESSON_SUMMARY" <<'PY'
import sys
src, out, version, size_mb, summary = sys.argv[1:6]
html = open(src, encoding="utf-8").read()
html = (html.replace("@VERSION@", version)
            .replace("@SIZE_MB@", size_mb)
            .replace("@LESSON_SUMMARY@", summary))
leftover = [t for t in ("@VERSION@", "@SIZE_MB@", "@LESSON_SUMMARY@") if t in html]
if leftover:
    sys.exit("치환되지 않은 자리가 남았다: %s" % ", ".join(leftover))
open(out, "w", encoding="utf-8").write(html)
print("    페이지    : %s (%s · %sMB · %s)" % (out, version, size_mb, summary))
PY
