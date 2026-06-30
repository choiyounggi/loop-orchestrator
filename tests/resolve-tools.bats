#!/usr/bin/env bats
# Tests for resolve-tools.sh — layered tool-profile resolution.

setup() {
  RT="${BATS_TEST_DIRNAME}/../scripts/resolve-tools.sh"
  HOME_CFG="${BATS_TEST_TMPDIR}/home.json"
  PROJ_CFG="${BATS_TEST_TMPDIR}/proj.json"
  # point both layers at the tmpdir; create per-test as needed
  export LOOP_ORCH_CONFIG_HOME="$HOME_CFG"
  export LOOP_ORCH_CONFIG_PROJECT="$PROJ_CFG"
}

@test "no config: every role resolves to default" {
  run bash "$RT" --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.knowledge.kind')" = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.tacit.kind')"     = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.plan.kind')"      = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.verify.kind')"    = "default" ]
  [ "$(printf '%s' "$output" | jq -r '.explore.kind')"   = "default" ]
}

@test "verify role is configurable like the others" {
  printf '{"verify":{"kind":"cli","ref":"pnpm test"}}' > "$PROJ_CFG"
  run bash "$RT" --role verify
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "pnpm test" ]
}

@test "home config: a configured role is used" {
  printf '{"knowledge":{"kind":"mcp","ref":"wiki-rag"}}' > "$HOME_CFG"
  run bash "$RT" --role knowledge
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "wiki-rag" ]
}

@test "project overrides home per role" {
  printf '{"plan":{"kind":"skill","ref":"home:Plan"}}'   > "$HOME_CFG"
  printf '{"plan":{"kind":"skill","ref":"rtb:plan"}}'    > "$PROJ_CFG"
  run bash "$RT" --role plan
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "rtb:plan" ]
}

@test "merge is field-wise: project keeps home fields it does not set" {
  printf '{"knowledge":{"kind":"mcp","ref":"wiki-rag","how":"wiki_search"}}' > "$HOME_CFG"
  printf '{"knowledge":{"how":"wiki_query_context"}}'                        > "$PROJ_CFG"
  run bash "$RT" --role knowledge
  [ "$(printf '%s' "$output" | jq -r '.ref')" = "wiki-rag" ]            # inherited
  [ "$(printf '%s' "$output" | jq -r '.how')" = "wiki_query_context" ] # overridden
}

@test "invalid config layer fails open to lower layers (no crash)" {
  printf 'not json at all' > "$HOME_CFG"
  # stdout must stay pure JSON; the "invalid config" warning goes to stderr
  # (drop it so jq parses only the resolved object).
  run bash -c "bash '$RT' --role knowledge 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "default" ]
}

@test "invalid config: warning goes to stderr, not stdout" {
  printf 'not json at all' > "$HOME_CFG"
  run bash -c "bash '$RT' --role knowledge 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"ignoring invalid config"* ]]
}

@test "unknown arg errors" {
  run bash "$RT" --bogus
  [ "$status" -ne 0 ]
}

@test "summary prints one line per role with assertions" {
  printf '{"tacit":{"kind":"mcp","ref":"rtb-lore"}}' > "$PROJ_CFG"
  run bash "$RT" --summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tacit: mcp rtb-lore"
  echo "$output" | grep -q "knowledge: default"
}
