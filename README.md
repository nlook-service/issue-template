# issue-template

AI 위임 개발 워크플로우 템플릿 — **상위 모델이 설계하고, 실행 모델이 구현하는** 팀을 위한 설계문서 + GitHub 이슈 폼.

```
상위 모델(설계·리뷰)          실행 모델(구현)
      │                          │
  설계문서 작성 ──▶ 이슈 분해 ──▶ 이슈 단위 구현 ──▶ PR
      │                                            │
      └────────────── 설계문서 대비 리뷰 ◀──────────┘
```

## 왜 필요한가

AI에게 구현을 맡길 때 실패하는 원인은 대부분 지시 문서에 있다:

- **상상으로 쓴 설계** — 존재하지 않는 함수를 참조하거나 실제 데이터 구조와 다른 스키마를 가정
- **범위 미지정** — "겸사겸사" 리팩토링하다 diff가 폭발 (scope creep)
- **모호한 완료 기준** — "잘 동작해야 함"은 AI가 스스로 검증할 수 없다

이 템플릿은 세 가지를 구조적으로 강제한다: **검증된 코드 앵커**, **Non-goals 명시**, **실행 가능한 검증 명령어**.

## 구성 파일

| 파일 | 용도 | 사용 시점 |
|---|---|---|
| `design-doc-template.md` | 상위 설계문서 | 기능 하나 설계할 때마다 |
| `github/ISSUE_TEMPLATE/ai-task.yml` | 구현 이슈 폼 | 설계문서의 이슈 분해 항목 하나당 이슈 1개 |

## 다른 저장소에 적용하기

### 방법 1 — 원라이너 (권장)

대상 저장소 루트에서:

```bash
mkdir -p .github/ISSUE_TEMPLATE docs/design
curl -fsSL https://raw.githubusercontent.com/nlook-service/issue-template/main/github/ISSUE_TEMPLATE/ai-task.yml \
  -o .github/ISSUE_TEMPLATE/ai-task.yml
curl -fsSL https://raw.githubusercontent.com/nlook-service/issue-template/main/design-doc-template.md \
  -o docs/design/TEMPLATE.md
git add .github docs/design && git commit -m "chore: AI 위임 워크플로우 템플릿 추가"
```

커밋 후 GitHub의 **New Issue** 화면에 "AI 구현 작업" 폼이 나타난다.

### 방법 2 — clone 후 복사

```bash
git clone https://github.com/nlook-service/issue-template.git /tmp/issue-template
cp /tmp/issue-template/github/ISSUE_TEMPLATE/ai-task.yml <repo>/.github/ISSUE_TEMPLATE/
cp /tmp/issue-template/design-doc-template.md <repo>/docs/design/TEMPLATE.md
```

## 사용 순서

1. **설계** — 상위 모델(Claude Fable/Opus 등)에게:
   > "관련 코드를 먼저 읽고 검증한 뒤 `docs/design/<기능명>.md`를 TEMPLATE.md 양식으로 작성해줘."

   설계문서 2번 섹션 "현재 상태 (검증됨)"의 파일:라인 근거가 실제 코드와 일치하는지 확인한다. 이게 이 워크플로우의 핵심 방어선이다.

2. **분해·등록** — 설계문서 6번 섹션의 이슈를 등록한다. **이슈 1개 = AI 세션 1개에서 끝나는 크기.** 애매하면 더 잘게.

   ```bash
   gh issue create --label ai-task --title "[Task] refresh 토큰 갱신 로직" --body-file issue-body.md
   ```

3. **구현** — 실행 모델(Sonnet 등)에게 이슈를 하나씩 위임한다. 이슈에 검증 명령어가 포함되어 있어 AI가 자가 확인하며 작업한다.

4. **리뷰** — 구현 PR을 상위 모델에게 **설계문서 대비**로 리뷰시킨다. 루프가 닫힌다.

## 이슈 폼 필드 요약

| 필드 | 필수 | 목적 |
|---|---|---|
| 목표 | ✅ | 구현 중 판단이 갈릴 때의 기준 |
| 하지 말 것 (Non-goals) | ✅ | scope creep 차단 |
| 코드 앵커 | ✅ | 파일:라인 단위 정확한 작업 위치 |
| 인터페이스 계약 | | 시그니처/스키마를 코드로 — 산문 금지 |
| 완료 기준 + 검증 명령어 | ✅ | AI가 스스로 실행해 통과 확인 |
| 엣지 케이스 | | 설계 단계에서 내린 결정 명시 |
| 의존성 | | 선행 이슈, 설계문서 링크 |

## 커스터마이징

- 라벨(`ai-task`), 제목 접두어(`[Task]`)는 `ai-task.yml` 상단에서 팀 컨벤션에 맞게 수정
- 조직 전체 기본 템플릿으로 쓰려면 조직의 `.github` 저장소에 넣으면 모든 repo에 상속된다
