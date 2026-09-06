#!/bin/bash
#
# PR 게이트 1/3 — LearnKit·Tools 전체 스위트.
#
# 두 패키지를 한 게이트로 묶는 이유는 의존 방향이다 — Tools → LearnKit 단방향이라
# LearnKit 이 깨지면 Tools 는 그 위에서 아무 의미가 없다. 반대로 Tools 만 깨질 수도
# 있으니(예: packtool CLI 표면) 순서대로 둘 다 돈다. 하나로 합쳐 두면 CI 쪽에
# "필수 체크"가 하나만 생겨 브랜치 보호 설정이 늘어나지 않는다.
#
# 실행 위치는 상관없다 — 이 스크립트 자체가 레포 루트를 찾는다.
#
# 사용법:
#   scripts/ci-run-swift-tests.sh
#
# 종료 코드: swift test 그대로 전달한다(0 통과, 그 외 실패).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> swift test --package-path Packages/LearnKit"
swift test --package-path "$REPO_ROOT/Packages/LearnKit"

echo "==> swift test --package-path Tools"
swift test --package-path "$REPO_ROOT/Tools"

echo "==> 통과 — LearnKit + Tools"
