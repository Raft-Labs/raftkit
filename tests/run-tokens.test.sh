#!/usr/bin/env bash
# Contract suite for plugins/raftkit-dev/scripts/run-tokens.mjs --stages:
# per-stage wall-clock minutes (intake, plan, build, review, stop) split at
# markers v2.1 and v3 runs both leave in the same place, and cache-read tokens
# reported apart from a list-price cost that follows each model's price. The
# plain line, quoted by older STOPs and pinned in tests/telemetry.test.sh section 16, is
# unchanged; any failure is "Token total: not measured".
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
# Usage u: 100k input, 10k output, 1M cache read, 40k cache write = 1,150,000
# raw tokens. On claude-opus-5-5 ($4 in, $20 out, $0.20 cache read, cache
# write 1.25x input, per million) that is 0.40 + 0.20 + 0.20 + 0.20 = $1.00; on
# claude-haiku-4-5 ($1, $5, cache read 0.1x) it is 0.10 + 0.05 + 0.10 + 0.05 = $0.30.
node - "$PROJ" <<'FIXTURE'
const fs = require("fs");
const [proj] = process.argv.slice(2);
const T0 = Date.parse("2026-11-25T10:00:00.000Z");
const at = (min) => new Date(T0 + min * 60000).toISOString();
const u = { input_tokens: 100000, output_tokens: 10000, cache_read_input_tokens: 1000000, cache_creation_input_tokens: 40000 };
const zero = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 };
let n = 0;
const msg = (min, content, usage = zero, model = "claude-opus-5-5", id = `m${n++}`) =>
  JSON.stringify({ type: "assistant", timestamp: at(min), isSidechain: false, message: { id, model, usage, content } });
const tool = (name, input) => [{ type: "tool_use", name, input }];
const text = (t) => [{ type: "text", text: t }];
const user = (min, t) => JSON.stringify({ type: "user", timestamp: at(min), message: { role: "user", content: t } });
const bash = (command) => tool("Bash", { command });
const agent = (subagent_type) => tool("Agent", { subagent_type, model: "sonnet" });

// A v2.1-ordered implement run: branch before exploring, the simplifier as a
// subagent, every marker present.
fs.writeFileSync(`${proj}/full.jsonl`, [
  user(-5, "hello"),
  msg(-4, text("before the run"), u),
  msg(0, tool("Skill", { skill: "raftkit-dev:implement" }), u),
  msg(0.5, tool("mcp__1234__get_task", { task_gid: "1" })),
  msg(1, bash("node /x/scripts/verify.mjs --only typecheck")),
  msg(1.5, bash("git checkout -b feat/123-x")),
  msg(2, tool("Read", { file_path: "/repo/src/x.ts" })),
  msg(5, tool("Write", { file_path: "/repo/docs/specs/feat-123-x.md", content: "plan" })),
  msg(6, tool("Edit", { file_path: "/repo/docs/specs/feat-123-x.md" })),
  msg(7, bash("node /x/scripts/scope-check.mjs --hash")),
  msg(28, agent("pr-review-toolkit:code-simplifier")),
  msg(30, agent("pr-review-toolkit:code-reviewer")),
  msg(32, bash("node /x/scripts/verify.mjs")),
  msg(37, bash("node /x/scripts/verify.mjs")),
  msg(39, text("Drafting the PR.")),
  msg(40, bash("node /x/scripts/run-tokens.mjs sid --stages")),
  msg(41, text("Story ready to raise.\n**STOP** — approve to push and raise, edit to change, or decline.")),
  user(50, "go"),
].join("\n") + "\n");

// A v3-ordered run, measured in-run: explore before branching, simplify
// inline, the gate batch as one parallel message, no STOP line yet.
fs.writeFileSync(`${proj}/v3.jsonl`, [
  msg(0, tool("Skill", { skill: "raftkit-dev:implement" }), u),
  msg(0.2, tool("mcp__1234__get_task", { task_gid: "1" }), zero, "claude-opus-5-5", "intake"),
  msg(0.2, bash("git fetch origin develop"), zero, "claude-opus-5-5", "intake"),
  msg(3, tool("Read", { file_path: "/repo/src/x.ts" })),
  msg(4, tool("Grep", { pattern: "badge" })),
  msg(6, bash("git checkout -b feat/123-x")),
  msg(7, tool("Write", { file_path: "/repo/docs/specs/feat-123-x.md", content: "plan" })),
  msg(8, bash("node /x/scripts/scope-check.mjs --hash")),
  msg(20, tool("Edit", { file_path: "/repo/src/x.ts" })),
  msg(25, agent("pr-review-toolkit:code-reviewer"), zero, "claude-opus-5-5", "gate"),
  msg(25, bash("node /x/scripts/verify.mjs"), zero, "claude-opus-5-5", "gate"),
  msg(25, bash("node /x/scripts/scope-check.mjs --base abc"), zero, "claude-opus-5-5", "gate"),
  msg(33, bash("node /x/scripts/verify.mjs")),
  msg(34, text("Drafting the PR.")),
  msg(35, bash("node /x/scripts/run-tokens.mjs sid --stages")),
].join("\n") + "\n");

