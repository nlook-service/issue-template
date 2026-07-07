# issue-template

AI 위임 개발 워크플로우 — **상위 모델이 설계하고, 실행 모델이 구현하는** 팀을 위한 템플릿 + Claude Code 슬래시 커맨드 세트.

```
[설계 세션: Opus/Fable]                      [구현 세션: Sonnet]
        │                                          │
/design-to-issues "기능 설명"                /implement-issue 12
        │                                          │
  ① 코드 읽고 검증                            ④ 이슈 계약대로 구현
  ② 설계문서 작성                             ⑤ 검증 명령어 자가 실행
  ③ 이슈 자동 등록 ──── GitHub Issues ─────▶  ⑥ PR 생성
        │                                          │
        └───────── ⑦ 설계문서 대비 PR 리뷰 ◀───────┘
                     [리뷰 세션: Opus/Fable]
```

---

## ❓ 자주 묻는 것부터

### Q. 이슈 템플릿만 repo에 넣으면 알아서 되나요?

**아니요.** 템플릿은 "양식"일 뿐 스스로 아무것도 하지 않습니다. 이 워크플로우는 세 부품이 합쳐져야 돌아갑니다:

| 부품 | 역할 | 없으면 |
|---|---|---|
| `ai-task.yml` (이슈 폼) | 사람이 웹에서 이슈를 만들 때 양식 강제 | 자유 형식 이슈가 섞임 |
| `design-doc-template.md` | 설계문서의 구조 강제 | 상상 설계, 근거 없는 앵커 |
| **`.claude/commands/*.md` (슬래시 커맨드)** | **Claude Code가 이 양식대로 일하게 만드는 실행 장치** | 매번 손으로 길게 지시해야 함 |

즉 **Claude Code에게 지시하는 과정은 슬래시 커맨드가 담당**합니다. `/design-to-issues`를 치면 Claude가 코드를 읽고 → 설계문서를 쓰고 → 이 저장소의 이슈 양식 그대로 `gh issue create`로 등록합니다. 사람이 이슈 폼을 채울 일은 거의 없어지고, 폼은 사람이 수동으로 만들 때의 안전망 역할입니다.

### Q. 어떤 모델로 요청해야 하나요?

Claude Code에서 `/model`로 세션 모델을 전환합니다. 단계별 권장:

| 단계 | 커맨드 | 권장 모델 | 이유 |
|---|---|---|---|
| 설계 + 이슈 등록 | `/design-to-issues` | **Opus** (또는 사용 가능한 최상위 모델) | 코드 전체 맥락 파악, 분해 판단, 엣지 케이스 도출이 품질을 좌우 |
| 구현 | `/implement-issue N` | **Sonnet** | 계약이 명확하면 실행은 빠르고 저렴한 모델로 충분 |
| PR 리뷰 | 아래 리뷰 프롬프트 | **Opus** | 설계 의도 대비 검증은 다시 상위 모델 |

> 핵심 원리: **비싼 모델의 산출물(설계·계약)이 좋을수록 싼 모델의 실행 품질이 올라간다.** 설계에서 아끼고 구현에서 비싼 모델을 쓰는 것이 가장 비효율적인 조합입니다.

### Q. 그래서 뭐가 달라지나요? (Before / After)

| 문제 | 템플릿 없이 | 이 워크플로우로 |
|---|---|---|
| 상상 설계 | 설계문서가 존재하지 않는 함수·다른 스키마를 참조 → 구현이 산으로 감 | 설계 1단계에서 **파일:라인 근거 강제** — 검증 안 된 사실은 설계에 못 씀 |
| Scope creep | "겸사겸사" 리팩토링으로 diff 폭발, 리뷰 불가 | 이슈마다 **Non-goals 필수** — 구현 커맨드가 준수를 강제 |
| 완료 판정 | "잘 되는 것 같아요" — AI도 사람도 확인 불가 | **실행 가능한 검증 명령어** — AI가 스스로 돌려 통과 확인, PR에 결과 첨부 |
| 컨텍스트 초과 | 큰 작업을 통째로 위임 → 세션 중반부터 품질 급락 | **이슈 1개 = 세션 1개 크기**로 분해 규칙 명문화 |
| 리뷰 기준 부재 | PR을 뭘 기준으로 봐야 할지 모름 | 설계문서·이슈 계약이 그대로 리뷰 체크리스트가 됨 |

---

## 구성 파일

```
issue-template/
├── design-doc-template.md              # 상위 설계문서 양식 (기능 1개당 1개)
├── github/
│   └── ISSUE_TEMPLATE/
│       └── ai-task.yml                 # GitHub 이슈 폼 (웹에서 수동 등록용 안전망)
└── claude/
    └── commands/
        ├── design-to-issues.md         # [설계 세션] 요구사항 → 설계문서 → 이슈 등록
        └── implement-issue.md          # [구현 세션] 이슈 번호 → 구현 → 검증 → PR
```

## 설치 (대상 저장소 루트에서)

