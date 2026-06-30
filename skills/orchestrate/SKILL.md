---
name: orchestrate
description: Orchestrate one natural-language goal into parallel tmux Claude Code sessions — clarify requirements, branch by environment, decompose into tasks (with approval), launch a session per task running loop-implement, review and integration-test, then merge after your confirmation. Use when asked to build/implement a goal "with the orchestrator" or to split work across multiple sessions. For a single task, use loop-implement instead.
---

# orchestrate — multi-session orchestrator

You are the orchestrator. **You do not implement — sessions do.** You clarify,
decompose, distribute, review, integrate, and merge. Autonomy lives inside the
implementation loop; two human gates bracket it (task-split, pre-merge).

Scripts referenced below live in `${CLAUDE_PLUGIN_ROOT}/skills/orchestrate/scripts/`.
Communication: session→orchestrator via `.orchestration/status/<task>.json`;
orchestrator→session via `tmux send-keys` one-liners (templates/session-prompt.md).

## Tool profile
Resolve the pluggable tool profile once up front:
`sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary`. It maps capability
roles — `intake` (issue-tracker work-list source), `knowledge` (domain/policy),
`tacit` (incidents/danger zones), `plan` (planning skill), `verify` (test/build/QA
command), `explore` (code search) — to
whatever tools this installation has, or to generic defaults when unset (optional,
layered per-user then per-repo; see `references/tool-profile.md`). Use
`knowledge`/`tacit` yourself during Clarify/Decompose, and write each task's
resolved roles into its `<tools_guidance>` brief so worker sessions inherit them
even if they can't re-read the config. A role is a tool injected into one step,
never a loop: do not map a role to an implement/verify-loop tool or another
orchestrator (that nests loops); there is no `implement` role.

## Preflight
Run `${CLAUDE_PLUGIN_ROOT}/hooks/preflight.sh` to resolve git/tmux/jq paths and
surface any missing CLI. **git, tmux, and jq are all required** — if any is
missing, stop and ask the user to install it (the SessionStart preflight hook is
advisory only; this skill must hard-require them). For a missing tmux: with the
user's consent, install it (macOS: `brew install tmux`; otherwise advise) before
launching sessions. Never auto-install without consent.

## Phase 0 — Intake + Clarify
Two ways the work-list arrives:
- **`intake` role configured** (e.g. an issue tracker) → if the user names a parent
  issue (key/URL), use the intake tool to read it and its children: the parent gives
  the overall goal/architecture, each child becomes a candidate task. Extract the
  issue key from a URL (last path segment). This is the "Jira-style" entry — only
  taken when `intake` is set *and* the user supplies an issue; otherwise:
- **`intake` unset, or a free-text goal** → the natural-language path (default):
  decompose the goal yourself in Phase 2.

Either way, ask the user — one question at a time — until goal / scope / constraints
/ done criteria are clear enough to decompose. Don't start until they are.

## Phase 1 — Environment branch
- **git repo present** → create a feature (integration) branch + one worktree per
  task. Determine base via `gh repo view --json defaultBranchRef` (fallback: the
  current branch) — measure, don't assume.
- **no git repo** → run `scripts/safe-cleanup.sh init-check <workdir>`. Only if it
  returns ok, `git init` (add a `.gitignore` incl. `.orchestration/` first), then
  proceed as above. If it REFUSEs (nested repo / secrets), stop and report.

## Phase 2 — Decompose
Get the task set: use the `intake` children as candidate tasks if Phase 0 read an
issue, otherwise split the goal into independent tasks yourself. Then, the same way
for both: for each task extract **affected files**, **outputs** (what it newly
creates — component/schema/endpoint/type), and **consumes** (another task's output
it depends on). Build a conflict/dependency matrix from those and topologically sort
into Waves (`conflict-matrix.md`): a dependency edge `A → B` means B consumes A's
output, so A's Wave precedes B's. Detect duplicate outputs and assign a single
producer; others consume (add a dependency edge). Apply a **concurrent-session cap**
(default 4) — if a Wave exceeds it, split it or ask. Tasks in the same Wave are
independent (parallel); a later Wave starts only after the previous Wave is approved.

