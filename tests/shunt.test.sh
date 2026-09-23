#!/usr/bin/env bash
# Proves the bulk-read shunt is safe and correct:
#   1. an oversized read is denied, with the bulk-reader instruction attached
#   2. everything else is allowed — under threshold, narrowed by offset/limit,
#      binary, missing, outside the repo, a directory, an unparsable payload
#   3. instruction files (CLAUDE.md, SKILL.md, plan records, the agreement)
#      are never shunted at any size — the load-bearing exemption, because a
#      paraphrased scope contract is worse than an expensive one
#   4. the kill switch and the threshold override are honoured
#   5. a Bash call never reaches the shunt: it is not registered on Bash
#   6. every failure path exits 0 and prints nothing (fail open)
#   7. a deny is recorded as telemetry; an allow costs no telemetry at all
#   8. token accounting counts each message once, folds subagent files,
#      skips a fork's copied history, and resumes incrementally; run-tokens.mjs
#      prints the one line the STOP quotes
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
mkdir -p "$REPO/clients/acme.bank" && seq 1 900 > "$REPO/clients/acme.bank/q3-layoffs"   # no extension, dotted directory

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

# ------------------------------------------------------- 1. the one deny
expect_eq "an oversized read is denied" "deny" "$(verdict "$(read_payload "$REPO/src/big.ts")")"
expect_eq "a relative path resolves against cwd and is denied" "deny" "$(verdict "$(read_payload "src/big.ts")")"

r="$(reason "$(read_payload "$REPO/src/big.ts")")"
grep -q "src/big.ts is 900 lines" <<< "$r" && echo "PASS: the reason names the file and its real line count" ||
  { echo "FAIL: reason line count (got: ${r:0:80})"; failures=$((failures + 1)); }
# A plugin agent is dispatched by its scoped name.
grep -q 'subagent_type: "raftkit-core:bulk-reader"' <<< "$r" && echo "PASS: the reason carries the bulk-reader call by its scoped name" ||
  { echo "FAIL: reason lacks the scoped bulk-reader call"; failures=$((failures + 1)); }
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

# ------------------------------- 3b. the bulk-reader and subagents are not policed
# The hook runs inside subagent tool calls too. A subagent's context is its
# own, so its reads are never shunted: Claude Code puts agent_id on every hook
# payload from inside a subagent, and only there.
agent_payload() { # <extra-json-fields>
  node -e '
    const [cwd, file, extra] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({ cwd, tool_name: "Read", tool_input: { file_path: file }, ...JSON.parse(extra) }));
  ' "$REPO" "$REPO/src/big.ts" "$1"
}
expect_eq "the bulk-reader, by its scoped plugin name, bypasses the shunt" "allow" \
  "$(verdict "$(agent_payload '{"agent_type":"raftkit-core:bulk-reader"}')")"
expect_eq "a Read made inside any subagent is never denied" "allow" \
  "$(verdict "$(agent_payload '{"agent_id":"a4d33b7f47848085d","agent_type":"Explore"}')")"
expect_eq "an empty agent_id is not a subagent" "deny" "$(verdict "$(agent_payload '{"agent_id":""}')")"
# `--agent` sets agent_type on the main thread with no agent_id: still policed.
expect_eq "a main-thread --agent session is still policed" "deny" \
  "$(verdict "$(agent_payload '{"agent_type":"code-reviewer"}')")"
# The hard defence, which needs no payload field at all: a paged read is
# exempt, so the agent can always get the text even if it is not recognised.
expect_eq "a paged read by an unrecognised agent is allowed" "allow" \
  "$(verdict "$(read_payload "$REPO/src/big.ts" ',"offset":1,"limit":1500')")"
# The deny text must name that route, or an unrecognised reader is stuck.
grep -q "offset and limit" <<< "$r" && echo "PASS: the reason names the paged-read route" ||
  { echo "FAIL: reason lacks the paged-read route"; failures=$((failures + 1)); }