// No branch, no story read (an existing branch), the review found by
// scope-check, and no STOP yet: the run is measured up to its last record.
fs.writeFileSync(`${proj}/partial.jsonl`, [
  msg(0, tool("Skill", { skill: "raftkit-dev:fix" }), u),
  msg(4, tool("MultiEdit", { file_path: "docs/specs/fix-9.md" })),
  msg(20, bash("node /x/scripts/scope-check.mjs --base abc")),
  msg(26, text("still reviewing")),
].join("\n") + "\n");

// The same usage on three models: the cost follows each model's price, and a
// model with no listed price is counted apart, never priced as another.
fs.writeFileSync(`${proj}/models.jsonl`, [
  msg(0, tool("Skill", { skill: "raftkit-dev:implement" }), u),
  msg(1, text("a"), u, "claude-haiku-4-5"),
  msg(2, text("b"), u, "claude-mystery-1"),
].join("\n") + "\n");
FIXTURE

rt() { env CLAUDE_CONFIG_DIR="$CFG" RAFTKIT_TELEMETRY_DIR="$TEST_ROOT/state" CLAUDE_PLUGIN_DATA="$TEST_ROOT/state" node "$RUN_TOKENS" "$@" 2>/dev/null; }
ONE="Token total: 1,150,000 tokens (main 1,150,000, subagents 0; claude-opus-5-5: 1,150,000) — measured"

expect_eq "the plain line is unchanged without --stages" "$ONE" "$(rt full)"

out="$(rt full --stages)"
expect_eq "--stages still prints exactly one line" "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
expect_eq "--stages adds cache reads, list-price cost and per-stage minutes; the simplifier and --hash open no stage" \
  "$ONE; cache-read 1,000,000, cost-weighted \$1.00 at list price; minutes: intake 2.0, plan 3.0, build 25.0, review 9.0, stop 2.0" "$out"

expect_eq "a v3-ordered run splits at the same places: exploring before the branch is plan, inline simplify is build" \
  "$ONE; cache-read 1,000,000, cost-weighted \$1.00 at list price; minutes: intake 3.0, plan 4.0, build 18.0, review 9.0, stop 1.0" \
  "$(rt v3 --stages)"

expect_eq "a missing marker folds its stage into the one before, and no STOP measures to the last record" \
  "$ONE; cache-read 1,000,000, cost-weighted \$1.00 at list price; minutes: intake+plan 4.0, build 16.0, review+stop 6.0" \
  "$(rt partial --stages)"

expect_eq "the same usage costs what each model's price says; an unpriced model is counted apart" \
  "Token total: 3,450,000 tokens (main 3,450,000, subagents 0; claude-opus-5-5: 1,150,000, claude-haiku-4-5: 1,150,000, claude-mystery-1: 1,150,000) — measured; cache-read 3,000,000, cost-weighted \$1.30 at list price (unpriced: 1,150,000 tokens); minutes: intake+plan+build+review+stop 2.0" \
  "$(rt models --stages)"

expect_eq "--session with --stages measures the whole session" \
  "Token total: 2,300,000 tokens (main 2,300,000, subagents 0; claude-opus-5-5: 2,300,000) — measured; cache-read 2,000,000, cost-weighted \$2.00 at list price; minutes: intake 7.0, plan 3.0, build 25.0, review 9.0, stop 2.0" \
  "$(rt full --stages --session)"

expect_eq "an unknown session with --stages keeps the not-measured fallback" \
  "Token total: not measured" "$(rt nosuchsession --stages)"

tree_sum() { find "$TEST_ROOT" -type f -print0 | sort -z | xargs -0 cksum | cksum; }
before="$(tree_sum)"
rt full --stages >/dev/null
expect_eq "--stages writes nothing" "$before|no" "$(tree_sum)|$([[ -e "$TEST_ROOT/state" ]] && echo yes || echo no)"

echo
if [[ "$failures" -gt 0 ]]; then echo "$failures test(s) failed"; exit 1; fi
echo "all tests passed"