## 🚦 Gate 1 — task-split approval (REQUIRED)
Report the task list, Waves, session count, and a rough cost note. **Wait for the
user's approval** before launching anything.

## Phase 3 — Launch + plan (per Wave)
**Phases 3–4 repeat per Wave in `## Waves` order.** A later Wave launches only after
the previous Wave is fully approved; `<N>` below = the *current* Wave's task count.
Single-Wave splits run everyone in parallel (the original behavior).

0. **Preceding-interface injection (Wave 2+):** before launching this Wave, fill each
   task's brief `<dependencies>` with the **exact signatures** the approved preceding
   Wave exposed (function/type/component — the real signature, not a paraphrase). This
   is the contract the downstream session plans against; loose text invites drift.
   Wave 1 skips this.
1. `scripts/setup-worktrees.sh <integ> <root> <base> <branch>...` then verify with
   `git worktree list`.
2. Per task: write `briefs/<task>.md` (templates/brief.md) — fill `<tools_guidance>`
   from the resolved tool profile so the session uses the right knowledge/tacit/plan
   tools — then
   `scripts/launch-session.sh lo-<n> <worktree> bypassPermissions "<plan prompt>"`
   (plan prompt = templates/session-prompt.md §1, with the subagent protocol block).
3. `scripts/watch-status.sh <status-dir> plan_ready <N>` in the background; when it
   exits, collect `plans/<task>.md`.
   *(Plans proceed autonomously per the user's choice — no per-plan gate.)*

## Phase 4 — Implement + review (max 3 rework)
Inject §2 (implement) to each session; `watch-status ... impl_done <N>`. Review each
worktree diff (`git -C <wt> diff <integ>...HEAD`); if a session's tests look weak,
**cross-call `test-quality-auditor` yourself** (self-call + orchestrator cross-call).
On shortfall, write `reviews/<task>-rN.md`, inject §3 (rework), repeat. After 3
failed rounds, escalate. When this Wave's tasks are all approved, return to Phase 3
step 0 for the next Wave (inject its preceding-interface signatures); once the last
Wave is approved, go to Phase 5.

## Phase 5 — Integration test loop (max 3)
Merge-preview onto the integration branch and run the integration tests (use the
`verify` role's command if configured). On failure, route back to the responsible
session as rework. Repeat until green.

## 🚦 Gate 2 — pre-merge review (REQUIRED)
Show the full integration diff (`git diff`). **Wait for the user's confirmation.**

## Phase 6 — Cleanup + merge (only after Gate 2)
1. `scripts/safe-cleanup.sh merge <root> <integ> <branch>...` — refuses dirty
   worktrees, merges sequentially, stops + reports on conflict (no --force).
2. `scripts/safe-cleanup.sh remove-worktrees <root> <branch>...` (after merge
   verified; skips any dirty worktree).
3. `scripts/safe-cleanup.sh kill-sessions lo-<n>...` (exact names only).
**Local merge into the feature branch only.** Remote push / PR is the user's job.

## Re-entry (resume)
On re-invocation with no context, measure real state first: `git worktree list`,
each `.orchestration/status/*.json` phase, and which `briefs/plans/reviews/`
artifacts exist. Resume from the earliest incomplete step (idempotently skip done
steps). Check `tmux ls`; relaunch dead sessions and re-inject the right prompt.

## Guardrails
- You never implement — sessions do; you analyze, plan, review, manage.
- Gate 1 (task-split) and Gate 2 (pre-merge) are mandatory; everything else autonomous.
- No remote push, no PR, no force-push. Destructive cleanup only after Gate 2, via
  safe-cleanup (never --force).
- Sessions must not weaken tests (loop-implement guard); the auditor enforces it.
- Always verify real state after worktree/session ops (`git worktree list`, `tmux ls`,
  status files) — never trust echo logs (set -e is fail-open in eval subshells).
- Bundled agent only: `test-quality-auditor`. Don't depend on built-in agent names
  (general-purpose/Explore/Plan are version-dependent).
