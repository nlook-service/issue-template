# issue-template

AI 위임 개발 워크플로우 — **팀의 합의를 '계약'으로 명문화하고, 구현과 검증을 독립 세션으로 분리하는** 템플릿 + Claude Code 슬래시 커맨드 세트.

```
/spec "기능 설명"  (상위 모델 고정)           /implement-issue 12  (세션 모델)
        │                                          │
  ① 코드 읽고 검증                            ④ 이슈 계약대로 구현
  ② 설계문서 작성                             ⑤ 검증 명령어 자가 실행
  ③ 이슈 자동 등록 ──── GitHub Issues ─────▶  ⑥ PR 생성
        │                                          │
        └── /review-pr 15 12  (상위 모델·별도 세션) ◀──┘
                     ⑦ 설계문서 대비 PR 판정
```

`/spec`·`/review-pr` frontmatter에 `model:`이 박혀 있어 **`/model`을 직접 안 쳐도 그 커맨드를 부르는 순간 자동으로 상위 모델로 전환**되고, 다음 프롬프트부터 세션은 원래 모델로 돌아갑니다. `/implement-issue`는 모델을 고정하지 않고 세션 모델을 그대로 상속합니다 (아래 FAQ 참고). 세 커맨드 모두 `disable-model-invocation: true`라 Claude가 알아서 트리거하지 않고, 사람이 직접 `/spec`·`/implement-issue`·`/review-pr`을 쳤을 때만 실행됩니다.

> **이 워크플로우는 네이티브 코드 리뷰의 대체재가 아닙니다.** 네이티브 리뷰는 "좋은 코드인가"를 묻고, `/review-pr`은 "**우리가 합의한 그 코드**인가"를 묻습니다. 이슈 계약(Non-goals·앵커·완료 기준)이라는 채점 기준은 네이티브 도구가 알 수 없는 입력이므로, 둘을 함께 쓰는 것이 정답입니다.

---

## ❓ 자주 묻는 것부터

### Q. 이슈 템플릿만 repo에 넣으면 알아서 되나요?

**아니요.** 템플릿은 "양식"일 뿐 스스로 아무것도 하지 않습니다. 이 워크플로우는 세 부품이 합쳐져야 돌아갑니다:

| 부품 | 역할 | 없으면 |
|---|---|---|
| `ai-task.yml` (이슈 폼) | 사람이 웹에서 이슈를 만들 때 양식 강제 | 자유 형식 이슈가 섞임 |
| `design-doc-template.md` | 설계문서의 구조 강제 | 상상 설계, 근거 없는 앵커 |
| **`.claude/commands/*.md` (슬래시 커맨드)** | **Claude Code가 이 양식대로 일하게 만드는 실행 장치** | 매번 손으로 길게 지시해야 함 |

즉 **Claude Code에게 지시하는 과정은 슬래시 커맨드가 담당**합니다. `/spec`을 치면 Claude가 코드를 읽고 → 설계문서를 쓰고 → 이 저장소의 이슈 양식 그대로 `gh issue create`로 등록합니다. 사람이 이슈 폼을 채울 일은 거의 없어지고, 폼은 사람이 수동으로 만들 때의 안전망 역할입니다.

### Q. 어떤 모델로 요청해야 하나요?

**신경 쓸 필요 없습니다 — 설계·리뷰는 커맨드가 상위 모델로 자동 전환하고, 구현은 세션 모델을 그대로 따릅니다.**

| 단계 | 커맨드 | 모델 | 이유 |
|---|---|---|---|
| 설계 + 이슈 등록 | `/spec` | **상위 모델 고정** | 코드 전체 맥락 파악, 분해 판단, 엣지 케이스 도출이 품질을 좌우 — 세션 모델과 무관한 품질 하한선 |
| 구현 | `/implement-issue N` | **세션 모델 상속** | 계약이 명확하면 어떤 모델이든 실행 가능. 고정하지 않는 이유: 세션이 상위 모델일 때 모르는 사이 하위 모델로 강등되는 것을 방지 |
| PR 리뷰 | `/review-pr <PR번호> [이슈번호]` | **상위 모델 고정 + 별도 세션** | 구현 세션은 자기 가정을 물려받아 자기 결함을 못 잡는다 — **독립 세션 + 상위 모델 + 계약 대조**의 3중 구조가 검출력의 핵심 |

