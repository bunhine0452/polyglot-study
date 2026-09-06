#!/usr/bin/env bash
#
# 러너의 Swift 가 이 저장소를 빌드할 수 있는지 **먼저** 단언한다.
#
# 왜 필요한가: 세 패키지가 모두 `swift-tools-version: 6.2` 다. 러너 이미지의 기본
# 툴체인이 그보다 낮으면 SwiftPM 이 "package is using Swift tools version 6.2.0 but the
# installed version is 5.10.0" 로 죽는데, 그 메시지는 잡 로그 한복판에 묻힌다.
# 실측(2026-09-07): macos-14 → 5.10, macos-15 → 6.1.2, macos-26 → 6.3.3.
# 이미지가 뒤로 가거나 라벨을 잘못 바꾸면 여기서 한 줄로 멈춘다.
set -euo pipefail

REQUIRED_MAJOR=6
REQUIRED_MINOR=2

raw="$(swift --version 2>&1)"
version="$(printf '%s' "$raw" | sed -n 's/.*Apple Swift version \([0-9][0-9.]*\).*/\1/p' | head -1)"
if [ -z "$version" ]; then
	echo "swift --version 에서 버전을 읽지 못했다:" >&2
	printf '%s\n' "$raw" >&2
	exit 1
fi

major="${version%%.*}"
rest="${version#*.}"
minor="${rest%%.*}"
[ "$minor" = "$rest" ] && [ "$minor" = "$version" ] && minor=0

if [ "$major" -lt "$REQUIRED_MAJOR" ] ||
	{ [ "$major" -eq "$REQUIRED_MAJOR" ] && [ "$minor" -lt "$REQUIRED_MINOR" ]; }; then
	echo "Swift ${version} 는 이 저장소를 빌드할 수 없다 — swift-tools-version 6.2 가 필요하다." >&2
	echo "러너 이미지를 확인하라. macos-26 이 6.3.3, macos-15 는 6.1.2, macos-14 는 5.10 이다." >&2
	ls -d /Applications/Xcode*.app 2>/dev/null >&2 || true
	exit 1
fi

echo "==> Swift ${version} (요구: ${REQUIRED_MAJOR}.${REQUIRED_MINOR}+)"
