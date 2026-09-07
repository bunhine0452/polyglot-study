#!/bin/bash
#
# PR 게이트 3/3 — 콘텐츠 팩 검증 (`packtool validate`).
#
# 팩을 건드리지 않는 PR 에서도 이 잡은 항상 돈다(브랜치 보호가 요구하는 필수
# 체크를 workflow paths 필터로 걸면, 그 필터에 안 걸리는 PR 은 체크가 영영
# "대기 중"으로 남아 머지가 막힌다 — GitHub Actions 의 알려진 함정이다). 대신 이
# 스크립트가 직접 diff 를 봐서 packs 변경이 없으면 빠르게 통과한다. 즉 "필수 체크"인
# 것과 "packs 변경 PR 에서만 실제로 게이트가 선다"는 것이 동시에 성립한다.
#
# 툴체인 부재 시 정책은 packtool 쪽 기본값을 그대로 따른다 — **스킵이 아니라 실패**.
# 이 스크립트는 --allow-missing-toolchain 을 기본으로 넘기지 않는다. 그 플래그를
# 켜는 것은 호출자의 명시적 선택이어야 하고(ALLOW_MISSING_TOOLCHAIN=1 또는
# --allow-missing-toolchain), 그렇게 켠 실행은 필수 체크로 세면 안 된다 — 구조·문법
# 단계만 돈 것을 "통과"로 착각하게 만들기 때문이다. docs/ci.md 참고.
#
# 사용법:
#   scripts/ci-validate-packs.sh                       # PR_BASE_SHA 로 변경 팩 탐지, 없으면 전체 (packs + fixtures)
#   scripts/ci-validate-packs.sh Content/packs/foo bar  # 명시한 팩만 검증 (로컬 점검용)
#   ALLOW_MISSING_TOOLCHAIN=1 scripts/ci-validate-packs.sh ...   # 실행 게이트를 건너뛴다(필수 체크 금지)
#
# 환경 변수:
#   PR_BASE_SHA             PR 베이스 커밋. 있으면 그 이후 Content/packs/ 변경만 찾는다.
#                            찾을 수 없는 ref 면 안전 측으로 전체 팩을 검증한다.
#   ALLOW_MISSING_TOOLCHAIN 1 이면 packtool 에 --allow-missing-toolchain 을 넘긴다.
#   JUNIT_OUT_DIR            팩별 JUnit 리포트를 쓸 디렉터리. 기본 .build/ci-reports/packtool.
#
# 종료 코드: 0 통과(또는 검증 대상 없음) · 1 팩 검증 실패 1개 이상 · 2 도구/스크립트 오류.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/Tools"
# 검증 대상 루트 둘. `Content/packs` 는 앱이 번들하는 콘텐츠이고,
# `Content/fixtures` 는 팩 포맷 스펙을 고정하는 픽스처다(배포되지 않는다).
# 둘 다 게이트를 통과해야 한다 — 픽스처가 깨지면 스펙 문서가 거짓이 된다.
PACK_ROOTS=("$REPO_ROOT/Content/packs" "$REPO_ROOT/Content/fixtures")
JUNIT_OUT_DIR="${JUNIT_OUT_DIR:-$REPO_ROOT/.build/ci-reports/packtool}"

allow_missing_toolchain=0
[ "${ALLOW_MISSING_TOOLCHAIN:-0}" = "1" ] && allow_missing_toolchain=1

explicit_packs=()
for arg in "$@"; do
	case "$arg" in
	--allow-missing-toolchain) allow_missing_toolchain=1 ;;
	-*)
		echo "packtool-validate: 알 수 없는 인자: $arg" >&2
		exit 2
		;;
	*) explicit_packs+=("$arg") ;;
	esac
done

if [ "$allow_missing_toolchain" -eq 1 ]; then
	echo "!! --allow-missing-toolchain 켜짐 — 실행 게이트를 건너뛴다. 이 실행은 필수 체크로 쓰면 안 된다." >&2
fi