> 핵심 원리: **검증이 구현보다 약해지면 안 된다.** 구현 모델은 아껴도 되지만, 설계와 리뷰는 항상 쓸 수 있는 가장 강한 모델로 — 그리고 리뷰는 반드시 구현과 **다른 세션**에서.

`spec.md`·`review-pr.md` frontmatter의 `model:` 값만 바꾸면 고정 모델을 교체할 수 있습니다(조직에서 쓸 수 있는 최상위 모델로). 값이 조직의 `availableModels` 허용 목록에 없으면 조용히 무시되고 세션의 현재 모델이 유지됩니다 — 즉 실패해도 에러 없이 그냥 전환이 안 될 뿐입니다. `implement-issue.md`는 의도적으로 `model:`을 지정하지 않습니다 — 비용 절감이 필요한 팀만 파일 내 주석을 참고해 지정하세요.

### Q. 그래서 뭐가 달라지나요? (Before / After)

| 문제 | 템플릿 없이 | 이 워크플로우로 |
|---|---|---|
| 상상 설계 | 설계문서가 존재하지 않는 함수·다른 스키마를 참조 → 구현이 산으로 감 | 설계 1단계에서 **파일:라인 근거 강제** — 검증 안 된 사실은 설계에 못 씀 |
| Scope creep | "겸사겸사" 리팩토링으로 diff 폭발, 리뷰 불가 | 이슈마다 **Non-goals 필수** — 구현 커맨드가 준수를 강제 |
| 완료 판정 | "잘 되는 것 같아요" — AI도 사람도 확인 불가 | **실행 가능한 검증 명령어** — AI가 스스로 돌려 통과 확인, PR에 결과 첨부 |
| 컨텍스트 초과 | 큰 작업을 통째로 위임 → 세션 중반부터 품질 급락 | **이슈 1개 = 세션 1개 크기**로 분해 — 리뷰 가능한 PR 크기 유지 |
| 리뷰 기준 부재 | PR을 뭘 기준으로 봐야 할지 모름 | 설계문서·이슈 계약이 그대로 리뷰 체크리스트가 됨 |
| 이슈 파편화 | 이슈가 나열식으로 등록돼 어떤 기능의 일부인지, 뭐부터 해야 하는지 알기 어려움 | 상위 이슈 1개 아래 **sub-issue 트리 + 진행률** — 상위 이슈 본문에 구현 순서(의존 그래프) 명시 |
| 셀프 리뷰의 한계 | 구현한 세션이 자기 코드를 검토 → 같은 가정·같은 맹점으로 결함 통과 | **별도 세션 + 상위 모델**이 계약 대비로 리뷰 — 일반 리뷰가 놓치는 계약 위반 검출 |

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
        ├── spec.md                     # [설계, 상위 모델 고정] 요구사항 → 설계문서 → 이슈 등록
        ├── implement-issue.md          # [구현, 세션 모델 상속] 이슈 번호 → 구현 → 검증 → PR
        └── review-pr.md                # [리뷰, 상위 모델 고정] PR → 설계문서·이슈 계약 대비 판정
```

## 설치 (대상 저장소 루트에서)

```bash
REPO_RAW=https://raw.githubusercontent.com/nlook-service/issue-template/main

mkdir -p .github/ISSUE_TEMPLATE docs/design .claude/commands
curl -fsSL $REPO_RAW/github/ISSUE_TEMPLATE/ai-task.yml       -o .github/ISSUE_TEMPLATE/ai-task.yml
curl -fsSL $REPO_RAW/design-doc-template.md                  -o docs/design/TEMPLATE.md
curl -fsSL $REPO_RAW/claude/commands/spec.md                 -o .claude/commands/spec.md
curl -fsSL $REPO_RAW/claude/commands/implement-issue.md      -o .claude/commands/implement-issue.md
curl -fsSL $REPO_RAW/claude/commands/review-pr.md            -o .claude/commands/review-pr.md

# 이슈 라벨 생성 (gh issue create --label이 라벨 미존재 시 실패하므로 필수)
gh label create ai-task --color "1D76DB" --description "AI 위임 구현 작업" 2>/dev/null || true

