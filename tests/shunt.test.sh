#!/usr/bin/env bash
# Proves the bulk-read shunt is safe and correct:
#   1. an oversized read is denied, with the bulk-reader instruction attached
#   2. everything else is allowed — under threshold, narrowed by offset/limit,
#      binary, missing, outside the repo, a directory, an unparsable payload
#   3. instruction files (CLAUDE.md, SKILL.md, plan records, the agreement)
#      are never shunted at any size — the load-bearing exemption, because a
#      paraphrased scope contract is worse than an expensive one
#   4. the kill switch and the threshold override are honoured
#   5. the bash forms it claims to catch are caught, and the ones it cannot
#      parse with certainty are left alone
#   6. every failure path exits 0 and prints nothing (fail open)
#   7. a deny is recorded as telemetry; an allow costs no telemetry at all
#   8. token accounting folds a transcript correctly and resumes incrementally
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
cd "$(dirname "$0")/.."

SHUNT="$PWD/plugins/raftkit-core/hooks/shunt.mjs"
failures=0

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# The hook resolves paths against the payload's cwd, so every case runs against
# a throwaway repo rather than this one — a test must never depend on the
# contents of the checkout it is running in.
REPO="$TEST_ROOT/repo"
mkdir -p "$REPO/src" "$REPO/docs/specs" "$REPO/plugins/x/skills/y"
seq 1 900 > "$REPO/src/big.ts"
seq 1 100 > "$REPO/src/small.ts"
seq 1 900 > "$REPO/CLAUDE.md"
seq 1 900 > "$REPO/plugins/x/skills/y/SKILL.md"
seq 1 900 > "$REPO/docs/specs/feat-branch.md"
seq 1 900 > "$REPO/src/my-skills-notes.md"   # NOT inside skills/ — must shunt
printf 'a\0b\n%.0s' $(seq 1 900) > "$REPO/src/blob.bin"
seq 1 500 > "$REPO/src/exact.ts"          # exactly at the default threshold
seq 1 900 > "$TEST_ROOT/outside-big.ts"   # oversized, but not in the repo

expect_eq() { # <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected '$2', got '$3')"
    failures=$((failures + 1))
  fi
}

# Run the hook with a payload and echo its verdict: "deny" or "allow".
# Any non-zero exit is reported as "crash", which no case may ever produce.
verdict() { # <payload-json> [env assignments...]
  local payload="$1"; shift
  local out status
  out="$(printf '%s' "$payload" | env RAFTKIT_TELEMETRY_DIR="$TEST_ROOT/spool-$RANDOM" "$@" node "$SHUNT" 2>/dev/null)"
  status=$?
  if [[ "$status" -ne 0 ]]; then echo "crash"; return; fi
  if [[ -z "$out" ]]; then echo "allow"; return; fi
  node -e '
    const j = JSON.parse(require("fs").readFileSync(0, "utf8"));
    process.stdout.write(j.hookSpecificOutput?.permissionDecision ?? "malformed");
  ' <<< "$out"
}

reason() { # <payload-json>
  printf '%s' "$1" | env RAFTKIT_TELEMETRY_DIR="$TEST_ROOT/spool-$RANDOM" node "$SHUNT" 2>/dev/null |
    node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8"));process.stdout.write(j.hookSpecificOutput?.permissionDecisionReason??"");'
}

read_payload() { # <path> [extra-json]
  printf '{"session_id":"s1","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Read","tool_input":{"file_path":"%s"%s}}' \
    "$REPO" "$1" "${2:-}"
}

bash_payload() { # <command>
  node -e '
    const [cwd, cmd] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({
      session_id: "s1", hook_event_name: "PreToolUse", cwd,
      tool_name: "Bash", tool_input: { command: cmd },
    }));
  ' "$REPO" "$1"
}

# ------------------------------------------------------- 1. the one deny
expect_eq "an oversized read is denied" "deny" "$(verdict "$(read_payload "$REPO/src/big.ts")")"
expect_eq "a relative path resolves against cwd and is denied" "deny" "$(verdict "$(read_payload "src/big.ts")")"