# The agent reads files, not the project's instructions.
awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' plugins/raftkit-core/agents/bulk-reader.md | grep -qx 'omitClaudeMd: true' &&
  echo "PASS: the bulk-reader does not load CLAUDE.md" ||
  { echo "FAIL: bulk-reader frontmatter lacks omitClaudeMd: true"; failures=$((failures + 1)); }

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

# -------------------------------------------------------- 5. Bash is not shunted
# A Bash result over Claude Code's own output cap is truncated anyway, so the
# shunt could never deny one, yet it spawned node on every Bash call. Even a
# payload that reaches it is allowed.
expect_eq "a Bash call is allowed, even one that cats a big file" "allow" \
  "$(verdict "$(node -e '
      const [cwd, cmd] = process.argv.slice(1);
      process.stdout.write(JSON.stringify({ session_id: "s1", hook_event_name: "PreToolUse", cwd, tool_name: "Bash", tool_input: { command: cmd } }));
    ' "$REPO" "cat $REPO/src/big.ts")")"

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
last_ext() { node -e 'const fs=require("fs");const p=process.argv[1]+"/spool/events.jsonl";
  process.stdout.write(JSON.stringify(fs.existsSync(p)?JSON.parse(fs.readFileSync(p,"utf8").trim().split("\n").pop()).props.path_ext:null));' "$1"; }
expect_eq "the deny records the file's extension" '".ts"' "$(last_ext "$d")"
# Every session sends this record, so it carries the extension and never a path.
dx="$TEST_ROOT/tele-noext"; mkdir -p "$dx"
printf '%s' "$(read_payload "$REPO/clients/acme.bank/q3-layoffs")" |
  env RAFTKIT_TELEMETRY_DIR="$dx" PATH="$TEST_ROOT/stub:$PATH" node "$SHUNT" >/dev/null 2>&1
expect_eq "a file with no extension under a dotted directory records no path fragment" '""' "$(last_ext "$dx")"

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
# The fixture mirrors the shapes measured in real CLI 2.1.280 transcripts, with
# every piece of content removed: one message written as several lines that
# repeat its usage, subagents in their own files (placeholder usage first,
# workflow agents one level deeper, agentType in a sibling .meta.json), a usage
# whose top-level fields are zero with the real numbers in `iterations`, and a
# fork that copies its parent's records before its own SessionStart:fork.
CFG="$TEST_ROOT/cfg"
PROJ="$CFG/projects/-fixture"
SID="11111111-aaaa-4bbb-8ccc-000000000001"
FORK="22222222-aaaa-4bbb-8ccc-000000000002"
T="$PROJ/$SID.jsonl"
mkdir -p "$PROJ/$SID/subagents/workflows/wf_fixture"
node - "$PROJ" "$SID" "$FORK" <<'FIXTURE'
const fs = require("fs");
const [proj, sid, fork] = process.argv.slice(2);
const u = (i, o, cr, cc, extra = {}) => ({ input_tokens: i, output_tokens: o, cache_read_input_tokens: cr, cache_creation_input_tokens: cc, ...extra });
const msg = (sessionId, id, ts, usage, model = "claude-opus-5-5", content = [{ type: "text", text: "" }]) =>
  JSON.stringify({ type: "assistant", sessionId, timestamp: ts, isSidechain: false, message: { id, model, usage, content } });
const line = (o) => JSON.stringify(o);
const main = [
  line({ type: "user", sessionId: sid, timestamp: "2026-09-18T01:00:00.000Z", message: { role: "user", content: "hi" } }),
  line({ type: "attachment", sessionId: sid, timestamp: "2026-09-18T01:00:00.100Z", attachment: { type: "skill_listing", names: ["raftkit-dev:implement", "raftkit-dev:fix", "raftkit-core:rules", "other:x"], content: "- raftkit-dev:implement: Take one story\n- raftkit-dev:fix\n- raftkit-core:rules\n- other:x: y" } }),
  // m1: three lines, one message — counted once
  msg(sid, "m1", "2026-09-18T01:00:01.000Z", u(10, 20, 30, 40)),
  msg(sid, "m1", "2026-09-18T01:00:01.100Z", u(10, 20, 30, 40)),
  msg(sid, "m1", "2026-09-18T01:00:01.200Z", u(10, 20, 30, 40)),
  // m2: top-level zeros, real numbers in iterations
  msg(sid, "m2", "2026-09-18T01:00:02.000Z", u(0, 0, 0, 0, { iterations: [{ type: "message", ...u(5, 5, 5, 5) }] }), "claude-opus-5"),
  msg(sid, "syn", "2026-09-18T01:00:02.500Z", u(0, 0, 0, 0), "<synthetic>"),
  "not json at all",
  // m3 starts the RaftKit run: the model invokes implement
  msg(sid, "m3", "2026-09-18T01:00:03.000Z", u(1, 1, 1, 1), "claude-opus-5-5", [{ type: "tool_use", name: "Skill", input: { skill: "raftkit-dev:implement" } }]),
  msg(sid, "m4", "2026-09-18T01:00:04.000Z", u(100, 0, 0, 0)),
  // a nested skill inside the run does not restart it
  msg(sid, "m5", "2026-09-18T01:00:05.000Z", u(0, 0, 0, 0), "claude-opus-5-5", [{ type: "tool_use", name: "Skill", input: { skill: "raftkit-dev:scope-guard" } }]),
];
fs.writeFileSync(`${proj}/${sid}.jsonl`, main.join("\n") + "\n");
const sub = `${proj}/${sid}/subagents`;
fs.writeFileSync(`${sub}/agent-a1.meta.json`, JSON.stringify({ agentType: "Explore" }));
fs.writeFileSync(`${sub}/agent-a1.jsonl`, [
  msg("x", "s1", "2026-09-18T01:00:03.500Z", u(1, 1, 0, 0), "claude-haiku-4-5"),      // placeholder
  msg("x", "s1", "2026-09-18T01:00:03.600Z", u(2, 3, 4, 5), "claude-haiku-4-5"),      // final: 14
].join("\n") + "\n");
fs.writeFileSync(`${sub}/workflows/wf_fixture/agent-b2.meta.json`, JSON.stringify({ agentType: "general-purpose" }));
fs.writeFileSync(`${sub}/workflows/wf_fixture/agent-b2.jsonl`, msg("x", "s2", "2026-09-18T01:00:03.700Z", u(6, 6, 6, 6), "claude-sonnet-5") + "\n"); // 24
// The fork: the parent's m1 copied under the fork's own sessionId and the
// parent's timestamps, then its own start, then its own message.
fs.writeFileSync(`${proj}/${fork}.jsonl`, [
  msg(fork, "m1", "2026-09-18T01:00:01.000Z", u(10, 20, 30, 40)),
  msg(fork, "m4", "2026-09-18T01:00:04.000Z", u(100, 0, 0, 0)),
  line({ type: "attachment", sessionId: fork, timestamp: "2026-09-18T02:00:00.000Z", attachment: { type: "hook_success", hookEvent: "SessionStart", hookName: "SessionStart:fork" } }),
  msg(fork, "f1", "2026-09-18T02:00:01.000Z", u(7, 7, 7, 7)),
].join("\n") + "\n");
FIXTURE

TOKENS_LIB="$PWD/plugins/raftkit-core/hooks/lib/tokens.mjs"
tok() { # <session> <transcript> <dotted field> — one field of runTokens()
  node --input-type=module -e '
    const { runTokens } = await import(process.argv[1]);
    const t = runTokens(process.argv[3], process.argv[2]);
    let v = t; for (const k of process.argv[4].split(".")) v = v?.[k];
    process.stdout.write(String(v));
  ' "$TOKENS_LIB" "$1" "$2" "$3"
}
export RAFTKIT_TELEMETRY_DIR="$TEST_ROOT/tokstate"
# main 100 (m1 once) + 20 (m2 via iterations) + 4 (m3) + 100 (m4) = 224; subagents 14 + 24 = 38
expect_eq "a message spread over several lines is counted once" "224" "$(tok "$SID" "$T" main)"
expect_eq "subagent files, workflow agents included, are the sidechain" "38" "$(tok "$SID" "$T" sidechain)"
expect_eq "the total is main plus subagents" "262" "$(tok "$SID" "$T" total)"
expect_eq "a subagent's placeholder usage is replaced by its final line" "14" "$(tok "$SID" "$T" by_agent.Explore)"
expect_eq "subagent tokens are attributed by agentType" "24" "$(tok "$SID" "$T" by_agent.general-purpose)"
expect_eq "subagent tokens appear in the by-model totals" "24" "$(tok "$SID" "$T" by_model.claude-sonnet-5)"
expect_eq "tokens are still attributed per tier" "14" "$(tok "$SID" "$T" by_tier.haiku)"
expect_eq "a usage whose top level is zero is counted from its iterations" "20" "$(tok "$SID" "$T" by_model.claude-opus-5)"
expect_eq "a zero-usage message adds no model row" "undefined" "$(tok "$SID" "$T" 'by_model.<synthetic>')"
expect_eq "a forked session does not re-count its parent's history" "28" "$(tok "$FORK" "$PROJ/$FORK.jsonl" total)"

# Incremental: an unchanged transcript is not re-counted, a later line for the
# same message replaces its usage, and a new message is added.
expect_eq "re-reading an unchanged transcript does not double-count" "262" "$(tok "$SID" "$T" total)"
node -e '
  const u = { input_tokens: 150, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 };
  process.stdout.write(JSON.stringify({ type: "assistant", timestamp: "2026-09-18T01:00:05.500Z", message: { id: "m5", model: "claude-opus-5-5", usage: u, content: [] } }) + "\n");
' >> "$T"
expect_eq "a later line for the same message replaces its usage, across reads" "412" "$(tok "$SID" "$T" total)"
node -e '
  const u = { input_tokens: 8, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 };
  process.stdout.write(JSON.stringify({ type: "assistant", timestamp: "2026-09-18T01:00:06.000Z", message: { id: "m6", model: "claude-opus-5-5", usage: u, content: [] } }) + "\n");
' >> "$T"
expect_eq "an appended message is folded in" "420" "$(tok "$SID" "$T" total)"

# Listing coverage rides along the first time a skill_listing is seen.
L="$TEST_ROOT/listing.jsonl"; head -2 "$T" > "$L"
expect_eq "listing coverage counts RaftKit entries" "3" "$(tok sessL "$L" listing.raftkit)"
expect_eq "  and those that kept a description" "raftkit-dev:implement" "$(tok sessL2 "$L" listing.described)"
expect_eq "  and is reported once, not on every turn" "undefined" "$(tok sessL "$L" listing)"

expect_eq "a missing transcript yields null" "null" \
  "$(node --input-type=module -e '
      const { runTokens } = await import(process.argv[1]);
      process.stdout.write(String(runTokens("/nonexistent/x.jsonl", "sX")));
    ' "$TOKENS_LIB")"
expect_eq "a transcript with no session id yields null" "null" \
  "$(node --input-type=module -e '
      const { runTokens } = await import(process.argv[1]);
      process.stdout.write(String(runTokens(process.argv[2], "")));
    ' "$TOKENS_LIB" "$T")"

# ------------------------------------------------- 8b. run-tokens.mjs (C1)
# The STOP quotes this line, so it is a contract: exactly one line, measured or
# "not measured", never an estimate, never a write.
RUN_TOKENS="$PWD/plugins/raftkit-dev/scripts/run-tokens.mjs"
RT_STATE="$TEST_ROOT/rt-state"   # where a hook would keep state; run-tokens must never create it
rt() { env CLAUDE_CONFIG_DIR="$CFG" RAFTKIT_TELEMETRY_DIR="$RT_STATE" CLAUDE_PLUGIN_DATA="$RT_STATE" node "$RUN_TOKENS" "$@" 2>/dev/null; }
out="$(rt "$SID")"
expect_eq "run-tokens prints exactly one line" "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
# The run starts at the implement invocation (m3): 4 + 100 + 150 + 8 = 262 main,
# plus both subagents, which started after it: 38.
expect_eq "run-tokens measures the run from its skill invocation" \
  "Token total: 300 tokens (main 262, subagents 38; claude-opus-5-5: 262, claude-sonnet-5: 24, claude-haiku-4-5: 14) — measured" "$out"
expect_eq "run-tokens --session measures the whole session" \
  "Token total: 420 tokens (main 382, subagents 38; claude-opus-5-5: 362, claude-sonnet-5: 24, claude-opus-5: 20, claude-haiku-4-5: 14) — measured" "$(rt "$SID" --session)"
expect_eq "an unknown session is not measured" "Token total: not measured" "$(rt "33333333-aaaa-4bbb-8ccc-000000000003")"
# A traversal that would resolve to a real transcript if the id went unchecked.
expect_eq "a malformed session id is not measured" "Token total: not measured" "$(rt "../-fixture/$SID")"
expect_eq "no session id is not measured" "Token total: not measured" "$(rt)"
tree_sum() { find "$TEST_ROOT" -type f -print0 | sort -z | xargs -0 cksum | cksum; }
before="$(tree_sum)"
rt "$SID" >/dev/null
expect_eq "run-tokens writes nothing" "$before|no" "$(tree_sum)|$([[ -e "$RT_STATE" ]] && echo yes || echo no)"

# Installed from the plugin cache, run-tokens finds raftkit-core beside it.
CACHE="$CFG/plugins/cache/raftkit"
mkdir -p "$CACHE/raftkit-core/9.9.9" "$CACHE/raftkit-dev/9.9.9"
cp -R plugins/raftkit-core/. "$CACHE/raftkit-core/9.9.9/"
cp -R plugins/raftkit-dev/. "$CACHE/raftkit-dev/9.9.9/"
printf '{"version":2,"plugins":{"raftkit-core@raftkit":[{"scope":"user","installPath":"%s","version":"9.9.9"}]}}' \
  "$CACHE/raftkit-core/9.9.9" > "$CFG/plugins/installed_plugins.json"
expect_eq "run-tokens installed from the cache finds raftkit-core" "measured" \
  "$(env CLAUDE_CONFIG_DIR="$CFG" node "$CACHE/raftkit-dev/9.9.9/scripts/run-tokens.mjs" "$SID" 2>/dev/null | grep -o 'measured$')"
rm -rf "$CACHE/raftkit-core"
expect_eq "run-tokens without raftkit-core says not measured" "Token total: not measured" \
  "$(env CLAUDE_CONFIG_DIR="$CFG" node "$CACHE/raftkit-dev/9.9.9/scripts/run-tokens.mjs" "$SID" 2>/dev/null)"
rm -rf "$CFG/plugins"

# ------------------------------------------------------- 9. it is wired up
node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const pre = h.hooks.PreToolUse || [];
  const matchers = pre.map((e) => e.matcher).sort().join(",");
  // Read only: a Bash call must not spawn node for a check that can never deny.
  if (matchers !== "Read") { console.error("matchers: " + matchers); process.exit(1); }
  // Async hooks have their stdout discarded, and this hooks stdout IS its
  // decision — declaring it async would silently disable every deny.
  for (const entry of pre) for (const hook of entry.hooks) {
    if (hook.async) { console.error("PreToolUse hook must not be async"); process.exit(1); }
    if (!hook.args.some((a) => a.endsWith("shunt.mjs"))) { console.error("wrong script"); process.exit(1); }
  }
' && echo "PASS: the shunt is registered on Read only, synchronously" ||
  { echo "FAIL: hooks.json registration"; failures=$((failures + 1)); }

grep -q "RAFTKIT_SHUNT=off" plugins/raftkit-core/hooks/hooks.json &&
  echo "PASS: hooks.json documents the bypass" ||
  { echo "FAIL: hooks.json does not document the bypass"; failures=$((failures + 1)); }

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