git add .github docs .claude && git commit -m "chore: AI 위임 워크플로우 템플릿 설치"
```

설치 후:
- GitHub **New Issue** 화면에 "AI 구현 작업" 폼이 나타남
- Claude Code에서 `/spec`, `/implement-issue`, `/review-pr` 커맨드 사용 가능 (`gh` CLI 로그인 필요: `gh auth login`) — 설계·리뷰 커맨드는 상위 모델로 자동 전환되므로 `/model`을 직접 칠 필요 없음

---

## 전체 과정 (실제 지시 예시)

### ① 설계 — `/spec` (자동으로 상위 모델)

```
$ claude
> /spec 토큰 만료 시 재로그인 없이 세션을 이어가는 refresh 토큰 갱신 기능
```

Claude가 자동으로:
1. 관련 코드를 읽고 사실을 검증 (파일:라인 근거 수집)
2. `docs/design/refresh-token.md` 설계문서 작성
3. 이슈 분해안을 보여주고 **승인 요청** ← 여기서 사람이 검토
4. 승인하면 `gh issue create`로 이슈 등록 — 2개 이상으로 분해됐으면 상위 추적 이슈(`[Feature]`)를 먼저 만들고 각 작업 이슈를 GitHub **sub-issue로 연결** (UI에서 트리 + 진행률로 표시), 상위 이슈 본문에 구현 순서 명시
5. 등록된 이슈 번호 표 + 구현 세션에 전달할 지시문 출력

### ② 구현 — `/implement-issue` (세션 모델 상속, 이슈당 새 세션)

```
$ claude
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

### ③ 리뷰 — `/review-pr` (자동으로 상위 모델, 반드시 별도 세션)

```
$ claude
> /review-pr 15 12
```

**구현했던 세션에서 이어서 돌리지 말고 새 세션에서 실행하세요** — 구현 세션은 자기가 깔았던 가정을 컨텍스트째로 물려받아 자기 결함을 잘 못 잡습니다. 독립 세션 + 상위 모델 + 계약 대조가 합쳐져야 일반 리뷰가 놓치는 계약 위반이 잡힙니다.

`design.md`·이슈 #12 계약과 PR diff를 한 줄씩 대조해 승인/반려 판정을 내립니다. 승인일 때만 머지 여부를 물어봅니다 — 반려면 무엇을 고쳐야 하는지만 보고하고 머지하지 않습니다. 리뷰 통과 → 머지 → 다음 이슈. 루프가 닫힙니다.

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

- **모델 고정**: `spec.md`·`review-pr.md`는 `model:`로 상향 고정 (기본값 opus — 조직에서 쓸 수 있는 최상위 모델로 교체). `implement-issue.md`는 의도적으로 미지정 — 지정하면 세션이 상위 모델일 때 하위 모델로 강등되는 효과가 있음
- **라벨·제목 접두어**: `ai-task.yml` 상단과 커맨드 파일의 `gh issue create` 라인에서 팀 컨벤션에 맞게 수정 (상위 추적 이슈는 `[Feature]`, 작업 이슈는 `[Task]` 접두어)
- **sub-issue 연결**: `/spec`이 이슈를 2개 이상으로 분해하면 상위 이슈를 만들고 REST API로 sub-issue 연결. sub-issues를 지원하지 않는 환경(구버전 GHES)에서는 자동으로 건너뛰며, 이슈 본문의 의존성 필드가 같은 정보를 텍스트로 유지
- **이슈 크기 기준**: `spec.md`의 "파일 5개, 300라인 diff" 기준을 팀에 맞게 조정
- **조직 전체 적용**: 조직의 `.github` 저장소에 `ISSUE_TEMPLATE/`을 넣으면 모든 repo에 이슈 폼이 상속됨 (슬래시 커맨드는 repo별 `.claude/commands/` 또는 개인 `~/.claude/commands/`에 설치)
- **Claude Code 외 도구**: 커맨드 파일은 평문 마크다운 지시문이므로 Cursor rules, Copilot instructions 등에도 내용을 이식 가능

## 선택 통합 (Optional Integrations)

- **[Langfuse](./integrations/langfuse/README.md)** — `/spec`·`/implement-issue`·`/review-pr` 실행을 이름 있는 trace로 기록. 기본 설치에는 포함되지 않으며, 켜면 커맨드 인자가 제3자 SaaS로 전송되니 설치 전 README의 경고를 꼭 읽으세요.

## 요구 사항

- [Claude Code](https://claude.com/claude-code) — 슬래시 커맨드 실행
- [gh CLI](https://cli.github.com/) — 이슈/PR 생성 (`gh auth login` 필요)

## 라이선스

[MIT](./LICENSE)
