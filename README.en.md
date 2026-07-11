<div align="center">

# issue-template

### Write the issue like a contract → implement → review against it → merge → the loop repeats it for you.

A Claude Code workflow that stops the classic failure modes of delegating to AI — hallucinated designs, drive-by refactoring, "it seems to work" — by **writing issues as contracts**.

[한국어](./README.md) | **English**

<p>
  <a href="https://nlook.me"><img alt="Made by nlook" src="https://img.shields.io/badge/made%20by-nlook.me-0a0a0b"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2563eb"></a>
  <a href="./VERSION"><img alt="Version" src="https://img.shields.io/badge/version-1.7.1-blue"></a>
  <a href="https://docs.claude.com/en/docs/claude-code"><img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-workflow-86efac"></a>
</p>

</div>

The core loop is **3 slash commands**, plus a navigator (`/next`) and an autonomous loop (`/issue-loop`) on top:

```
/spec "feature description"  (auto higher model)    /implement-issue 12  (session model)
        │                                                 │
  ① read & verify real code                          ④ implement per issue contract
  ② write design doc                                 ⑤ self-run verification commands
  ③ auto-register issues ──── GitHub Issues ─────▶   ⑥ create PR
        │                                                 │
        └── /review-pr 15 12  (higher model · separate session) ◀──┘
                     ⑦ judge the PR against the design doc

  /next        derives "what to do next" from GitHub state
  /issue-loop  repeats the whole loop with subagents (humans decide merges)
```

## Table of contents

