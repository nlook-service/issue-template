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

   **승인 시안 확인 (이슈 의존성에 시안 링크가 있는 경우)**: 링크가 가리키는 `.design/<슬러그>/vN.html`이 존재하고 `meta.json`의 `status`가 `approved`인지 확인한다. 컴포넌트 제약·시안이 가정한 데이터 부재 등으로 **승인 시안대로 구현이 불가능하면 앵커 붕괴와 동일하게 처리한다** — 위 명령으로 이슈에 차이(파일:라인 근거)를 코멘트하고 `needs-respec`을 붙인 뒤 중단. 시안과 다른 화면을 임의로 만들지 않는다.

3. **브랜치 생성**: `git checkout -b task/$ARGUMENTS-<슬러그>` — 재작업이면 새 브랜치를 만들지 말고 기존 PR의 브랜치(`headRefName`)를 checkout 해서 이어서 작업한다.

   그리고 **프로젝트 보드 상태를 "In Progress"로 옮긴다** — GitHub 내장 워크플로우는 "작업 시작"을 감지할 신호가 없어 이 칸은 커맨드가 채워야 한다. `project` 스코프가 없거나(`gh auth refresh -s project`로 부여) Status 필드/옵션이 없으면 **조용히 건너뛴다** (보드 연동은 보너스이지 의존성이 아니다). 이슈가 이미 추가된 모든 프로젝트에 대해 처리한다:

   ```bash
   read -r OWNER REPO <<<"$(gh repo view --json owner,name -q '.owner.login+" "+.name')"
   gh api graphql -f query='
     query($o:String!,$r:String!,$n:Int!){ repository(owner:$o,name:$r){ issue(number:$n){
       projectItems(first:20){ nodes{ id project{ id title
         field(name:"Status"){ ... on ProjectV2SingleSelectField { id options{ id name } } } } } } } } }' \
     -f o="$OWNER" -f r="$REPO" -F n=$ARGUMENTS 2>/dev/null \
   | jq -c '.data.repository.issue.projectItems.nodes[]
       | select(.project.field != null)
       | {item:.id, proj:.project.id, field:.project.field.id,
          opt:((.project.field.options[] | select(.name|ascii_downcase|test("progress")) | .id) // null)}
       | select(.opt != null)' \
   | while read -r row; do
       gh api graphql -f query='mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){
         updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){ projectV2Item{ id } } }' \
         -f p="$(jq -r .proj <<<"$row")" -f i="$(jq -r .item <<<"$row")" \
         -f f="$(jq -r .field <<<"$row")" -f o="$(jq -r .opt <<<"$row")" >/dev/null 2>&1 || true
     done
   ```

   Done은 이 커맨드가 만지지 않는다 — 머지 시 `Closes #N`으로 이슈가 닫히고, 프로젝트의 내장 워크플로우(`Item closed → Done`)가 옮긴다 (README 2단계 설정).

4. **구현 규칙**:
   - 코드 앵커에 명시된 파일만 수정한다
   - `.design/` 이하는 읽기 전용 — 어떤 섹션에 언급돼도 수정하지 않는다 (승인 시안 불변성)
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

## UI 버그 조사 규칙 (대상 이슈가 UI 버그일 때)

1. **코드를 읽기 전에 화면 상태부터 확보한다.**
   스크린샷 · URL · 테마 · **켜져 있는 표시 모드/토글**(다크 모드, 인쇄/컴팩트 레이아웃, 배경·스킨, 폰트 설정 등 앱이 가진 렌더 상태 축 전부) · 뷰포트.
   이슈에 없으면 사용자에게 **요청한다.** 추측으로 시작하지 않는다.

2. **기본 상태로 재고 "정상"이라 결론내지 않는다.**
   렌더 상태 축은 곱하면 조합이 수십~수백 개다. 기본 조합 1회 측정은 **아무것도 증명하지 못한다.**
   신고된 증상이 안 나오면 → 버그 없음이 아니라, **아직 그 상태를 못 만든 것이다.**

3. **재현 실패 = 조사 종료가 아니다.**
   상태 축을 하나씩 켜가며 **이분법으로 조건을 좁힌다.**
   (예: 배경 이미지 ON/OFF × 인쇄 레이아웃 ON/OFF — 4조합 전부 측정)

4. **오라클은 실측뿐이다.** computed style · 대비비 등 **숫자**로 보고한다.
   "흐려 보인다"가 아니라 "color=#E8E4D9, bg=#FFFFFF, 대비 1.4:1".
   측정 못 했으면 **"미측정"이라 정직하게 쓰고 이유를 적는다. 측정한 척하지 않는다.** — 정직한 재현 실패 보고는 가짜 수정을 막는 가치 있는 결과다.
