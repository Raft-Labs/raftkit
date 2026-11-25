#!/usr/bin/env bash
# Contract suite for plugins/raftkit-dev/scripts/run-tokens.mjs --stages:
# per-stage wall-clock minutes (intake, plan, build, review, stop) split at
# markers the transcript always carries, and cache-read tokens reported apart
# from cost-weighted tokens. The plain line, quoted by older STOPs and pinned
# in tests/shunt.test.sh, is unchanged; any failure is "Token total: not measured".
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
cd "$(dirname "$0")/.." || exit 2
RUN_TOKENS="$PWD/plugins/raftkit-dev/scripts/run-tokens.mjs"

failures=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
expect_eq() { # <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "PASS: $1"; else
    echo "FAIL: $1"; echo "  expected: $2"; echo "  actual:   $3"; failures=$((failures + 1)); fi
}

CFG="$TEST_ROOT/cfg"
PROJ="$CFG/projects/-fixture"
mkdir -p "$PROJ"
# Usage u(100, 10, 1000, 40): 1,150 raw tokens; cost-weighted in input-token
# equivalents is 100 + 5*10 + 0.1*1000 + 1.25*40 = 300.
node - "$PROJ" <<'FIXTURE'
const fs = require("fs");
const [proj] = process.argv.slice(2);
const T0 = Date.parse("2026-11-25T10:00:00.000Z");
const at = (min) => new Date(T0 + min * 60000).toISOString();
const u = { input_tokens: 100, output_tokens: 10, cache_read_input_tokens: 1000, cache_creation_input_tokens: 40 };
const zero = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 };
let n = 0;
const msg = (min, content, usage = zero) =>
  JSON.stringify({ type: "assistant", timestamp: at(min), isSidechain: false, message: { id: `m${n++}`, model: "claude-opus-5-5", usage, content } });
const tool = (name, input) => [{ type: "tool_use", name, input }];
const text = (t) => [{ type: "text", text: t }];
const user = (min, t) => JSON.stringify({ type: "user", timestamp: at(min), message: { role: "user", content: t } });

// A full implement run: every marker present, in order.
fs.writeFileSync(`${proj}/full.jsonl`, [
  user(-5, "hello"),
  msg(-4, text("before the run"), u),
  msg(0, tool("Skill", { skill: "raftkit-dev:implement" }), u),
  msg(1, tool("Bash", { command: "node /x/scripts/verify.mjs --only typecheck" })),
  msg(2, tool("Bash", { command: "git checkout -b feat/123-x" })),
  msg(5, tool("Write", { file_path: "/repo/docs/specs/feat-123-x.md", content: "plan" })),
  msg(6, tool("Edit", { file_path: "/repo/docs/specs/feat-123-x.md" })),
  msg(30, tool("Agent", { subagent_type: "pr-review-toolkit:code-reviewer", model: "sonnet" })),
  msg(32, tool("Bash", { command: "node /x/scripts/verify.mjs" })),
  msg(40, tool("Bash", { command: "node /x/scripts/run-tokens.mjs sid --stages" })),
  msg(41, text("Story ready to raise.\n**STOP** — approve to push and raise, edit to change, or decline.")),
  user(50, "go"),
].join("\n") + "\n");

// No branch created (an existing branch), the review found by scope-check,
// and no STOP yet: the run is measured up to its last record.
fs.writeFileSync(`${proj}/partial.jsonl`, [
  msg(0, tool("Skill", { skill: "raftkit-dev:fix" }), u),
  msg(4, tool("MultiEdit", { file_path: "docs/specs/fix-9.md" })),
  msg(20, tool("Bash", { command: "node /x/scripts/scope-check.mjs --base abc" })),
  msg(26, text("still reviewing")),
].join("\n") + "\n");
FIXTURE

rt() { env CLAUDE_CONFIG_DIR="$CFG" RAFTKIT_TELEMETRY_DIR="$TEST_ROOT/state" CLAUDE_PLUGIN_DATA="$TEST_ROOT/state" node "$RUN_TOKENS" "$@" 2>/dev/null; }

expect_eq "the plain line is unchanged without --stages" \
  "Token total: 1,150 tokens (main 1,150, subagents 0; claude-opus-5-5: 1,150) — measured" "$(rt full)"

out="$(rt full --stages)"
expect_eq "--stages still prints exactly one line" "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
expect_eq "--stages adds cache reads, cost-weighted tokens and per-stage minutes" \
  "Token total: 1,150 tokens (main 1,150, subagents 0; claude-opus-5-5: 1,150) — measured; cache-read 1,000, cost-weighted 300 input-token equivalents; minutes: intake 2.0, plan 3.0, build 25.0, review 10.0, stop 1.0" "$out"

expect_eq "a missing marker folds its stage into the one before, and no STOP measures to the last record" \
  "Token total: 1,150 tokens (main 1,150, subagents 0; claude-opus-5-5: 1,150) — measured; cache-read 1,000, cost-weighted 300 input-token equivalents; minutes: intake+plan 4.0, build 16.0, review+stop 6.0" \
  "$(rt partial --stages)"

expect_eq "--session with --stages measures the whole session" \
  "Token total: 2,300 tokens (main 2,300, subagents 0; claude-opus-5-5: 2,300) — measured; cache-read 2,000, cost-weighted 600 input-token equivalents; minutes: intake 7.0, plan 3.0, build 25.0, review 10.0, stop 1.0" \
  "$(rt full --stages --session)"

expect_eq "an unknown session with --stages keeps the not-measured fallback" \
  "Token total: not measured" "$(rt nosuchsession --stages)"

tree_sum() { find "$TEST_ROOT" -type f -print0 | sort -z | xargs -0 cksum | cksum; }
before="$(tree_sum)"
rt full --stages >/dev/null
expect_eq "--stages writes nothing" "$before|no" "$(tree_sum)|$([[ -e "$TEST_ROOT/state" ]] && echo yes || echo no)"

grep -qE '^// Stages split at ' plugins/raftkit-core/hooks/lib/tokens.mjs
expect_eq "the stage heuristic is documented in one line" "0" "$?"

echo
if [[ "$failures" -gt 0 ]]; then echo "$failures test(s) failed"; exit 1; fi
echo "all tests passed"
