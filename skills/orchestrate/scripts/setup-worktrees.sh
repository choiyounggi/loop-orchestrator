#!/bin/sh
# setup-worktrees.sh — create an integration branch + one worktree per task.
# Dependency installs run separately (in the background). Ends with a real
# `git worktree list` so callers verify actual state rather than trusting
# echo logs (set -e is fail-open inside some eval subshells).
#
# usage: setup-worktrees.sh <integration-branch> <repo-root> <base-ref> <task-branch>...
#   <integration-branch>  integration (feature) branch name, e.g. feat/my-goal
#   <repo-root>           absolute path to the main worktree
#   <base-ref>            ref to branch the integration branch from, e.g. origin/main
#   <task-branch>...      per-task branch names
set -eu
GIT=$(command -v git) || { echo "setup-worktrees: git not found" >&2; exit 127; }

[ $# -ge 4 ] || { echo "usage: setup-worktrees.sh <integ-branch> <repo-root> <base-ref> <task-branch>..." >&2; exit 1; }
integ="$1"; root="$2"; base="$3"; shift 3

cd "$root"
"$GIT" fetch origin --quiet 2>/dev/null || echo "setup-worktrees: fetch failed — proceeding with local refs" >&2

# 1) integration branch (branch only; keep the main worktree's current branch)
if "$GIT" show-ref --verify --quiet "refs/heads/$integ"; then
  echo "-> $integ already exists"
else
  "$GIT" branch "$integ" "$base"
  echo "ok: $integ (from $base)"
fi

# 2) per-task worktrees (based on the integration branch)
for br in "$@"; do
  safe=$(printf '%s' "$br" | tr '/' '-')
  path="$root/.worktrees/$safe"
  if "$GIT" show-ref --verify --quiet "refs/heads/$br"; then
    [ -d "$path" ] || "$GIT" worktree add "$path" "$br"
    echo "-> $br exists — worktree ensured"
  else
    "$GIT" worktree add -b "$br" "$path" "$integ"
    echo "ok: worktree $path ($br)"
  fi
  # optional env copy if the project provides one (e.g. monorepos)
  if [ -f "$root/scripts/worktree-copy-env.sh" ]; then
    sh "$root/scripts/worktree-copy-env.sh" "$path" >/dev/null 2>&1 \
      && echo "  env copied" || echo "  warn: env copy skipped" >&2
  fi
done

echo "=== VERIFY ==="
"$GIT" worktree list