r="$(reason "$(read_payload "$REPO/src/big.ts")")"
grep -q "src/big.ts is 900 lines" <<< "$r" && echo "PASS: the reason names the file and its real line count" ||
  { echo "FAIL: reason line count (got: ${r:0:80})"; failures=$((failures + 1)); }
grep -q 'subagent_type: "bulk-reader"' <<< "$r" && echo "PASS: the reason carries the bulk-reader call" ||
  { echo "FAIL: reason lacks the bulk-reader call"; failures=$((failures + 1)); }
grep -q "offset/limit" <<< "$r" && echo "PASS: the reason names the route back for editing" ||
  { echo "FAIL: reason lacks the edit route"; failures=$((failures + 1)); }
grep -q "RAFTKIT_SHUNT=off" <<< "$r" && echo "PASS: the reason names the bypass" ||
  { echo "FAIL: reason lacks the bypass"; failures=$((failures + 1)); }

# -------------------------------------------------------- 2. allow paths
expect_eq "a read under the threshold is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/small.ts")")"
# The boundary is inclusive: a file of exactly N lines is at the threshold and
# is shunted. An off-by-one here silently raises the threshold by one line.
expect_eq "a file exactly at the threshold is denied" "deny" "$(verdict "$(read_payload "$REPO/src/exact.ts")")"
expect_eq "a file one line under the threshold is allowed" "allow" \
  "$(verdict "$(read_payload "$REPO/src/exact.ts")" RAFTKIT_SHUNT_MIN_LINES=501)"
expect_eq "a read narrowed by offset is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/big.ts" ',"offset":10')")"
expect_eq "a read narrowed by limit is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/big.ts" ',"limit":50')")"
expect_eq "a binary file is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/blob.bin")")"
expect_eq "a missing file is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/nope.ts")")"
# stat succeeds and the read fails: the one case where the line count is
# genuinely unknown. Unknown must mean allow, never deny — treating a failed
# count as "definitely oversized" turns a fail-open into a fail-closed.
seq 1 900 > "$REPO/src/locked.ts"; chmod 000 "$REPO/src/locked.ts"
if cat "$REPO/src/locked.ts" >/dev/null 2>&1; then
  echo "SKIP: an unreadable file is allowed (running with read-everything privileges)"
else
  expect_eq "an unreadable oversized file is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/locked.ts")")"
fi
chmod 644 "$REPO/src/locked.ts"
expect_eq "a directory is allowed" "allow" "$(verdict "$(read_payload "$REPO/src")")"
# Oversized on purpose: a small file outside the repo would be allowed by the
# threshold alone and would prove nothing about containment.
expect_eq "an oversized file outside the repo is allowed" "allow" \
  "$(verdict "$(read_payload "$TEST_ROOT/outside-big.ts")")"
expect_eq "another tool is allowed" "allow" \
  "$(verdict '{"cwd":"'"$REPO"'","tool_name":"Grep","tool_input":{"pattern":"x"}}')"

# A symlink inside the repo pointing out of it must not be shunted — and must
# not crash. realpath is what makes the containment check mean anything.
ln -s /etc/hosts "$REPO/src/escape.ts"
expect_eq "a symlink escaping the repo is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/escape.ts")")"
ln -s ../../../etc "$REPO/src/updir"
expect_eq "a traversal path is allowed" "allow" "$(verdict "$(read_payload "$REPO/src/updir/hosts")")"

# ------------------------------------------- 3. instructions are never shunted
expect_eq "CLAUDE.md is never shunted" "allow" "$(verdict "$(read_payload "$REPO/CLAUDE.md")")"
expect_eq "a SKILL.md is never shunted" "allow" "$(verdict "$(read_payload "$REPO/plugins/x/skills/y/SKILL.md")")"
expect_eq "anything under skills/ is never shunted" "allow" \
  "$(verdict "$(read_payload "$REPO/plugins/x/skills/y/SKILL.md")")"
