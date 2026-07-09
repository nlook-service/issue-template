#!/usr/bin/env bash
# issue-template 설치 겸 업데이트 스크립트.
# 대상 저장소 루트에서 실행:
#   curl -fsSL https://raw.githubusercontent.com/nlook-service/issue-template/main/install.sh | bash
# 처음 실행하면 설치, 다시 실행하면 최신본으로 업데이트된다.
# 로컬에서 수정한 파일은 덮어쓰지 않고 <파일>.new 로 받아두고 경고한다.
set -euo pipefail

REPO_RAW="${ISSUE_TEMPLATE_RAW:-https://raw.githubusercontent.com/nlook-service/issue-template/main}"
LOCK_FILE=".claude/issue-template.lock"

# 원본경로=설치경로
FILES="
github/ISSUE_TEMPLATE/ai-task.yml=.github/ISSUE_TEMPLATE/ai-task.yml
design-doc-template.md=docs/design/TEMPLATE.md
claude/commands/spec.md=.claude/commands/spec.md
claude/commands/implement-issue.md=.claude/commands/implement-issue.md
claude/commands/review-pr.md=.claude/commands/review-pr.md
claude/commands/next.md=.claude/commands/next.md
"

if [ ! -d .git ]; then
  echo "✗ git 저장소 루트가 아닙니다. 설치할 저장소의 루트에서 실행하세요." >&2
  exit 1
fi

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 전부 먼저 받아서 실패 시 아무것도 건드리지 않는다
REMOTE_VERSION="$(curl -fsSL "$REPO_RAW/VERSION" | tr -d '[:space:]')"
for pair in $FILES; do
  src="${pair%%=*}"
  mkdir -p "$TMP/$(dirname "$src")"
  curl -fsSL "$REPO_RAW/$src" -o "$TMP/$src"
done

LOCAL_VERSION=""
[ -f "$LOCK_FILE" ] && LOCAL_VERSION="$(sed -n 's/^version //p' "$LOCK_FILE")"

recorded_sha() { # $1=설치경로 → 락 파일에 기록된 sha (없으면 빈 값)
  [ -f "$LOCK_FILE" ] || return 0
  awk -v f="$1" '$2==f{print $1}' "$LOCK_FILE"
}

NEW_LOCK="$TMP/lock"
echo "version $REMOTE_VERSION" > "$NEW_LOCK"
CHANGED=0 SKIPPED=0

for pair in $FILES; do
  src="${pair%%=*}"; dest="${pair#*=}"
  new_sha="$(sha "$TMP/$src")"
  rec_sha="$(recorded_sha "$dest")"
  mkdir -p "$(dirname "$dest")"

  if [ ! -f "$dest" ]; then
    cp "$TMP/$src" "$dest"; echo "+ $dest (신규 설치)"; CHANGED=$((CHANGED+1))
  elif [ "$(sha "$dest")" = "$new_sha" ]; then
    echo "= $dest (최신)"
  elif [ -n "$rec_sha" ] && [ "$(sha "$dest")" = "$rec_sha" ]; then
    cp "$TMP/$src" "$dest"; echo "↑ $dest (업데이트)"; CHANGED=$((CHANGED+1))
  else
    # 로컬 수정 감지 — 덮어쓰지 않고 .new 로 보존
    cp "$TMP/$src" "$dest.new"
    echo "! $dest — 로컬 수정 감지, 덮어쓰지 않음 (최신본: $dest.new)"
    SKIPPED=$((SKIPPED+1))
    # 이전 기록을 유지해 로컬 수정을 되돌리면 다음 실행에서 정상 업데이트되게 한다
    if [ -n "$rec_sha" ]; then echo "$rec_sha  $dest" >> "$NEW_LOCK"; fi
    continue
  fi
  echo "$new_sha  $dest" >> "$NEW_LOCK"
done

mkdir -p "$(dirname "$LOCK_FILE")"
cp "$NEW_LOCK" "$LOCK_FILE"

# 자동 업데이트 워크플로우 — 최초 1회만 설치 (이후 팀 소유, 업데이트 대상 아님).
# GITHUB_TOKEN은 워크플로우 파일을 수정할 수 없어 CI의 자동 PR에 포함될 수 없고,
# 파일이 이미 있으면 건드리지 않으므로 CI 안에서 이 스크립트가 돌아도 안전하다.
# 원치 않으면 ISSUE_TEMPLATE_NO_WORKFLOW=1 로 건너뛴다.
WF_DEST=".github/workflows/issue-template-sync.yml"
if [ "${ISSUE_TEMPLATE_NO_WORKFLOW:-0}" != "1" ] && [ ! -f "$WF_DEST" ]; then
  mkdir -p .github/workflows
  curl -fsSL "$REPO_RAW/github/workflows/issue-template-sync.yml" -o "$WF_DEST"
  echo "+ $WF_DEST (주 1회 자동 업데이트 PR — 최초 1회 설치)"
  echo "  ⚠ 리포/조직 Settings → Actions → 'Allow GitHub Actions to create and approve pull requests' 필요"
fi

# gh CLI가 있으면 필수 라벨 생성 (gh issue create --label 이 라벨 미존재 시 실패)
if command -v gh >/dev/null 2>&1; then
  gh label create ai-task --color "1D76DB" --description "AI 위임 구현 작업" 2>/dev/null || true
fi

echo
if [ -z "$LOCAL_VERSION" ]; then
  echo "✓ issue-template v$REMOTE_VERSION 설치 완료"
elif [ "$CHANGED" -eq 0 ] && [ "$SKIPPED" -eq 0 ]; then
  echo "✓ 이미 최신입니다 (v$REMOTE_VERSION)"
else
  echo "✓ v${LOCAL_VERSION:-?} → v$REMOTE_VERSION 업데이트 완료 (변경 $CHANGED, 보류 $SKIPPED)"
fi
[ "$SKIPPED" -gt 0 ] && echo "  보류된 파일은 <파일>.new 와 비교해 수동으로 반영하세요."
echo "  커밋: git add .github docs .claude && git commit -m 'chore: issue-template v$REMOTE_VERSION'"
