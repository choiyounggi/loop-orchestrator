# Tool profile — pluggable capability roles

loop-orchestrator is environment-neutral by default: it depends on no specific
MCP server, skill, or agent (only the bundled `test-quality-auditor`). The **tool
profile** lets each installation plug its own tools into a few named *capability
roles*. If you configure a role, the skills use your tool; if you don't, they use
the generic built-in behavior. Nothing breaks when nothing is configured.

## Roles

| Role        | Purpose                                          | Used by (step)                          |
| ----------- | ------------------------------------------------ | --------------------------------------- |
| `knowledge` | domain facts, business policy, code/status values | loop-implement step 1 (Analyze); orchestrate Phase 0/2 |
| `tacit`     | past incidents, edge cases, coupling/danger zones | loop-implement step 1 (Analyze) + step 6 (Self-review) |
| `plan`      | producing a non-trivial implementation plan       | loop-implement step 2 (Plan); orchestrate decomposition |

Roles are optional and extensible — you may add custom keys; the resolver passes
them through, and a skill uses a role only if it knows that role by name.

## Config files & precedence

Layered like `git config`, lowest to highest:

```
built-in defaults  <  ~/.claude/loop-orchestrator/tools.json  <  <repo>/.loop-orchestrator/tools.json
```

- **per-user** (`~/.claude/loop-orchestrator/tools.json`) — your machine's tools,
  applied across every project you run the orchestrator in.
- **per-repo** (`<repo>/.loop-orchestrator/tools.json`) — commit it to share a
  team-standard mapping; overrides your per-user file.
- Merge is **per role and per field**: a per-repo file can override one role — or
  one field of a role — and inherit the rest. To drop an inherited value, set that
  field to `null`.

## Schema

```jsonc
{
  "<role>": {
    "kind": "mcp" | "skill" | "agent" | "cli" | "default",
    "ref":  "<server / skill / agent name or command>",   // omit when kind=default
    "how":  "<short invocation hint, e.g. tool call sequence>",  // optional
    "when": "<one line: when this role should be consulted>"     // optional
  }
}
```

- `kind: "default"` (or an omitted role) → use loop-implement's own generic
  behavior for that role (no external dependency).
- Unknown/invalid config file → ignored with a warning (fail-open to defaults).

See `examples/tools.example.json` for an RTB-flavored profile
(wiki-rag / rtb-lore / rtb:plan).

## Resolving (for skills/scripts)

```sh
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh            # resolved JSON
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --summary  # one line per role
sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --role plan
```

`orchestrate` resolves the profile once and writes each role's guidance into the
per-task `<tools_guidance>` brief, so spawned worker sessions get it even if they
can't re-read the config. `loop-implement` resolves it directly when run standalone.
