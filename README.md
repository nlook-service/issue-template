# AI 위임 워크플로우 템플릿

Fable 5(설계) → GitHub 이슈 → Sonnet(구현) 워크플로우용 템플릿.

## 파일

- `design-doc-template.md` — 상위 설계문서. 기능 하나당 하나. Fable 5와 함께 작성.
- `github/ISSUE_TEMPLATE/ai-task.yml` — 구현 이슈 폼. 설계문서의 "이슈 분해" 항목 하나당 이슈 하나.

## 저장소에 설치

```bash
# 이슈 템플릿 (저장소마다 1회)
mkdir -p <repo>/.github/ISSUE_TEMPLATE
cp ~/templates/github/ISSUE_TEMPLATE/ai-task.yml <repo>/.github/ISSUE_TEMPLATE/

# 설계문서 (기능 설계할 때마다)
mkdir -p <repo>/docs/design
cp ~/templates/design-doc-template.md <repo>/docs/design/<기능명>.md
```

커밋 후 GitHub의 New Issue 화면에 "AI 구현 작업" 폼이 나타난다.

## 사용 순서

1. **설계** — Fable 5에게: "관련 코드를 먼저 읽고 검증한 뒤 `docs/design/<기능명>.md`를 이 템플릿으로 작성해줘." (2번 섹션의 파일:라인 근거가 실제 코드와 일치하는지 확인)
2. **분해** — 설계문서 6번 섹션의 이슈를 `gh issue create`나 웹 폼으로 등록. 이슈 하나 = 세션 하나 크기.
3. **구현** — Sonnet에게 이슈 하나씩 위임. 이슈에 검증 명령어가 있으므로 자가 확인 가능.
4. **리뷰** — Sonnet의 PR을 Fable 5에게 설계문서 대비로 리뷰시킴.

## CLI로 이슈 등록 예시

```bash
gh issue create --label ai-task --title "[Task] refresh 토큰 갱신 로직" --body-file issue-body.md
```
