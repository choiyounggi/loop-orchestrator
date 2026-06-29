---
name: loop-implement
description: Close a single implementation task with a methodology-grounded verification loop — define done, analyze, plan, write tests first (Red), implement (Green), run, self-review, get an independent test-quality audit, then judge against done; on failure reflect and retry (bounded). Use for one non-trivial task (feature, fix, behavior-changing refactor). Skip for typos, config values, simple renames.
---

# loop-implement — verification loop for a single task

Take one task and drive it to "done" through a closed loop whose steps are
grounded in established methodology (sources at the bottom). This is the worker
half of loop-orchestrator: an orchestrator session hands you one task; you
complete it here. It also works standalone for a single task.

## When to use
- Use: logic changes, new features, bug fixes, behavior-changing refactors.
- Skip: typos, config values, simple rename/import cleanup, one-line edits.

## The loop

```
0. Define done       — write the acceptance criteria + done checklist FIRST,
                        so the loop has an explicit pass/fail target.        [DoD/XP]
1. Analyze           — understand the change; list the test scenarios it needs. [TDD step 1 / PDCA Plan]
2. Plan / design     — for larger tasks only; fold into step 1 if small.       [PDCA Plan]
3. Write tests (Red) — write the failing test(s) BEFORE the code. The test is
                        the spec and the verification oracle. If test-first is
                        impractical (e.g. exploratory UI), fix the acceptance
                        criteria / verification command before implementing.    [TDD test-first]
4. Implement (Green) — minimal code to make the tests pass.                     [TDD Green / PDCA Do]
5. Run tests (Check) — run new + existing tests; preserve failure output.       [PDCA Check / self-testing code]
6. Self-review + refactor — clean up; check bugs, edge cases, resource leaks,
                        input validation, unused code.                          [TDD Refactor / self-review / Self-Refine]
6.5 Independent audit — REQUIRED: call the test-quality-auditor subagent with the
                        task brief, the diff, and the test paths. Do NOT grade
                        your own tests. (self-grading guard)
7. Judge against done — pass only if the done checklist is met AND the auditor
                        returns VERDICT: PASS.                                  [DoD / evaluator]
   - PASS  -> done.
   - FAIL  -> 7b.
7b. Reflect + retry  — state in words why it failed (what the auditor/tests
                        showed), then retry from step 3 with that reflection.
                        Bounded: at most 3 attempts. On the 3rd failure, STOP
                        and escalate with the last failure reason.              [Reflexion / bounded retry]
```

## Calling the auditor (step 6.5)

Use the Agent tool to run the `test-quality-auditor` subagent. Pass it: the task
brief, the change diff (`git diff`), and the test file path(s). It returns:

```
VERDICT: PASS | FAIL
REASONS: ...
```

- `VERDICT: PASS` -> proceed to step 7.
- `VERDICT: FAIL` -> address REASONS by strengthening the tests/code (never by
  weakening tests), increment the attempt count, and loop back to step 3.

This subagent is bundled with the plugin, so it is always available. Do NOT call
other agents by name (e.g. a code-reviewer) — they may not exist in the user's
environment. For optional exploration you may delegate to the core Agent tool
generically, without depending on a specific agent name.

## Guardrails (do not violate)
- Never weaken, delete, or skip tests to make them pass. Green must be honest.
- Bounded retry: at most 3 attempts; then stop and escalate the real failure.
- "I don't know" / "unverified" never counts as pass — stop and report.
- Scale to size: trivial tasks may skip steps 0 and 2 and the test requirement;
  non-trivial tasks run the whole loop.

## Sources
TDD Red-Green-Refactor / test-first (Kent Beck, *Canon TDD* / *TDD by Example*;
Fowler, Self-Testing Code); PDCA/PDSA (Shewhart/Deming); self-review and "improve
the codebase" review bar (Google eng-practices); Definition of Done (Scrum Guide)
+ acceptance criteria (XP); self-verification loops (Self-Refine, Reflexion;
Anthropic, *Building Effective Agents* evaluator-optimizer); bounded retry
(resilience patterns — bounded, with escalation).
