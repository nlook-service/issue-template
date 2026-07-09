---
description: ai-task 이슈 번호를 받아 이슈 계약대로만 구현하고 검증 후 PR 생성
argument-hint: <이슈 번호>
# model 미지정 — 세션 모델을 그대로 상속한다.
# 비용 절감이 목적인 팀만 아래 주석을 해제할 것. 단, 세션이 상위 모델일 때
# 사용자 의도보다 낮은 모델로 강등되는 효과가 있음을 유의.
# model: sonnet
disable-model-invocation: true
---

당신은 구현 담당 엔지니어다. 이슈에 적힌 계약을 벗어나지 않는다.

대상 이슈: #$ARGUMENTS

## 절차

1. **이슈 읽기**: `gh issue view $ARGUMENTS` 로 본문을 읽는다. 제목이 `[Feature]`이거나 본문에 "추적용"이라 적혀 있으면 **구현 대상이 아니다** — `gh api "repos/{owner}/{repo}/issues/$ARGUMENTS/sub_issues"`로 하위 이슈 목록을 조회해 다음 착수 가능한 이슈 번호를 보고하고 중단한다. 구현 이슈면 목표·Non-goals·코드 앵커·인터페이스 계약·완료 기준·엣지 케이스를 파악한다. 의존성에 선행 이슈가 있으면 `gh issue view <번호>`로 닫혔는지 확인하고, 안 닫혔으면 중단하고 보고한다.

   **재작업 여부 확인**: 이 이슈를 가리키는 열린 PR이 이미 있는지 확인한다 — `gh pr list --state open --search "$ARGUMENTS in:body" --json number,headRefName,body` 에서 본문에 `Closes #$ARGUMENTS`가 있는 PR을 찾는다. 있으면 이번 세션은 **반려 후 재작업**이다: `gh pr view <PR번호> --json reviews,comments` 로 반려 사유(리뷰·코멘트)를 읽고, 그 지적을 고치는 것이 이번 작업의 범위가 된다. 반려 사유 없이 열린 PR만 있으면 중단하고 사용자에게 상황을 보고한다.

2. **앵커 검증**: 이슈의 코드 앵커가 현재 코드와 일치하는지 실제 파일을 열어 확인한다. 라인이 밀렸으면 현재 위치를 찾아 진행하되, **함수/구조 자체가 달라져 설계 전제가 깨졌으면 구현하지 않는다.** 이때 차이점을 세션 안에만 남기지 말고 GitHub에 적재한 뒤 중단한다 (라벨이 리포에 없으면 코멘트만):

   ```bash
   gh issue comment $ARGUMENTS --body "<앵커 기준 설계 전제와 실제 코드의 차이 — 파일:라인 근거 포함>"
   gh issue edit $ARGUMENTS --add-label needs-respec
   ```

   `/next`가 이 라벨을 "재설계 필요"로 표시한다. 계약(이슈 본문)을 재설계로 수정한 뒤 라벨을 제거하면 다시 착수 대상이 된다.

3. **브랜치 생성**: `git checkout -b task/$ARGUMENTS-<슬러그>` — 재작업이면 새 브랜치를 만들지 말고 기존 PR의 브랜치(`headRefName`)를 checkout 해서 이어서 작업한다.

4. **구현 규칙**:
   - 코드 앵커에 명시된 파일만 수정한다
   - **Non-goals에 있는 것은 절대 건드리지 않는다** — 개선할 점이 보여도 하지 말고 보고만 한다
   - 인터페이스 계약의 시그니처/스키마를 그대로 따른다 — 임의 변경 금지
   - 엣지 케이스 항목의 결정을 그대로 구현한다
   - 이슈에 없는 판단이 필요해지면 임의로 정하지 말고 사용자에게 묻는다

5. **검증**: 완료 기준의 검증 명령어를 **직접 실행**해 전부 통과시킨다. 실패하면 고치고 다시 실행. 통과 출력 결과를 보고에 포함한다.

6. **PR 생성**: 커밋 후 `gh pr create` 로 PR을 만든다. **재작업이면 새 PR을 만들지 않는다** — 기존 브랜치에 커밋을 push하고, 반려 지적 각각에 어떻게 대응했는지 `gh pr comment`로 남긴 뒤 7단계로 간다. 신규 PR에는 이슈의 라벨·마일스톤을 승계한다 (프로젝트/마일스톤 화면에서 PR도 함께 집계되도록):

   ```bash
   gh issue view $ARGUMENTS --json labels,milestone \
     -q '{labels: [.labels[].name] | join(","), milestone: .milestone.title}'
   gh pr create --label "<위 라벨들>" --milestone "<위 마일스톤>" ...   # 마일스톤 없으면 생략
   ```

   PR 본문에 다음을 포함한다:
   - `Closes #$ARGUMENTS`
   - 완료 기준 체크리스트 (실행 결과 포함)
   - Non-goals 준수 확인 — 건드리지 않은 것 명시
   - 설계와 다르게 한 것이 있으면 그 이유

7. **보고**: PR 링크, 검증 결과, (있다면) 구현 중 발견한 설계와의 불일치를 요약한다.