expect_eq "a plan record is never shunted" "allow" "$(verdict "$(read_payload "$REPO/docs/specs/feat-branch.md")")"
# The exemption is by path segment, not substring: a file merely named
# "...skills..." is ordinary content and must still be shunted.
expect_eq "a lookalike path is still shunted" "deny" "$(verdict "$(read_payload "$REPO/src/my-skills-notes.md")")"

# ------------------------------- 3b. the bulk-reader is not policed
# The hook runs inside subagent tool calls too, so without this the one agent
# whose job is the oversized read is the one agent denied it.
for field in agent_type subagent_type agent_name agentType agent_id; do
  expect_eq "the bulk-reader bypasses the shunt via $field" "allow" \
    "$(verdict "$(node -e '
        const [cwd, file, field] = process.argv.slice(1);
        process.stdout.write(JSON.stringify({
          cwd, tool_name: "Read", tool_input: { file_path: file }, [field]: "bulk-reader",
        }));
      ' "$REPO" "$REPO/src/big.ts" "$field")")"
done
expect_eq "another agent is still policed" "deny" \
  "$(verdict "$(node -e '
      const [cwd, file] = process.argv.slice(1);
      process.stdout.write(JSON.stringify({
        cwd, tool_name: "Read", tool_input: { file_path: file }, subagent_type: "code-reviewer",
      }));
    ' "$REPO" "$REPO/src/big.ts")")"
# The hard defence, which needs no payload field at all: a paged read is
# exempt, so the agent can always get the text even if it is not recognised.
expect_eq "a paged read by an unrecognised agent is allowed" "allow" \
  "$(verdict "$(read_payload "$REPO/src/big.ts" ',"offset":1,"limit":1500')")"
# The deny text must name that route, or an unrecognised bulk-reader is stuck.
grep -q "offset and limit" <<< "$r" && echo "PASS: the reason names the paged-read route" ||
  { echo "FAIL: reason lacks the paged-read route"; failures=$((failures + 1)); }

# ------------------------------------------ 4. kill switch and threshold
expect_eq "RAFTKIT_SHUNT=off allows everything" "allow" \
  "$(verdict "$(read_payload "$REPO/src/big.ts")" RAFTKIT_SHUNT=off)"
expect_eq "a raised threshold allows the same file" "allow" \
  "$(verdict "$(read_payload "$REPO/src/big.ts")" RAFTKIT_SHUNT_MIN_LINES=1000)"
expect_eq "a lowered threshold denies a smaller file" "deny" \
  "$(verdict "$(read_payload "$REPO/src/small.ts")" RAFTKIT_SHUNT_MIN_LINES=50)"
# A misconfigured threshold must fall back to the default, never to zero —
# zero would shunt every read in the repo, including one-line files.
expect_eq "a junk threshold falls back to the default" "allow" \
  "$(verdict "$(read_payload "$REPO/src/small.ts")" RAFTKIT_SHUNT_MIN_LINES=abc)"
expect_eq "a zero threshold falls back to the default" "allow" \
  "$(verdict "$(read_payload "$REPO/src/small.ts")" RAFTKIT_SHUNT_MIN_LINES=0)"

# -------------------------------------------------------- 5. bash forms
expect_eq "cat on a big file is denied" "deny" "$(verdict "$(bash_payload "cat $REPO/src/big.ts")")"
expect_eq "cat piped into grep is denied" "deny" "$(verdict "$(bash_payload "cat $REPO/src/big.ts | grep foo")")"
expect_eq "head -n above the threshold is denied" "deny" "$(verdict "$(bash_payload "head -n 900 $REPO/src/big.ts")")"
expect_eq "head -n below the threshold is allowed" "allow" "$(verdict "$(bash_payload "head -n 20 $REPO/src/big.ts")")"
expect_eq "cat on a small file is allowed" "allow" "$(verdict "$(bash_payload "cat $REPO/src/small.ts")")"
expect_eq "grep is allowed" "allow" "$(verdict "$(bash_payload "grep -n foo $REPO/src/big.ts")")"
# Anything it cannot parse with certainty must pass through untouched.
expect_eq "a chained command is allowed" "allow" \
  "$(verdict "$(bash_payload "cat $REPO/src/big.ts; rm -f /tmp/x")")"
expect_eq "a command substitution is allowed" "allow" \
  "$(verdict "$(bash_payload "cat \$(echo $REPO/src/big.ts)")")"
expect_eq "a redirect is allowed" "allow" "$(verdict "$(bash_payload "cat $REPO/src/big.ts > /tmp/out")")"
# These two match the cat-into-pipe shape and are rejected only by the guard on
# chaining. Without it the hook would claim to understand a compound command.
expect_eq "a pipe followed by a chained command is allowed" "allow" \
  "$(verdict "$(bash_payload "cat $REPO/src/big.ts | grep x; rm -f /tmp/y")")"
expect_eq "an or-chain is allowed" "allow" \
  "$(verdict "$(bash_payload "cat $REPO/src/big.ts || echo missing")")"
expect_eq "cat with two files is allowed" "allow" \
  "$(verdict "$(bash_payload "cat $REPO/src/big.ts $REPO/src/small.ts")")"

# ------------------------------------------------- 6. fail open, always
for bad in '' 'not json' '{' '[]' 'null' '{"tool_name":"Read"}' '{"tool_name":"Read","tool_input":null}' \
           '{"tool_name":"Read","tool_input":{"file_path":123}}' '{"tool_name":"Read","tool_input":{"file_path":""}}'; do
  expect_eq "malformed payload is allowed: ${bad:0:32}" "allow" "$(verdict "$bad")"
done
# No cwd at all: the hook must not shunt on a guess about where it is.
expect_eq "a payload with no cwd never crashes" "allow" \
  "$(verdict '{"tool_name":"Read","tool_input":{"file_path":"/nonexistent/zzz.ts"}}')"

# ------------------------------------------------------- 7. telemetry
d="$TEST_ROOT/tele"; mkdir -p "$d"
printf '%s' "$(read_payload "$REPO/src/big.ts")" |
  env RAFTKIT_TELEMETRY_DIR="$d" PATH="$TEST_ROOT/stub:$PATH" node "$SHUNT" >/dev/null 2>&1
expect_eq "a deny is recorded" "raftkit_shunt" \
  "$(node -e 'const fs=require("fs");const p=process.argv[1]+"/spool/events.jsonl";
     process.stdout.write(fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8").trim().split("\n").pop()).event:"none");' "$d")"
expect_eq "the deny records the lines it avoided" "900" \
  "$(node -e 'const fs=require("fs");const p=process.argv[1]+"/spool/events.jsonl";
     process.stdout.write(String(JSON.parse(fs.readFileSync(p,"utf8").trim().split("\n").pop()).props.lines_avoided));' "$d")"

d2="$TEST_ROOT/tele-allow"; mkdir -p "$d2"
printf '%s' "$(read_payload "$REPO/src/small.ts")" | env RAFTKIT_TELEMETRY_DIR="$d2" node "$SHUNT" >/dev/null 2>&1
expect_eq "an allow costs no telemetry" "no" \
  "$([[ -f "$d2/spool/events.jsonl" ]] && echo yes || echo no)"

d3="$TEST_ROOT/tele-off"; mkdir -p "$d3"
printf '%s' "$(read_payload "$REPO/src/big.ts")" |
  env RAFTKIT_TELEMETRY_DIR="$d3" RAFTKIT_TELEMETRY=off node "$SHUNT" >/dev/null 2>&1
expect_eq "telemetry opt-out writes nothing, and the shunt still works" "no" \
  "$([[ -f "$d3/spool/events.jsonl" ]] && echo yes || echo no)"
expect_eq "telemetry opt-out does not disable the shunt" "deny" \
  "$(verdict "$(read_payload "$REPO/src/big.ts")" RAFTKIT_TELEMETRY=off)"

# ------------------------------------------------- 8. token accounting
T="$TEST_ROOT/transcript.jsonl"
mk_msg() { # <model> <isSidechain> <in> <out> <cache_read> <cache_creation>
  node -e '
    const [model, side, i, o, cr, cc] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({
      type: "assistant", isSidechain: side === "true",
      message: { model, usage: {
        input_tokens: +i, output_tokens: +o,
        cache_read_input_tokens: +cr, cache_creation_input_tokens: +cc } },
    }) + "\n");
  ' "$@"
}
{
  echo '{"type":"user","message":{"role":"user","content":"hi"}}'
  mk_msg claude-opus-5 false 10 20 30 40
  mk_msg claude-haiku-4-5 true 1 2 3 4
  echo 'not json at all'
} > "$T"

tok() { # <jq-ish path> — echoes one field of runTokens()
  node --input-type=module -e '
    const { runTokens } = await import(process.argv[1]);
    const t = runTokens(process.argv[2], process.argv[3]);
    const path = process.argv[4].split(".");
    let v = t; for (const k of path) v = v?.[k];
    process.stdout.write(String(v));
  ' "$PWD/plugins/raftkit-core/hooks/lib/tokens.mjs" "$T" "$1" "$2"
}
export RAFTKIT_TELEMETRY_DIR="$TEST_ROOT/tokstate"
expect_eq "the total is main plus sidechain" "110" "$(tok sessA total)"
expect_eq "the sidechain is split out" "10" "$(tok sessB sidechain)"
expect_eq "the main thread is split out" "100" "$(tok sessC main)"
expect_eq "tokens are attributed per tier" "10" "$(tok sessD by_tier.haiku)"
expect_eq "a malformed line is skipped, not fatal" "2" "$(tok sessE messages)"

# A second read of an unchanged transcript must not double-count, and an
# appended message must be picked up. This is the incremental contract.
tok sessG total >/dev/null
expect_eq "re-reading an unchanged transcript does not double-count" "110" "$(tok sessG total)"
mk_msg claude-sonnet-5 false 5 5 5 5 >> "$T"
expect_eq "an appended message is folded in" "130" "$(tok sessG total)"

expect_eq "a missing transcript yields null" "null" \
  "$(node --input-type=module -e '
      const { runTokens } = await import(process.argv[1]);
      process.stdout.write(String(runTokens("/nonexistent/x.jsonl", "sX")));
    ' "$PWD/plugins/raftkit-core/hooks/lib/tokens.mjs")"
expect_eq "a transcript with no session id yields null" "null" \
  "$(node --input-type=module -e '
      const { runTokens } = await import(process.argv[1]);
      process.stdout.write(String(runTokens(process.argv[2], "")));
    ' "$PWD/plugins/raftkit-core/hooks/lib/tokens.mjs" "$T")"
expect_eq "no transcript path yields null" "null" \
  "$(node --input-type=module -e '
      const { runTokens } = await import(process.argv[1]);
      process.stdout.write(String(runTokens("", "sX")));
    ' "$PWD/plugins/raftkit-core/hooks/lib/tokens.mjs")"

# ------------------------------------------------------- 9. it is wired up
node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const pre = h.hooks.PreToolUse || [];
  const matchers = pre.map((e) => e.matcher).sort().join(",");
  if (matchers !== "Bash,Read") { console.error("matchers: " + matchers); process.exit(1); }
  // Async hooks have their stdout discarded, and this hooks stdout IS its
  // decision — declaring it async would silently disable every deny.
  for (const entry of pre) for (const hook of entry.hooks) {
    if (hook.async) { console.error("PreToolUse hook must not be async"); process.exit(1); }
    if (!hook.args.some((a) => a.endsWith("shunt.mjs"))) { console.error("wrong script"); process.exit(1); }
  }
' && echo "PASS: the shunt is registered on Read and Bash, synchronously" ||
  { echo "FAIL: hooks.json registration"; failures=$((failures + 1)); }

grep -q "RAFTKIT_SHUNT=off" plugins/raftkit-core/hooks/hooks.json &&
  echo "PASS: hooks.json documents the bypass" ||
  { echo "FAIL: hooks.json does not document the bypass"; failures=$((failures + 1)); }

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
