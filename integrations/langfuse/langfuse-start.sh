#!/usr/bin/env bash
# UserPromptSubmit 훅: /spec, /implement-issue, /review-pr 실행 시작을 Langfuse trace로 기록한다.
# 선택 기능이다 — jq/curl이 없거나, LANGFUSE_* 환경변수가 없거나, 네트워크가 실패해도
# 절대 0이 아닌 코드로 종료하지 않는다 (본 워크플로우를 절대 막지 않기 위함).

command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"

[ -z "$PROMPT" ] && exit 0
[ -z "$SESSION_ID" ] && exit 0

CMD="$(printf '%s' "$PROMPT" | awk '{print $1}')"
case "$CMD" in
  /spec) TRACE_NAME="spec"; MODEL="opus" ;;
  /implement-issue) TRACE_NAME="implement-issue"; MODEL="session" ;;
  /review-pr) TRACE_NAME="review-pr"; MODEL="opus" ;;
  *) exit 0 ;;
esac

# 이 두 값이 없으면 사용자가 Langfuse 연동을 켜지 않은 것 — 조용히 스킵
[ -z "${LANGFUSE_PUBLIC_KEY:-}" ] && exit 0
[ -z "${LANGFUSE_SECRET_KEY:-}" ] && exit 0
LANGFUSE_HOST="${LANGFUSE_HOST:-https://cloud.langfuse.com}"

REPO="unknown"
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  REPO="$(git -C "$CWD" remote get-url origin 2>/dev/null | sed -E 's#.*[/:]([^/]+/[^/]+)(\.git)?$#\1#')"
  [ -z "$REPO" ] && REPO="unknown"
fi

ARGS="$(printf '%s' "$PROMPT" | cut -d' ' -f2- )"
[ "$ARGS" = "$CMD" ] && ARGS=""

ISSUE_NUMBERS="$(printf '%s' "$ARGS" | grep -oE '[0-9]+' | jq -R . 2>/dev/null | jq -s -c . 2>/dev/null)"
[ -z "$ISSUE_NUMBERS" ] && ISSUE_NUMBERS="[]"

STATE_DIR="${TMPDIR:-/tmp}/claude-langfuse"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
{
  echo "START_EPOCH=$(date +%s)"
} > "$STATE_DIR/$SESSION_ID.env" 2>/dev/null

NOW="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
EVENT_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$SESSION_ID-start")"

BODY="$(jq -n \
  --arg id "$SESSION_ID" \
  --arg name "$TRACE_NAME" \
  --arg sessionId "$SESSION_ID" \
  --arg input "$ARGS" \
  --arg repo "$REPO" \
  --arg model "$MODEL" \
  --argjson issues "$ISSUE_NUMBERS" \
  '{id:$id, name:$name, sessionId:$sessionId, input:$input, metadata:{repo:$repo, model:$model, issue_numbers:$issues, source:"issue-template"}, tags:["claude-code",$name]}' 2>/dev/null)"

[ -z "$BODY" ] && exit 0

PAYLOAD="$(jq -n \
  --arg id "$EVENT_ID" \
  --arg ts "$NOW" \
  --argjson body "$BODY" \
  '{batch:[{id:$id, timestamp:$ts, type:"trace-create", body:$body}]}' 2>/dev/null)"

[ -z "$PAYLOAD" ] && exit 0

curl -s -m 5 -o /dev/null -X POST "$LANGFUSE_HOST/api/public/ingestion" \
  -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" >/dev/null 2>&1 || true

exit 0
