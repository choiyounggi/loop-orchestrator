#!/usr/bin/env bats
# Tests for status-update.sh and watch-status.sh

setup() {
  SU="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/status-update.sh"
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/watch-status.sh"
  export STATUS_DIR="${BATS_TEST_TMPDIR}/status"
}

@test "status-update: writes valid JSON with task/phase/extra" {
  run bash "$SU" task-1 plan_ready worktree=/some/wt
  [ "$status" -eq 0 ]
  [ "$(jq -r '.task'     "$STATUS_DIR/task-1.json")" = "task-1" ]
  [ "$(jq -r '.phase'    "$STATUS_DIR/task-1.json")" = "plan_ready" ]
  [ "$(jq -r '.worktree' "$STATUS_DIR/task-1.json")" = "/some/wt" ]
}

@test "status-update: missing phase arg errors" {
  run bash "$SU" task-1
  [ "$status" -ne 0 ]
}

@test "watch-status: exit 0 when all sessions reach target" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"done"}' > "$STATUS_DIR/b.json"
  run bash "$WS" "$STATUS_DIR" impl_done 2 5 1
  [ "$status" -eq 0 ]
}

@test "watch-status: exit 3 on a failed session" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"failed"}' > "$STATUS_DIR/a.json"
  run bash "$WS" "$STATUS_DIR" impl_done 1 5 1
  [ "$status" -eq 3 ]
}