- [Getting started (5 min)](#-getting-started-5-min)
- [Command guide](#-command-guide)
  - [/spec — design + issue registration](#spec--design--issue-registration)
  - [/implement-issue — implementation](#implement-issue--implementation)
  - [/review-pr — review](#review-pr--review)
  - [/next — navigator](#next--navigator)
  - [/issue-loop — autonomous loop](#issue-loop--autonomous-loop)
- [The 3 rules to remember](#the-3-rules-to-remember)
- [How this relates to your git workflow](#how-this-relates-to-your-git-workflow)
- [FAQ](#-faq)
- [Issue body format](#issue-body-format-auto-generated-by-the-commands)
- [Projects & milestone integration](#projects--milestone-integration)
- [Label system](#label-system)
- [What is automated](#what-is-automated)
- [Customization](#customization)
- [Security](#-security)
- [Repository layout](#repository-layout)

---

## 🚀 Getting started (5 min)

### Step 1. Install — one line

From the root of the target repository:

```bash
curl -fsSL https://raw.githubusercontent.com/nlook-service/issue-template/main/install.sh | bash
```

This one line installs everything:

- 4 slash commands (`.claude/commands/`) + the `issue-loop` skill (`.claude/skills/`)
- GitHub issue form + design doc template
- 13 labels (`ai-task`, `size:S/M`, `review:approved/rejected`, …)
- Auto-update workflow (every Monday; opens a PR only when the template changed)

Then commit as instructed:

```bash
git add .github docs .claude && git commit -m "chore: install issue-template"
```

> **Updating uses the same command.** Re-running it refreshes only changed files; files your team modified are never overwritten — the latest version is saved next to them as `<file>.new`.
>
> Uncomfortable with `curl | bash`? See "review before install" in the [Security](#-security) section.

### Step 2. One-time setup (optional but recommended)

| Setting | Where | Effect |
|---|---|---|
| Allow Actions to create PRs | Repo/org Settings → Actions → General → check **"Allow GitHub Actions to create and approve pull requests"** | Template updates arrive as weekly automated PRs |
| Auto-add to project | Team Project → ⚙️ Settings → Workflows → enable **Auto-add to project** with filter `label:ai-task` | Every registered issue is added to the project automatically |
| Auto board transitions | Same Workflows screen: enable **Item added → Todo**, **Item closed → Done**, **Pull request merged → Done** | The board's Todo/Done columns fill in automatically |
| Board "In Progress" | `gh auth refresh -s project` (grant the `project` scope to your gh token, once) | `/implement-issue` moves the board to **In Progress** when work starts — GitHub can't detect "work started", so the command fills this in. Silently skipped if the scope is absent |
| Create milestones | Repo → Issues → Milestones (set a due date) | `/spec` asks which milestone to attach at registration |
| Branch protection | Repo Settings → Branches → required checks on main | Forces CI to pass before `/issue-loop --unattended` can auto-merge |

> **Insights come for free.** The commands plant metadata on issues and PRs automatically — type (`feat`/`bug`/`refactor`), size (`size:S/M`), assignee and issue type from `/spec`; label/milestone inheritance on PRs from `/implement-issue`; verdict labels (`review:approved/rejected`) from `/review-pr` — so you get **progress** on the milestone page, **throughput charts** in Projects → Insights, and **rejection rate** via the `label:review:rejected` filter, with no extra tooling.

### Step 3. Run your first feature

```
$ claude
> /spec refresh-token renewal so sessions survive token expiry without re-login
```

Approve the breakdown and the issues are registered. Then pick your style:

- **Step by step, manually**: new session `/implement-issue 12` → another new session `/review-pr 15 12` → merge
- **Let it figure out the next step**: `/next`
- **Fully automated loop**: `/issue-loop`

---

## 📖 Command guide

### `/spec` — design + issue registration

```
/spec <feature description or path to a requirements doc>
```

Pinned to the higher model (opus). What it does:

1. **Verifies real code** — opens the code the requirement touches and collects file:line evidence. **Unverified facts never enter the design** (blocks hallucinated designs).
2. **Writes the design doc** — `docs/design/<feature-slug>.md`, with at least 2 explicit "things we will NOT do".
3. **Breaks work into issues** — each issue is sized to **finish in a single AI session** (~5 files, ~300-line diff). **Parallel-safety rule**: issues without dependencies must not share code anchors (files to modify) — that's what makes concurrent git-worktree work merge-conflict-free.
4. **Human approval** — nothing is registered until you approve the breakdown (and milestone).
5. **Registers issues** — a parent tracking issue (`[Feature]`) plus child issues (`[Task][<slug> <n>/<total>]`) linked as a sub-issue tree, with labels, assignee, milestone, and issue type attached automatically.

The `[auth 2/3]` title tag makes "which feature, which step" visible in the issue list regardless of global issue numbers.

### `/implement-issue` — implementation

```
/implement-issue <issue number>
```

Uses the session model as-is (intentionally not pinned). What it does:

1. **Reads the issue contract** — if it's a `[Feature]` tracking issue it won't implement; it points you to the next actionable child. Stops if prerequisite issues aren't closed.
2. **Validates anchors** — checks the issue's code anchors against the actual code. If the design premise is broken, it does NOT implement; it leaves an issue comment + the `needs-respec` label and stops (the record lives on GitHub, not in the session).
3. **Implements only the contract** — touches only anchored files, **never touches Non-goals**, follows the interface contract exactly.
4. **Self-verifies** — runs the acceptance commands itself until they all pass.
5. **Creates the PR** — body includes `Closes #N`, verification output, and Non-goals compliance. Inherits the issue's labels and milestone.

**Rework after rejection uses the same command.** Run it again with the same issue: it reads the rejection reasons from the open PR (review + comments), fixes them on the existing branch — no new PR — and replies to each point as a PR comment.

### `/review-pr` — review

```
/review-pr <PR number> [issue number]
```

Pinned to the higher model (opus). **Always run it in a session different from the one that implemented** — an implementing session inherits its own assumptions and can't catch its own defects.

This is not generic code review ("is this good code?") but **contract verification** ("is this the code we agreed on?"):

- Anchor-scope compliance / **Non-goals violations** (any single hit = rejection) / interface contract match / edge cases implemented / acceptance criteria actually passing (re-runs them itself when in doubt)
- `risk:high` PRs get stricter verification and, regardless of the verdict, **a human review is additionally required**.
- The full verdict is **recorded as a PR review** — rejection reasons don't evaporate with the session; the rework session reads and fixes them. It also attaches `review:approved`/`review:rejected` labels.
- **Solo development works as-is.** GitHub refuses approve/request-changes reviews on your own PR, but in that case the verdict lands as a PR comment instead, and the automation's source of truth is the **labels**, not the review state — so nothing in the workflow breaks.
- It asks the user about merging only on approval. It never merges on its own.

### `/next` — navigator

```
/next [parent issue number]
```

Derives "what's next?" from GitHub state. Reads issue dependencies and PR states, prints a status board:

```
[auth-refresh] #10
  1/3 ✅ #11 refresh token renewal
  2/3 🔨 #12 session reuse detection
  3/3 ⛔ #13 expiry UI handling (waiting on 2/3)
```

- ✅ done / 🔍 awaiting review / 🔨 ready to implement / 🔧 needs respec (`needs-respec`) / ⛔ blocked
- **If it's implementation's turn, it starts implementing right there**; if it's review's turn, it prints the exact `/review-pr` command with numbers filled in. No need to memorize issue/PR numbers.
- With multiple ready issues, it suggests **parallel work via git worktree** — safe thanks to `/spec`'s parallel-safety rule. Unattended parallel execution is limited to `agent:auto`-labeled issues.

### `/issue-loop` — autonomous loop

Instead of opening a session per step of `/spec → /implement-issue → /review-pr → merge`, a **loop driver reads GitHub state and delegates each step to a fresh subagent**, repeating automatically. The original principles hold: one issue = one session (each step gets an independent subagent), review happens in a different session than implementation, and design approval plus `risk:high` merges are always human decisions.

#### Usage

```
/issue-loop                      # resume: read GitHub state and start/continue the loop
/issue-loop "<feature description>"  # start from design (human approves the breakdown), then loop
/issue-loop <parent issue number>    # scope to one feature ([Feature] issue)
/issue-loop --label <tag>        # only issues with that label (AND with ai-task)
/issue-loop --once               # take a single step and exit
/issue-loop --status             # print status board + plan only (no execution)
/issue-loop --max N              # step cap (default: max(20, open issues × 4))
/issue-loop --unattended         # fully unattended mode (see below)
/issue-loop --economy            # all implementation on sonnet (review/design stay on opus)
/issue-loop --usage-guard N      # stop at step boundary when usage estimate exceeds N% (default 90)
```

#### What each step does

1. **Collect state** — re-reads issues, PRs, and labels from GitHub (GitHub is the source of truth).
2. **Decide the next action** — priority: review unreviewed PRs → rework rejected PRs → merge gate for approved PRs → implement the next ready issue. Before starting an issue, an **anchor-conflict check** holds back any issue whose files overlap an open PR (prevents merge conflicts even across features).
3. **Dispatch a subagent** — implementation/review/rework each run in a fresh agent that returns a one-line result. Detailed records land on GitHub (PR body, comments, reviews).
4. **Journal** — appends steps and checkpoints to `.claude/issue-loop/journal.md` (auto-gitignored).

#### Two modes

| | Default (supervised) | `--unattended` |
|---|---|---|
| Target issues | All (`agent:assist` issues ask once before starting) | Only `agent:auto`-labeled issues |
| Agent questions | Forwarded to you, then resumed | Issue is skipped and escalated |
| Merging | **Human decides, loop executes** — asks when a PR is approved | Auto-merges only after the **enhanced review** passes + CI green |
| `risk:high` PRs | Human review & merge (loop only reports) | Same — regardless of mode |

The unattended **enhanced review** is the quality basis for auto-merge, so every item is mandatory: ① re-run the issue's verification commands directly ② run the full test suite ③ confirm tests were added/updated ④ confirm docs were updated when interfaces changed ⑤ any `(manual)` acceptance criterion disqualifies auto-merge. Any miss = rejection.

**Recipe for a fully unattended run** — decomposition approval is the one gate that is never automated, so front-load the approval, then run the loop hands-off:

```
/spec "<feature description>"                    # ① human approves the decomposition + issues registered — check agent:auto labels
/issue-loop --unattended                        # ② implement→review→merge runs fully unattended from here
/issue-loop --unattended --economy --usage-guard 85   # combo: save quota + stop gracefully near the limit
```

Even unattended, `risk:high` PRs (human review required) and `agent:assist` issues (skipped) remain — come back to the final report's **merge queue and escalation list**.

#### Model routing (usage optimization)

| Condition | Model |
|---|---|
| `size:S` and not `risk:high` | sonnet |
| `size:M` or `risk:high` | opus |
| Rework (after rejection) | opus — a failed task gets promoted |
| Review · design | opus, always — never downgraded |

- `--economy`: all implementation on sonnet for quota-tight days. Quality is protected by opus reviews and the two-rejection safeguard.
- On opus quota exhaustion: implementation falls back to sonnet once; **review/design never fall back — the loop stops instead**. Stopping beats looping with a lowered quality gate.

#### Safety rails

- **Issues rejected twice are removed from the loop** and escalated to a human (prevents rejection ping-pong). The count comes from the GitHub history of `review:rejected` **label additions**, not the local journal — so it stays accurate even in solo development, where you can't leave a request-changes review on your own PR.
- `--max` step cap (default `max(20, issues × 4)`) — never hit on a normal run; only stops runaways.
- **Usage guard**: with [ccusage](https://github.com/ryoppippi/ccusage) installed, the loop estimates 5-hour-block usage before each step and stops gracefully at the boundary past the threshold (default 90%). Silently skipped when the tool is absent.
- If the working tree has changes the agent didn't make, it stops without touching them.

#### Interruption & resume

All state lives on GitHub (issues, PRs, labels, branches), so **re-running `/issue-loop` IS the resume**. Whether you hit a usage limit or switch machines (any `gh`-authenticated CLI/web session), it naturally continues from state collection. The journal is only auxiliary — rejection counts and interruption notes.

Full rules: [`claude/skills/issue-loop/SKILL.md`](./claude/skills/issue-loop/SKILL.md) (Korean).

---

## The 3 rules to remember

1. **One issue = one session.** Three issues means three implementation sessions. (`/issue-loop` satisfies this automatically via subagents.)
2. **Review always happens in a fresh session.** The implementing session inherits its own assumptions and can't catch its own defects.
3. **Don't think about models.** Design and review auto-switch to the higher model; implementation follows the session model.

---

## How this relates to your git workflow

What this template actually requires of your branching strategy is minimal:

```
task/<issue-number>-<slug> ──PR──▶ <default branch> (merged after contract review, Closes #N)
```

- **One issue = one branch = one PR.** `/implement-issue` creates the branch automatically and comes back as a PR.
- **The template does not choose your PR base branch.** The commands work against the repo's default branch, so it layers onto whatever strategy your org uses — trunk-based (straight to main), git-flow (develop), or release branches.
- **Merge method (squash/merge/rebase) follows your org's convention.** Just note that the one-issue-one-PR structure pairs well with squash.
- **CI complements `/review-pr`.** `/review-pr` asks "was it built to the contract?"; CI asks "is it mechanically sound?" (tests, typecheck, build). They are not substitutes — if you have CI, gate PRs on it as well.
- **Parallel work**: issues without dependencies have disjoint code anchors (`/spec`'s parallel-safety rule), so worktree-based parallel work is safe under any strategy.

The choices above that layer are team- and environment-dependent — for reference only:

| Situation | Common choice |
|---|---|
| Solo/small team, no staging | Trunk-based + tag releases (`git tag vX.Y.Z` → deploy). Without staging, a develop branch tends to become a merge-delay device rather than a testing ground |
| Staging environment available | Trunk-based + environment promotion — auto-deploy to staging, verify, then promote to production with a tag |
| Scheduled releases / QA org | git-flow / release branches — set develop as the default branch and the template works unmodified |

---

## ❓ FAQ

**Q. Isn't the issue template file alone enough?**
No. The template is just a form; the slash commands are what make Claude work to that form. `install.sh` installs both.

**Q. If `/issue-loop` exists, why keep `/next` and the individual commands?**
The loop is an automation layer on top of the individual commands. Use the individual commands when you want to handle a single issue, watch each step yourself, or clean up an issue the loop escalated. It's also why an interrupted loop can be continued manually from anywhere.

**Q. How do I learn about template updates?**
The auto-update workflow checks weekly and opens a PR only when something changed (no auto-merge — review then merge). Re-run the install command to get updates immediately.

**Q. We customized the command files — will updates overwrite them?**
No. Checksums recorded at install time (`.claude/issue-template.lock`) detect local modifications; modified files get the latest version saved as `<file>.new` next to them, with a warning.

**Q. I'm a solo developer — doesn't GitHub refuse approvals on your own PR?**
It does, which is why the source of truth for approve/reject is the **labels** (`review:approved`/`review:rejected`), not the GitHub review state. When `gh pr review --approve` is refused on your own PR, the full verdict lands as a PR comment, and `/issue-loop`'s merge gate and rejection counter only ever look at the labels (and their addition history). The one exception is a repo with a branch-protection rule requiring 1+ approving reviews — a solo account can never satisfy that by GitHub policy, so the loop detects it before starting, warns you, and hands those merges to a human (relax the rule and auto-merge works too).

**Q. What if I need a grouping bigger than a Feature (an Epic)?**
Keep the hierarchy as is and add one issue by hand. Create an issue titled `[Epic]`, write "tracking only" in the body, then attach the `[Feature]` issues created by `/spec` as sub-issues — GitHub sub-issues nest, so the Epic ⊃ Feature ⊃ Task tree and progress bars just work. No command changes needed: `/implement-issue` and `/issue-loop` only ever look at Tasks, and the "tracking only" marker keeps the Epic from being picked up for implementation. Create one only when several features form a single initiative; otherwise Features and milestones are enough.

**Q. Why `/review-pr` instead of native AI code review?**
It's a complement, not a replacement. Native review asks "is this good code?"; `/review-pr` asks "is this **the code we agreed on**?" The issue contract (Non-goals, anchors, acceptance criteria) is grading criteria native tools don't know about — use both.

**Q. What does this actually fix?**

| Problem | How this workflow solves it |
|---|---|
| Hallucinated designs (referencing functions that don't exist) | **file:line evidence required** before design — unverified facts can't enter |
| Diff explosion from drive-by refactoring | **Non-goals required** on every issue |
| "It seems to work" | **Executable verification commands** — the AI runs them itself |
| Delegating huge tasks wholesale → quality collapse | Forced breakdown to **one-session-sized issues** |
| Issue fragmentation | **Sub-issue tree + progress + dependency order** under a parent issue |
| Self-review blind spots | **Separate session + higher model** reviews against the contract |
| Merge conflicts in parallel work | Dependency-free issues have **disjoint code anchors** — worktree-safe |
| Rejection reasons evaporating with the session | Full verdict **recorded as a PR review** — the rework session reads it |
| Broken design premises silently buried | Issue comment + **`needs-respec` label** on GitHub — `/next` surfaces it |
| Session open/close fatigue | **`/issue-loop`** — auto-repeats with per-step subagents, resumes from GitHub state |

---

## Issue body format (auto-generated by the commands)

| Field | Required | Purpose |
|---|---|---|
| Goal | ✅ | The tiebreaker when implementation judgment calls arise |
| Non-goals | ✅ | Blocks scope creep — the single most effective field |
| Code anchors | ✅ | Exact work location at file:line granularity |
| Interface contract | | Signatures/schemas as code |
| Acceptance criteria + verification commands | ✅ | The AI runs them itself. Anything unmeasurable by command is marked `(manual)` → human-checked at review |
| Edge cases | | Decisions already made at design time |
| Dependencies | | Prerequisite issue numbers, design doc link |

## Projects & milestone integration

The "issues registered but project/milestone hooked up by hand" problem disappears with the Step 2 setup:

- **Projects**: the Auto-add workflow (`label:ai-task`) adds issues the moment they're registered — nothing to configure on the command side
- **Board state (Todo/In Progress/Done)**: Todo and Done are moved by GitHub's built-in workflows (step 2 setup), while **In Progress has no signal GitHub can detect**, so `/implement-issue` moves it via the API when work starts. It only runs when the gh token has the `project` scope (`gh auth refresh -s project`); without it, only the board stays put — implement/review/merge proceed as normal
- **Milestones**: `/spec` queries non-expired milestones sorted by due date, confirms during approval, and registers with `--milestone`. If none exist, it doesn't ask
- **Assignee**: `/spec` registers with `--assignee "@me"` (or the assignee you name)
- **Issue types**: parent issues get `Feature`, task issues get `Task` (`Bug` for bug fixes). Issue types are organization-repo-only, so they're skipped automatically on personal repos

## Label system

13 labels created by `install.sh`. Humans never attach them — **the commands do**, turning labels into filterable data. One principle: **only create a label that has a consumer (a command or a human) filtering by it.** Dynamic state like "prerequisites done" never becomes a label — it would rot into a lie, so `/next` computes it live every time.

| Label | Attached by | Meaning · use |
|---|---|---|
| `ai-task` | `/spec` | Identifies AI-delegated work. **The Projects Auto-add filter key** |
| `feat` / `bug` / `refactor` | `/spec` | Work type, for distribution stats |
| `size:S` / `size:M` | `/spec` | Expected diff size (~100 / ~300 lines). **`/issue-loop`'s model-routing input** |
| `size:L` | (never attached) | Signal of >300 lines — the rule is to **split the issue further** instead |
| `review:approved` / `review:rejected` | `/review-pr` | Review verdict record. The `label:review:rejected` filter IS the rejection-rate metric |
| `agent:auto` / `agent:assist` | `/spec` | Can it finish without human input? **Unattended/parallel execution targets `agent:auto` only** — `/next` and `/issue-loop` filter on this |
| `risk:high` | `/spec` | Expensive-to-revert changes (auth, payments, migrations). Stricter review + **human review & merge required** (the loop never touches these) |
| `needs-respec` | `/implement-issue` | Design premise broke during implementation. `/next` shows 🔧 — fix the contract, remove the label, and it's actionable again |

## What is automated

| Task | Auto? | Owner |
|---|---|---|
| Design doc, issue breakdown & registration | 🤖 auto | `/spec` (**only the approval** is human) |
| Labels, milestone, assignee, issue type | 🤖 auto | `/spec` |
| Sub-issue tree & progress | 🤖 auto | `/spec` → GitHub UI |
| Adding issues to the project board | 🤖 auto | Projects **Auto-add** workflow (`label:ai-task`) |
| Board state → In Progress | 🤖 auto | `/implement-issue` moves it via the API when work starts (needs `project` scope; skipped if absent) |
| Board state → Done | 🤖 auto | Projects **Item closed → Done**, **PR merged → Done** workflows |
| Implementation, verification, PR creation | 🤖 auto | `/implement-issue` |
| Rework after rejection | 🤖 auto | `/implement-issue` |
| Recording broken design premises | 🤖 auto | `/implement-issue` (`needs-respec` + issue comment) |
| Review verdict + PR record + verdict label | 🤖 auto | `/review-pr` (**only the merge decision** is human) |
| Implement→review→merge repetition, model routing, resume | 🤖 auto | `/issue-loop` (supervised: human merges; unattended: enhanced review substitutes) |
| Template updates | 🤖 auto | Weekly sync workflow opens a PR (**only the merge** is human) |
| Milestone creation, breakdown approval, `risk:high` review & merge | 👤 human | Deliberately retained judgment points |

What remains for humans is **judgment** (approve what to build, approve the code, merge); recording, wiring, and aggregation are fully automatic.

## Customization

- **Change pinned models**: edit `model:` in the frontmatter of `spec.md` / `review-pr.md` (default opus). Values outside your org's allowlist are silently ignored. `implement-issue.md` is intentionally unpinned — pinning would downgrade higher-model sessions
- **Labels & title prefixes**: edit the `gh issue create` lines in the command files (parent `[Feature]`, task `[Task][<slug> <n>/<total>]`). If you change the numbering rule, update both `spec.md` §4-2 and the board parsing in `next.md`
- **Issue size threshold**: adjust "5 files, 300-line diff" in `spec.md`
- **Local edits coexist with updates**: modified files are never overwritten (latest saved as `.new`)
- **Disable auto-update**: install with `curl ... | ISSUE_TEMPLATE_NO_WORKFLOW=1 bash` (the workflow file is installed once and team-owned afterward)
- **Pin to a version**: `curl -fsSL .../install.sh | ISSUE_TEMPLATE_RAW=https://raw.githubusercontent.com/nlook-service/issue-template/<tag-or-commit> bash` — pin to a commit you've audited
- **Org-wide rollout**: put `ISSUE_TEMPLATE/` in your org's `.github` repository to inherit the issue form everywhere
- **Other AI tools**: the command files are plain markdown — portable to Cursor rules, Copilot instructions, etc.

## 🔒 Security

The data flow and permissions are intentionally simple:

- **No outbound data.** Commands and skills are plain-markdown instructions; the only tools they run are local `git` and your own authenticated `gh` CLI. There is no telemetry or collection code. (The one exception is the explicitly opt-in [Langfuse integration](./integrations/langfuse/README.md) — enabling it sends command arguments to a third-party SaaS; read that README's warnings first.)
- **Review before install** if `curl | bash` concerns you:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/nlook-service/issue-template/main/install.sh -o install.sh
  less install.sh   # review
  bash install.sh
  ```

  Only markdown/YAML templates are installed, everything is downloaded to a temp dir first (a failed download touches nothing), and you can pin to an audited commit via `ISSUE_TEMPLATE_RAW` (see Customization).
- **Auto-update workflow**: actions are **pinned to commit SHAs**, permissions are limited to `contents: write` + `pull-requests: write`, and it **only opens PRs — never auto-merges**. If you don't want to trust upstream, install with `ISSUE_TEMPLATE_NO_WORKFLOW=1`.
- **Unattended auto-merge guardrails**: `--unattended` auto-merge requires the enhanced review + `agent:auto` + not `risk:high` + CI green, all at once. We recommend also enabling **branch protection (required checks)** — GitHub stays the last line of defense even if the loop misjudges.
- **Reporting vulnerabilities**: please use GitHub's **Private vulnerability reporting** (Security tab) instead of a public issue.

## Repository layout

```
issue-template/
├── install.sh                          # install & update script (re-run = update)
├── VERSION                             # release version (bump when distributed files change)
├── design-doc-template.md              # design doc form (one per feature)
├── github/
│   ├── ISSUE_TEMPLATE/
│   │   └── ai-task.yml                 # GitHub issue form (safety net for manual web registration)
│   └── workflows/
│       └── issue-template-sync.yml     # weekly auto-update PR (installed once)
├── claude/
│   ├── commands/
│   │   ├── spec.md                     # [design] requirements → design doc → issues
│   │   ├── implement-issue.md          # [implement] issue number → code → verify → PR
│   │   ├── review-pr.md                # [review] PR vs design doc & issue contract
│   │   └── next.md                     # [navigator] status board + next action
│   └── skills/
│       └── issue-loop/
│           └── SKILL.md                # [loop] implement→review→merge with subagents
└── integrations/
    └── langfuse/                       # (optional) command execution traces — opt-in
```

> Note: the command files and skill are currently written in Korean. Claude follows them regardless of your conversation language; translated command files may come later.

## Optional integrations

- **[Langfuse](./integrations/langfuse/README.md)** — records command executions as traces (opt-in). Enabling it sends command arguments to a third-party SaaS; read the warnings in that README first. (Korean)

## Requirements

- [Claude Code](https://claude.com/claude-code) — runs the slash commands
- [gh CLI](https://cli.github.com/) — issue/PR creation (`gh auth login`)
- (optional) [ccusage](https://github.com/ryoppippi/ccusage) — `/issue-loop`'s usage guard

## Contributing

Issues and PRs welcome. When you modify a distributed file (anything in `install.sh`'s `FILES` list), bump `VERSION` too — consuming repositories' weekly sync uses it to decide whether to update.

## License

[MIT](./LICENSE)
