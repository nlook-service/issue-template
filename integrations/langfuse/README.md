# Langfuse 연동 (선택 사항)

`/spec`, `/implement-issue`, `/review-pr` 실행을 [Langfuse](https://langfuse.com)에 이름 있는 trace로 남깁니다.
**기본 설치에는 포함되지 않으며, 명시적으로 켜야만 동작합니다.**

## ⚠️ 켜기 전에 반드시 확인할 것

- 이 훅을 켜면 커맨드에 넘긴 **인자 전체(요구사항 설명, 이슈 번호 등)가 Langfuse Cloud(미국 호스팅 제3자 SaaS)로 전송**됩니다. 요구사항 설명에 내부 비즈니스 로직·민감정보가 들어갈 수 있다면 팀 정책상 문제가 없는지 먼저 확인하세요.
- 자체 호스팅 Langfuse를 쓰면 `LANGFUSE_HOST`를 자체 서버 주소로 지정해 외부 전송을 피할 수 있습니다.
- `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` 환경변수가 없으면 훅은 아무 일도 하지 않고 즉시 종료됩니다(기존 워크플로우에 영향 없음).
- `jq`/`curl`이 없거나 네트워크가 실패해도 훅은 항상 종료 코드 0으로 조용히 넘어갑니다 — Langfuse 문제로 `/spec` 등 본 기능이 막히는 일은 없습니다.

## 기록되는 내용

| 필드 | 값 |
|---|---|
| trace name | `spec` / `implement-issue` / `review-pr` |
| sessionId | Claude Code 세션 ID |
| input | 커맨드에 넘긴 인자 (요구사항 설명, 이슈 번호 등) |
| metadata.repo | `git remote get-url origin` 기준 `owner/repo` |
| metadata.model | 해당 커맨드의 고정 모델 (`opus`/`sonnet`) |
| metadata.issue_numbers | 인자에서 추출한 숫자들 (이슈 번호로 추정) |
| output / metadata.duration_ms | 세션 종료(Stop 훅) 시 기록되는 소요 시간 |

## 설치 (대상 저장소 루트에서, 이미 `/spec` 등 기본 설치가 끝난 상태 기준)

```bash
REPO_RAW=https://raw.githubusercontent.com/nlook-service/issue-template/main

mkdir -p .claude/hooks
curl -fsSL $REPO_RAW/integrations/langfuse/langfuse-start.sh -o .claude/hooks/langfuse-start.sh
curl -fsSL $REPO_RAW/integrations/langfuse/langfuse-end.sh   -o .claude/hooks/langfuse-end.sh
chmod +x .claude/hooks/langfuse-start.sh .claude/hooks/langfuse-end.sh
```

`.claude/settings.json`(없으면 새로 생성, 있으면 `hooks` 블록만 수동으로 병합)에 아래 내용을 추가합니다:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash .claude/hooks/langfuse-start.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash .claude/hooks/langfuse-end.sh" }] }
    ]
  }
}
```

> 이미 `hooks.UserPromptSubmit` / `hooks.Stop`이 있다면 **덮어쓰지 말고 배열에 위 항목을 추가**하세요.

마지막으로 셸 프로필(`~/.zshrc` 등) 또는 팀 시크릿 매니저를 통해 아래 환경변수를 설정해야 실제로 전송이 시작됩니다:

```bash
export LANGFUSE_PUBLIC_KEY="pk-lf-..."
export LANGFUSE_SECRET_KEY="sk-lf-..."
# 자체 호스팅이면:
# export LANGFUSE_HOST="https://langfuse.yourcompany.com"
```

## 요구 사항

- `jq`, `curl` (둘 중 하나라도 없으면 훅은 자동으로 비활성화됩니다)
- Langfuse Cloud 계정 또는 자체 호스팅 인스턴스

## 끄는 법

`.claude/settings.json`의 `hooks.UserPromptSubmit`/`hooks.Stop`에서 `langfuse-start.sh`/`langfuse-end.sh` 항목을 지우거나, `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` 환경변수를 unset 하면 됩니다.
