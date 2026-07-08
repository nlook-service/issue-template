#!/usr/bin/env bash
# Stop 훅: langfuse-start.sh가 시작한 trace를 종료 상태(duration 등)로 업데이트한다.
# 선택 기능이다 — 어떤 이유로든 실패해도 절대 0이 아닌 코드로 종료하지 않는다.

command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
STOP_HOOK_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"

[ -z "$SESSION_ID" ] && exit 0
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

[ -z "${LANGFUSE_PUBLIC_KEY:-}" ] && exit 0
[ -z "${LANGFUSE_SECRET_KEY:-}" ] && exit 0
LANGFUSE_HOST="${LANGFUSE_HOST:-https://cloud.langfuse.com}"

STATE_FILE="${TMPDIR:-/tmp}/claude-langfuse/$SESSION_ID.env"
[ -f "$STATE_FILE" ] || exit 0   # /spec 등으로 시작하지 않은 세션이면 스킵

START_EPOCH="$(grep '^START_EPOCH=' "$STATE_FILE" | cut -d= -f2)"
rm -f "$STATE_FILE" 2>/dev/null

DURATION_MS=0
if [ -n "$START_EPOCH" ]; then
  END_EPOCH="$(date +%s)"
  DURATION_MS=$(( (END_EPOCH - START_EPOCH) * 1000 ))
fi

NOW="$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
EVENT_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$SESSION_ID-end")"

BODY="$(jq -n \
  --arg id "$SESSION_ID" \
  --argjson duration "$DURATION_MS" \
  '{id:$id, output:"completed", metadata:{duration_ms:$duration}}' 2>/dev/null)"

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
