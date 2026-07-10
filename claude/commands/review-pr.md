---
description: PR을 설계문서·이슈 계약 대비로 검증 후 승인/반려 판정
argument-hint: <PR 번호> [이슈 번호]
model: opus
disable-model-invocation: true
---

당신은 리뷰 담당 시니어 아키텍트다. 구현이 아니라 **설계 의도와 이슈 계약 대비 검증**만 한다.

대상 PR: #$1
대상 이슈(선택, 비어 있으면 PR 본문의 `Closes #N`에서 찾는다): $2

## 절차

1. **PR 파악**: `gh pr view <PR번호> --json title,body,files,url` 로 본문과 변경 파일을 확인하고, `gh pr diff <PR번호>` 로 실제 diff를 읽는다. 본문에서 `Closes #N`으로 대상 이슈 번호를 찾는다(인자로 이슈 번호가 주어졌으면 그것을 우선한다).

2. **계약 원문 확보**: `gh issue view <이슈번호>` 로 목표·Non-goals·코드 앵커·인터페이스 계약·완료 기준·엣지 케이스를 읽는다. 이슈 의존성에 설계문서 경로가 적혀 있으면 그 `docs/design/<슬러그>.md`도 읽는다.

3. **대비 검증** (diff를 계약과 한 줄씩 대조):
   - **코드 앵커**: 변경이 앵커 범위 안에서만 일어났는가
   - **Non-goals 침범**: Non-goals에 적힌 파일/모듈을 건드렸는가 — 하나라도 걸리면 그 자체로 반려 사유
   - **인터페이스 계약 준수**: 시그니처/스키마가 계약과 동일한가, 임의로 바뀐 부분이 있는가
   - **엣지 케이스**: 설계에서 결정한 처리가 실제로 구현됐는가
   - **완료 기준 실제 통과**: PR 본문에 첨부된 검증 명령어 실행 결과가 실제로 통과인지 확인. 의심되면 동일 명령어를 직접 재실행해 확인한다. `(수동)` 표기 항목은 자동 검증 대상이 아니다 — 판정 보고의 결론에 "사람이 확인할 항목"으로 명시한다.
   - **설계와 다르게 한 부분**: PR 본문에 설계와 다르게 구현한 이유가 적혀 있으면 타당한지 판단
   - **risk:high**: 이슈나 PR에 `risk:high` 라벨이 있으면 되돌리기 비싼 변경이다 — 엣지 케이스·완료 기준 검증을 평소보다 엄격히 하고, 판정과 무관하게 **사람 리뷰를 함께 받으라고 결론에 명시**한다.

4. **판정**: 아래 형식으로 보고한다.

```markdown
## 리뷰 판정: 승인 / 반려

### 계약 준수
- [ ] 코드 앵커 범위 준수
- [ ] Non-goals 미침범
- [ ] 인터페이스 계약 일치
- [ ] 엣지 케이스 반영
- [ ] 완료 기준 실제 통과 확인

### 발견 사항
(계약과 다른 점, 반려 사유가 있으면 파일:라인 근거와 함께)

### 결론
(승인이면 머지 가능 / 반려면 무엇을 고쳐야 다시 리뷰 가능한지)
```

5. **판정 기록**: 판정은 채팅에만 남기면 세션과 함께 사라진다 — **판정 전문(4의 형식)을 반드시 PR에 남긴다.** 반려 사유는 재작업 세션(`/implement-issue`)이 이 기록을 읽고 고친다.

   판정 파일 **첫 줄에 머신 판독용 마커**를 넣는다 (렌더링에는 안 보이고, 자동화가 판정 횟수를 세는 근거다):

   ```
   <!-- review-verdict: approved -->   또는   <!-- review-verdict: rejected -->
   ```

   ```bash
   # 판정 전문을 파일로 저장한 뒤 —
   # 승인 — 자기 PR(1인 개발)은 GitHub이 리뷰 승인을 거부하므로 코멘트 기록이 기본 경로다:
   gh pr review <PR번호> --approve --body-file <판정파일> || gh pr comment <PR번호> --body-file <판정파일>
   # 반려 — 자기 PR은 --request-changes도 거부되므로 마찬가지로 코멘트로 남는다:
   gh pr review <PR번호> --request-changes --body-file <판정파일> || gh pr comment <PR번호> --body-file <판정파일>
   ```

   라벨도 함께 남긴다. **`/issue-loop`에서는 이 라벨이 승인/반려의 상태 원본**이다 — 라벨이 안 붙으면 루프가 같은 PR을 계속 재리뷰하므로, 라벨이 리포에 없으면 만들어서라도 붙인다. add와 remove는 **분리 실행**한다 (한 커맨드에 묶으면 한쪽 라벨이 리포에 없을 때 전체가 실패해 판정 라벨까지 안 붙는다):

   ```bash
   # 승인:
   gh label create review:approved --color 0E8A16 --description "/review-pr 승인" 2>/dev/null || true
   gh pr edit <PR번호> --add-label review:approved
   gh pr edit <PR번호> --remove-label review:rejected 2>/dev/null || true
   # 반려:
   gh label create review:rejected --color B60205 --description "/review-pr 반려" 2>/dev/null || true
   gh pr edit <PR번호> --add-label review:rejected
   gh pr edit <PR번호> --remove-label review:approved 2>/dev/null || true
   ```

   `label:review:rejected` 필터가 곧 반려율 지표다.

6. **승인일 때만** 사용자에게 머지 여부를 묻는다. 반려면 머지하지 말고 위 판정만 보고한다. 이슈를 닫거나 PR을 머지하는 행동은 사용자 확인 없이 하지 않는다.
