#!/bin/bash
#
# 공증·스테이플 자리 — {#notarize-staple-dmg}.
#
# **의도적으로 실행하지 않는다.** 공증에는 Apple Developer 계정(App Store Connect
# API 키 또는 애플 ID + 앱 암호)이 필요한데, 이 워크트리에는 개발자 인증서 자체가
# 없다 — `security find-identity -v -p codesigning` 결과 0건, 그래서
# `Scripts/build-app.sh` 는 ad-hoc 서명으로 떨어진다(그 스크립트 헤더 참고). 계정이
# 생겼을 때 이 스크립트를 채우는 순서만 여기 고정해 둔다. 지금은 안내만 찍고 종료한다.
#
# 사용법(계정이 생긴 뒤):
#   Scripts/build-app.sh --release
#   Codesign/notarize.sh /path/to/.build/bundle/Polyglot.app /path/to/Polyglot.dmg
#
# Sparkle 이 들어온 뒤 바뀐 것 — {#sparkle-updates}:
#   번들 안에 서명 대상 실행 파일이 넷 늘었다(Sparkle.framework 안의 Autoupdate ·
#   Updater.app · XPCServices 둘). `Scripts/build-app.sh` 가 안쪽부터 전부 서명하므로
#   여기서 따로 할 일은 없다. 다만 개발자 인증서가 생기면 두 가지가 자동으로 달라진다:
#
#   1. build-app.sh 가 ad-hoc 경로에서만 붙이던
#      `com.apple.security.cs.disable-library-validation` 이 **사라진다**. ad-hoc 에는
#      Team ID 가 없어 Hardened Runtime 의 라이브러리 검증이 Sparkle.framework 로드를
#      막기 때문에 넣었던 예외이고, Developer ID 로 앱과 프레임워크를 같은 신원으로
#      서명하면 필요 없다. 공증에 제출하는 번들에 이 예외가 남아 있으면 안 된다.
#   2. `--timestamp=none` 을 **`--timestamp` 으로 바꿔야 한다.** 공증은 보안 타임스탬프를
#      요구한다. 지금 껐던 이유는 인증서가 없어 타임스탬프 서버에 갈 이유가 없어서다.
#
set -euo pipefail

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
	echo "사용법: $0 <APP_BUNDLE> <DMG_PATH>" >&2
	exit 2
fi

echo "notarize.sh 는 스텁이다 — 개발자 계정이 없어 실행하지 않는다. 아래는 채워 넣을 순서다." >&2
exit 1

# ── 계정이 생기면 위 exit 1 을 지우고 아래를 채운다 ──────────────────────────
#
# APP_BUNDLE="$1"
# DMG_PATH="$2"
# DEVELOPER_ID_IDENTITY="Developer ID Application: <이름> (<TEAM_ID>)"
# NOTARY_PROFILE="polyglot-notary"
#
# 1) 자격증명은 notarytool 키체인 프로파일로 **한 번만** 저장한다 — {#notary-credentials}.
#    애플 ID·앱 암호·API 키가 이 스크립트·로그·셸 히스토리 어디에도 리터럴로 남지
#    않는다. 이후 모든 호출은 프로파일 이름(NOTARY_PROFILE)만 쓴다.
#      xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#        --apple-id "<Apple ID>" --team-id "<TEAM_ID>" --password "<앱 암호>"
#
# 2) DMG 자체도 서명한다 — {#dmg-notarize}. 앱만 서명하고 DMG 컨테이너를 안 하면
#    `stapler validate` 가 DMG 단독으로는 통과하지 않는다.
#      codesign --force --sign "$DEVELOPER_ID_IDENTITY" --timestamp "$DMG_PATH"
#
# 3) 제출 — --wait 로 심사 완료까지 블록. 몇 분 걸릴 수 있다.
#      xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
#
# 4) 스테이플 — 앱과 DMG 양쪽 다. 네트워크 격리 환경에서 Gatekeeper 가 온라인 조회
#    없이 통과하려면 필수다.
#      xcrun stapler staple "$APP_BUNDLE"
#      xcrun stapler staple "$DMG_PATH"
#
# 5) 검증 — 진짜 테스트는 네트워크 끊긴 다른 맥이지만, 로컬에서는 이 정도로 확인한다.
#      spctl --assess --type execute -vv "$APP_BUNDLE"
#      xcrun stapler validate "$DMG_PATH"