```bash
REPO_RAW=https://raw.githubusercontent.com/nlook-service/issue-template/main

mkdir -p .github/ISSUE_TEMPLATE docs/design .claude/commands
curl -fsSL $REPO_RAW/github/ISSUE_TEMPLATE/ai-task.yml       -o .github/ISSUE_TEMPLATE/ai-task.yml
curl -fsSL $REPO_RAW/design-doc-template.md                  -o docs/design/TEMPLATE.md
curl -fsSL $REPO_RAW/claude/commands/design-to-issues.md     -o .claude/commands/design-to-issues.md
curl -fsSL $REPO_RAW/claude/commands/implement-issue.md      -o .claude/commands/implement-issue.md

git add .github docs .claude && git commit -m "chore: AI 위임 워크플로우 템플릿 설치"
```

설치 후:
- GitHub **New Issue** 화면에 "AI 구현 작업" 폼이 나타남
- Claude Code에서 `/design-to-issues`, `/implement-issue` 커맨드 사용 가능 (`gh` CLI 로그인 필요: `gh auth login`)

---

## 전체 과정 (실제 지시 예시)

### ① 설계 세션 — Opus로

```
$ claude
> /model opus
> /design-to-issues 토큰 만료 시 재로그인 없이 세션을 이어가는 refresh 토큰 갱신 기능
```

Claude가 자동으로:
1. 관련 코드를 읽고 사실을 검증 (파일:라인 근거 수집)
2. `docs/design/refresh-token.md` 설계문서 작성
3. 이슈 분해안을 보여주고 **승인 요청** ← 여기서 사람이 검토
4. 승인하면 `gh issue create`로 이슈 등록 (이 저장소의 이슈 본문 양식 그대로)
5. 등록된 이슈 번호 표 + 구현 세션에 전달할 지시문 출력

### ② 구현 세션 — Sonnet으로 (이슈당 새 세션)

```
$ claude
> /model sonnet
> /implement-issue 12
```

Claude가 자동으로:
1. `gh issue view 12`로 계약(목표·Non-goals·앵커·완료 기준) 파악
2. 선행 이슈가 안 닫혔으면 중단하고 보고
3. 코드 앵커가 현재 코드와 맞는지 검증 — 설계 전제가 깨졌으면 구현 대신 보고
4. 앵커 범위만 구현, Non-goals 불가침
5. 완료 기준의 검증 명령어를 직접 실행해 통과 확인
6. `Closes #12` 포함 PR 생성

> 💡 이슈가 3개면 구현 세션도 3개. 세션 하나에 이슈 하나가 품질이 가장 좋습니다.
> 의존성 없는 이슈들은 git worktree로 병렬 진행 가능.

### ③ 리뷰 세션 — 다시 Opus로

```
$ claude
> /model opus
> PR #15를 docs/design/refresh-token.md 설계문서와 이슈 #12 계약 대비로 리뷰해줘.
> 특히: 인터페이스 계약 준수, Non-goals 침범 여부, 완료 기준 실제 통과 여부.
```

리뷰 통과 → 머지 → 다음 이슈. 루프가 닫힙니다.

---

## 이슈 본문 양식 (커맨드가 자동 생성하는 구조)

| 필드 | 필수 | 목적 |
|---|---|---|
| 목표 | ✅ | 구현 중 판단이 갈릴 때의 기준 |
| 하지 말 것 (Non-goals) | ✅ | scope creep 차단 — 제일 효과 큰 필드 |
| 코드 앵커 | ✅ | 파일:라인 단위 정확한 작업 위치 ("~근처에" 금지) |
| 인터페이스 계약 | | 시그니처/스키마를 코드로 — 산문 금지 |
| 완료 기준 + 검증 명령어 | ✅ | AI가 스스로 실행해 통과 확인 ("잘 동작해야 함" 금지) |
| 엣지 케이스 | | 설계 단계에서 내린 결정 — 안 쓰면 AI가 임의로 정함 |
| 의존성 | | 선행 이슈 번호, 설계문서 링크 |

## 커스터마이징

- **라벨·제목 접두어**: `ai-task.yml` 상단과 커맨드 파일의 `gh issue create` 라인에서 팀 컨벤션에 맞게 수정
- **이슈 크기 기준**: `design-to-issues.md`의 "파일 5개, 300라인 diff" 기준을 팀에 맞게 조정
- **조직 전체 적용**: 조직의 `.github` 저장소에 `ISSUE_TEMPLATE/`을 넣으면 모든 repo에 이슈 폼이 상속됨 (슬래시 커맨드는 repo별 `.claude/commands/` 또는 개인 `~/.claude/commands/`에 설치)
- **Claude Code 외 도구**: 커맨드 파일은 평문 마크다운 지시문이므로 Cursor rules, Copilot instructions 등에도 내용을 이식 가능

## 요구 사항

- [Claude Code](https://claude.com/claude-code) — 슬래시 커맨드 실행
- [gh CLI](https://cli.github.com/) — 이슈/PR 생성 (`gh auth login` 필요)