discover_all_packs() {
	local root dir
	for root in "${PACK_ROOTS[@]}"; do
		for dir in "$root"/*/; do
			[ -f "${dir}manifest.json" ] || continue
			printf '%s\n' "${dir%/}"
		done
	done
}

# PR 베이스 이후 Content/packs/ · Content/fixtures/ 아래에서 바뀐 파일들을 팩 루트 단위로 접는다.
# 매칭되는 게 하나도 없으면 센티널 "__NONE__" 한 줄만 찍는다(빈 출력과 "탐지
# 자체를 못 함"을 구별하기 위해서다).
discover_changed_packs() {
	local base="$1" changed
	if ! git -C "$REPO_ROOT" rev-parse --verify "${base}^{commit}" >/dev/null 2>&1; then
		echo "packtool-validate: PR_BASE_SHA(${base}) 를 이 체크아웃에서 찾을 수 없다 — 안전하게 전체 팩을 검증한다" >&2
		discover_all_packs
		return
	fi
	changed="$(git -C "$REPO_ROOT" diff --name-only "${base}...HEAD" -- Content/packs Content/fixtures 2>/dev/null)"
	if [ -z "$changed" ]; then
		echo "__NONE__"
		return
	fi
	printf '%s\n' "$changed" \
		| awk -F/ 'NF>=3 {print $1"/"$2"/"$3}' \
		| sort -u \
		| while read -r rel; do
			[ -f "$REPO_ROOT/$rel/manifest.json" ] && printf '%s\n' "$REPO_ROOT/$rel"
		done
}

pack_dirs=()
if [ "${#explicit_packs[@]}" -gt 0 ]; then
	for p in "${explicit_packs[@]}"; do
		case "$p" in
		/*) pack_dirs+=("$p") ;;
		*) pack_dirs+=("$REPO_ROOT/$p") ;;
		esac
	done
elif [ -n "${PR_BASE_SHA:-}" ]; then
	while IFS= read -r line; do
		[ "$line" = "__NONE__" ] && { pack_dirs=(); break; }
		[ -n "$line" ] && pack_dirs+=("$line")
	done < <(discover_changed_packs "$PR_BASE_SHA")
	if [ "${#pack_dirs[@]}" -eq 0 ]; then
		echo "==> PR_BASE_SHA=$PR_BASE_SHA 이후 콘텐츠 팩 변경 없음 — 검증 생략"
		exit 0
	fi
else
	while IFS= read -r line; do
		[ -n "$line" ] && pack_dirs+=("$line")
	done < <(discover_all_packs)
fi

if [ "${#pack_dirs[@]}" -eq 0 ]; then
	echo "==> 검증할 팩이 없다 (Content/{packs,fixtures}/*/manifest.json 없음)"
	exit 0
fi

mkdir -p "$JUNIT_OUT_DIR"

# ── learn-launcher 를 먼저 굽는다 ──────────────────────────────────────────
#
# `swift build --package-path Tools` 는 런처를 만들지 않는다. 런처는 LearnKit 의
# 실행 타깃이고 Tools 의 의존성 그래프 밖이라, packtool 만 빌드하면 Swift·Python 블록의
# 실행 게이트가 통째로 "실행 게이트를 태울 수 없다" 로 죽는다.
#
# 로컬에서는 개발자가 LearnKit 을 이미 빌드해 뒀기 때문에 이 구멍이 안 보인다.
# 실제 CI 러너에서 Swift 팩 36건 실패로 처음 드러났다(2026-09-07). SQL 팩은 인프로세스
# 러너라 런처가 필요 없어 같은 실행에서 통과했고, 그 대비가 원인을 바로 가리켰다.
if [ "$allow_missing_toolchain" -eq 0 ]; then
	echo "==> learn-launcher 빌드 (Tools 빌드로는 안 만들어진다)"
	swift build --package-path "$REPO_ROOT/Packages/LearnKit" --product learn-launcher
fi

validate_flags=(--report junit)
[ "$allow_missing_toolchain" -eq 1 ] && validate_flags+=(--allow-missing-toolchain)

failed_packs=()
tool_errors=()
tool_error=0

for dir in "${pack_dirs[@]}"; do
	if [ ! -d "$dir" ]; then
		echo "packtool-validate: 팩 디렉터리가 아니다: $dir" >&2
		tool_error=1
		tool_errors+=("$dir")
		continue
	fi
	pack_id="$(basename "$dir")"
	junit_path="$JUNIT_OUT_DIR/${pack_id}.xml"
	echo "==> packtool validate $dir"
	if swift run --package-path "$TOOLS_DIR" packtool validate "$dir" \
		"${validate_flags[@]}" -o "$junit_path"; then
		echo "    통과 — 리포트: $junit_path"
	else
		code=$?
		if [ "$code" -eq 2 ]; then
			echo "    도구 오류(exit 2) — $dir" >&2
			tool_error=1
		else
			echo "    실패(exit $code) — 리포트: $junit_path" >&2
			failed_packs+=("$pack_id")
		fi
	fi
done

echo
echo "==> 요약: 대상 ${#pack_dirs[@]}개 — 검증 실패 ${#failed_packs[@]}개, 도구 오류 ${#tool_errors[@]}개"
for p in "${failed_packs[@]:-}"; do
	[ -n "$p" ] && echo "  실패: $p"
done
for p in "${tool_errors[@]:-}"; do
	[ -n "$p" ] && echo "  도구 오류: $p"
done

if [ "$tool_error" -eq 1 ]; then
	exit 2
fi
if [ "${#failed_packs[@]}" -gt 0 ]; then
	exit 1
fi
exit 0
