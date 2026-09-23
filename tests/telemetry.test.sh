#!/usr/bin/env bash
# Proves the telemetry hooks are safe and correct:
#   1. record.mjs spools a well-formed event
#   2. credentials are scrubbed out of captured prompts
#   3. opt-out (RAFTKIT_TELEMETRY=off / DO_NOT_TRACK) writes nothing at all
#   4. every malformed input still exits 0 and never corrupts the spool
#      (the load-bearing one — a hook must never break a developer's session)
#   5. refusal patterns are valid regexes that match their documented examples
#   6. blocker detection classifies stops and leaves normal turns alone
#   7. flush clears the spool on 2xx and RETAINS it on failure
#      (plus: every flushed event carries the event_id the server dedups on)
#   8. the governance docs match what the code actually does
#   9. the governance docs match the shipped behaviour, the one-time disclosure
#      actually renders, and the manifests stay in version/description lockstep
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
cd "$(dirname "$0")/.."

HOOKS="plugins/raftkit-core/hooks"
RECORD="$HOOKS/record.mjs"
FLUSH="$HOOKS/flush.mjs"
# Absolute, for the few tests that have to run from another directory.
RECORD_ABS="$PWD/$RECORD"

failures=0

# Every sandbox lives under one root, and cleanup removes the root.
#
# The previous version tracked directories in an array, but new_sandbox is
# called as `d="$(new_sandbox)"` — the append ran in a command-substitution
# subshell and never reached the parent. Cleanup therefore saw nothing: stub
# servers were never killed and every temp dir leaked. A single root needs no
# bookkeeping and cannot drift out of sync.
TEST_ROOT="$(mktemp -d)"
cleanup() {
  # Stub servers first, while their PID files are still readable.
  local pidfile
  for pidfile in "$TEST_ROOT"/*/pids; do
    [[ -f "$pidfile" ]] || continue
    while read -r pid; do
      [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    done < "$pidfile"
  done
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

new_sandbox() { # echoes a fresh telemetry dir under TEST_ROOT
  mktemp -d "$TEST_ROOT/sbx.XXXXXX"
}

# Make the suite hermetic.
#
# identity() shells out to `gh api user` on every cold cache, and each test runs
# in a fresh sandbox, so an unauthenticated or slow `gh` — which is exactly what
# CI has — turns 22 identity resolutions into 22 network timeouts and blows the
# job's time budget. Tests must not touch the network.
#
# Individual tests that care about `gh` behaviour prepend their own stub, which
# takes precedence over this one.
STUB_BIN="$(new_sandbox)"
cat > "$STUB_BIN/gh" <<'STUB'
#!/usr/bin/env bash
# Hermetic default: succeed instantly, return nothing useful.
case "$1" in
  api) exit 1 ;;         # no identity lookup
  auth) exit 0 ;;        # "authenticated", so filing paths are reachable
  *) exit 0 ;;
esac
STUB
chmod +x "$STUB_BIN/gh"
export PATH="$STUB_BIN:$PATH"

# The endpoint / issue-repo / file-issues env overrides only apply under
# RAFTKIT_DEV=1. That gate exists so a checked-in .claude/settings.json `env`
# block in some client repo cannot redirect a developer's telemetry — see
# config() in lib/common.mjs. The suite is exactly the legitimate caller, so it
# opts in here, once, for every test below.
export RAFTKIT_DEV=1

# Never let the suite reach the real telemetry endpoint.
#
# The shipped config now points at production, so any test that runs flush.mjs
# without an explicit override would POST real events into the live database.
# Default to "send nowhere"; the flush tests set their own stub-server URL.
export RAFTKIT_TELEMETRY_ENDPOINT=""

# Nor read this machine's Claude Code config: the ledger and the plugin cache
# lookups resolve under an empty sandbox unless a test points them elsewhere.
export CLAUDE_CONFIG_DIR="$(new_sandbox)"
unset CLAUDE_PROJECT_DIR

check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}

expect_eq() { # <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected '$2', got '$3')"
    failures=$((failures + 1))
  fi
}

last_event_field() { # <spool> <dotted property path, e.g. props.refusal_id>
  node -e '
    const fs = require("fs");
    const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
    let v = JSON.parse(lines[lines.length - 1]);
    for (const key of process.argv[2].split(".")) {
      v = v == null ? undefined : v[key];
    }
    process.stdout.write(String(v));
  ' "$1" "$2" 2>/dev/null
}

seed_skill() { # <telemetry dir> <session id> — a RaftKit run in that session, so its stops count
  printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:implement"}}' "$2" \
    | RAFTKIT_TELEMETRY_DIR="$1" node "$RECORD" skill >/dev/null 2>&1
}

# ---------------------------------------------------------------- 1. spooling
d="$(new_sandbox)"
echo "{\"session_id\":\"s1\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\",\"cwd\":\"$PWD\"}" \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
check "session_start exits 0" ok $?
expect_eq "session_start spools one event" "1" "$(wc -l < "$d/spool/events.jsonl" | tr -d ' ')"
expect_eq "event name is correct" "raftkit_session_started" "$(last_event_field "$d/spool/events.jsonl" 'event')"

# The server dedups on event_id. Without it, every flush retry double-counts.
event_id="$(last_event_field "$d/spool/events.jsonl" 'event_id')"
if [[ "$event_id" =~ ^[A-Za-z0-9-]{8,64}$ ]]; then
  echo "PASS: event carries an idempotency key"
else
  echo "FAIL: missing or malformed event_id ('$event_id')"
  failures=$((failures + 1))
fi
# ...and it must differ per event, or dedup would collapse distinct events.
echo '{"session_id":"s1","cwd":"'$PWD'"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
second_id="$(last_event_field "$d/spool/events.jsonl" 'event_id')"
if [[ "$second_id" != "$event_id" ]]; then
  echo "PASS: event_id is unique per event"
else
  echo "FAIL: event_id repeated across events ('$event_id')"
  failures=$((failures + 1))
fi
repo_val="$(last_event_field "$d/spool/events.jsonl" 'props.repo')"
if [[ "$repo_val" == sha256:* ]]; then
  echo "PASS: the grouping key stays a hash"
else
  echo "FAIL: props.repo is not a hash ('$repo_val')"
  failures=$((failures + 1))
fi

# The readable name is sent deliberately — the dashboard cannot attribute a
# blocker to a project without it. What must NOT survive is a credential
# embedded in an HTTPS remote, which normalizing to owner/repo drops by
# construction rather than by pattern-matching.
name_val="$(last_event_field "$d/spool/events.jsonl" 'props.repo_name')"
if [[ "$name_val" == */* && "$name_val" != *http* && "$name_val" != *@* ]]; then
  echo "PASS: repo_name is a clean owner/repo slug"
else
  echo "FAIL: repo_name malformed or carries a host/credential ('$name_val')"
  failures=$((failures + 1))
fi

node -e '
  import("./plugins/raftkit-core/hooks/lib/common.mjs").then(({ repoSlug }) => {
    const cases = [
      ["git@github.com:Raft-Labs/raftkit.git", "Raft-Labs/raftkit"],
      ["https://github.com/Raft-Labs/raftkit.git", "Raft-Labs/raftkit"],
      // The one that matters: a token in the remote must not survive.
      ["https://user:ghp_AAAABBBBCCCCDDDD@github.com/Raft-Labs/raftkit.git", "Raft-Labs/raftkit"],
      ["ssh://git@gitlab.com/group/proj", "group/proj"],
      ["", ""],
      ["not-a-remote", ""],
    ];
    let bad = 0;
    for (const [input, want] of cases) {
      const got = repoSlug(input);
      if (got !== want) { console.error(`  ${input} -> ${got} (want ${want})`); bad++; }
      if (/ghp_|:\/\/|@/.test(got)) { console.error("  credential or host survived: " + got); bad++; }
    }
    process.exit(bad === 0 ? 0 : 1);
  }).catch(() => process.exit(1));
' >/dev/null 2>&1
check "repoSlug normalizes remotes and strips embedded credentials" ok $?

# ------------------------------------------------------------- 2. scrubbing
# Prompt text is kept only in a session that ran a RaftKit skill, so each
# prompt-scrubbing case runs in one — otherwise it passes on an empty prompt.
d="$(new_sandbox)"; seed_skill "$d" s1
secret_prompt='deploy using ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHH1234 and sk-proj-ZZZZYYYYXXXXWWWWVVVV1111 now'
echo "{\"session_id\":\"s1\",\"user_prompt\":\"$secret_prompt\",\"cwd\":\"$PWD\"}" \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
captured="$(last_event_field "$d/spool/events.jsonl" 'props.prompt')"
if [[ "$captured" == *"ghp_AAAA"* || "$captured" == *"sk-proj-ZZZZ"* ]]; then
  echo "FAIL: credentials survived scrubbing ('$captured')"
  failures=$((failures + 1))
else
  echo "PASS: credentials scrubbed from captured prompt"
fi
if [[ "$captured" == *"REDACTED"* && "$captured" == *"deploy using"* ]]; then
  echo "PASS: surrounding prompt text preserved"
else
  echo "FAIL: scrubbing destroyed non-secret text ('$captured')"
  failures=$((failures + 1))
fi

# Direct unit coverage of the scrubber's classes.
#
# Every case asserts THE SECRET ITSELF IS GONE, never merely that the word
# "REDACTED" appears somewhere. The old form asserted the latter and passed a
# rule that emitted "Authorization: [REDACTED] ghs_<real token>" — redaction had
# visibly happened, and the credential was still in the output. An assertion
# that cannot fail on a leak is worse than no assertion, because it reads as
# coverage. Third column = the substring that must NOT survive.
node -e '
  import("./plugins/raftkit-core/hooks/lib/scrub.mjs").then(({ scrub }) => {
    const cases = [
      ["github token",   "ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHH1234", "ghp_AAAABBBB"],
      ["aws key id",     "AKIAIOSFODNN7EXAMPLE", "AKIAIOSFODNN7EXAMPLE"],
      ["slack token",    "xoxb-1234567890-abcdefghij", "1234567890-abcdefghij"],
      ["pem block",      "-----BEGIN RSA PRIVATE KEY-----\nKEYBODYSECRET\n-----END RSA PRIVATE KEY-----", "KEYBODYSECRET"],
      ["password assignment", "password: hunter2supersecret", "hunter2supersecret"],
      ["url credentials", "https://user:pa55word@example.com/x", "pa55word"],

      // F2: the value was matched with \S+, which consumed only the word
      // "Bearer" and published the token that followed it.
      ["auth header bearer", "Authorization: Bearer ghs_REALTOKENAAAABBBBCCCCDDDD1234", "ghs_REALTOKEN"],
      ["auth header basic",  "Authorization: Basic dXNlcjpwYXNzd29yZDEyMzQ1Ng==", "dXNlcjpwYXNz"],
      ["proxy auth header",  "Proxy-Authorization: Basic c2VjcmV0OnZhbHVlMTIzNDU2", "c2VjcmV0OnZh"],
      // ...and consuming "Bearer" meant the rule beneath it could never fire.
      ["bare bearer",        "Bearer abcdefghijklmnopqrstuvwxyz0123", "abcdefghijklmnopqrstuvwxyz0123"],

      // F11: formats confirmed to pass straight through the old rule set.
      // Fixture note: these carry the real prefixes the rules key on, but their
      // random parts are deliberately shorter than the live formats (Stripe 24+,
      // SendGrid 22/43) and spell out FAKE. That keeps them matching OUR rules
      // while staying under the GitHub push-protection detectors. A realistic
      // fixture in a public repo is a secret-scanning alert, not better coverage.
      // (No apostrophes in this block: it lives inside a single-quoted node -e.)
      ["stripe live key",    "STRIPE=sk_live_FAKEKEYNOTREAL1", "sk_live_FAKEKEY"],
      ["stripe restricted",  "rk_live_FAKEKEYNOTREAL2", "rk_live_FAKEKEY"],
      ["smtp pass",          "SMTP_PASS=hunter2supersecret", "hunter2supersecret"],
      ["pwd assignment",     "Pwd=SuperSecret123", "SuperSecret123"],
      ["aws secret key",     "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", "wJalrXUtnFEMI"],
      ["sendgrid key",       "SG.FAKESENDGRIDIDXX01.FAKESENDGRIDSECRET01", "FAKESENDGRIDSECRET01"],
      ["twilio auth token",  "twilio token 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d here", "1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d"],
      ["pgp private block",  "-----BEGIN PGP PRIVATE KEY BLOCK-----\nlQOYBF8SECRETKEYMATERIAL\n-----END PGP PRIVATE KEY BLOCK-----", "SECRETKEYMATERIAL"],
      ["unsigned two-part jwt", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0", "eyJzdWIiOiIxMjM0"],
      ["azure account key",  "AccountKey=abc123def456ghi789jkl012mno345pqr678stu901vwx234yz==", "abc123def456ghi"],
      ["truncated pem",      "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEASECRETMATERIAL123\n...", "SECRETMATERIAL123"],
      ["cred assignment",    "DB_CRED=topsecretvalue1", "topsecretvalue1"],
    ];
    let bad = 0;
    for (const [label, input, secret] of cases) {
      const out = scrub(input);
      if (out.includes(secret)) { console.error("  SECRET SURVIVED (" + label + "): " + out); bad++; }
      else if (!out.includes("REDACTED")) { console.error("  no redaction marker: " + label); bad++; }
    }
    // Over-redaction is a real cost too: it is the analytics this exists for.
    for (const clean of [
      "please run the tests and fix the failing case",
      "implement story 123 and open a PR against development",
      "update the Authorization docs page",
      "check if the user is passing the right flag",
    ]) {
      if (scrub(clean) !== clean) { console.error("  clean text was altered: " + clean); bad++; }
    }
    process.exit(bad === 0 ? 0 : 1);
  }).catch((e) => { console.error(e); process.exit(1); });
' >/dev/null 2>&1
check "scrubber removes the secret itself in every credential class, leaves clean text alone" ok $?

# --------------------------------------------------------------- 3. opt-out
for var in "RAFTKIT_TELEMETRY=off" "DO_NOT_TRACK=1"; do
  d="$(new_sandbox)"
  echo '{"session_id":"x"}' | env "$var" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
  rc=$?
  if [[ $rc -eq 0 && ! -f "$d/spool/events.jsonl" ]]; then
    echo "PASS: $var writes nothing"
  else
    echo "FAIL: $var (exit $rc, spool present: $([ -f "$d/spool/events.jsonl" ] && echo yes || echo no))"
    failures=$((failures + 1))
  fi
done

# ------------------------------------------- 4. resilience: never break a session
d="$(new_sandbox)"
echo 'not json at all {{{' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
check "malformed stdin exits 0" ok $?
printf '' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
check "empty stdin exits 0" ok $?
RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop < /dev/null >/dev/null 2>&1
check "closed stdin exits 0" ok $?
echo '{}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" bogus_mode >/dev/null 2>&1
check "unknown mode exits 0" ok $?
# An unwritable data dir, portably: a regular FILE where a directory is
# expected fails with ENOTDIR instantly everywhere.
#
# The previous version used /proc/nonexistent/nope, which fails fast on macOS
# (no /proc) but makes mkdirSync hang forever on Linux — it never throws. That
# hung CI until the job timed out while passing locally.
blocked="$(new_sandbox)"
: > "$blocked/not-a-dir"
echo '{"session_id":"x"}' | RAFTKIT_TELEMETRY_DIR="$blocked/not-a-dir/spool" node "$RECORD" stop >/dev/null 2>&1
check "unwritable spool dir exits 0" ok $?
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  if (!fs.existsSync(p)) process.exit(0);
  for (const l of fs.readFileSync(p, "utf8").trim().split("\n")) {
    if (!l.trim()) continue;
    try { JSON.parse(l); } catch { process.exit(1); }
  }
' "$d/spool/events.jsonl"
check "spool contains no corrupt lines after malformed input" ok $?

# ------------------------------------------------------- 5. refusal registry
node -e '
  const fs = require("fs");
  const reg = JSON.parse(fs.readFileSync("plugins/raftkit-core/hooks/lib/refusals.json", "utf8"));
  let bad = 0;
  const ids = new Set();
  for (const r of reg.refusals) {
    if (ids.has(r.id)) { console.error("  duplicate id: " + r.id); bad++; }
    ids.add(r.id);
    let re;
    try { re = new RegExp(r.pattern, "m"); }
    catch { console.error("  invalid regex: " + r.id); bad++; continue; }
    if (!r.example) { console.error("  missing example: " + r.id); bad++; continue; }
    const firstLine = r.example.split("\n")[0].trim();
    if (!re.test(firstLine)) { console.error("  pattern does not match its example: " + r.id); bad++; }
  }
  const last = reg.refusals[reg.refusals.length - 1];
  if (last.id !== "generic-cant") { console.error("  generic-cant must stay last"); bad++; }
  process.exit(bad === 0 ? 0 : 1);
' >/dev/null 2>&1
check "every refusal pattern is a valid regex matching its example" ok $?

# ---------------------------------------------------- 6. blocker classification
d="$(new_sandbox)"; seed_skill "$d" s1
printf '{"session_id":"s1","last_assistant_message":"NOT READY — 2 gap(s):\\n- Section 3 missing"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "hard stop is classified as blocked" "raftkit_blocked" "$(last_event_field "$d/spool/events.jsonl" 'event')"
expect_eq "correct refusal id" "not-ready" "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"

# The one human stop per run is not a blocker: it is the moment the human
# decides. It gets its own event, and the reply that follows is flagged so the
# dashboard can tell a go from an edit from an abandoned run.
d="$(new_sandbox)"; seed_skill "$d" s1
printf '{"session_id":"s1","last_assistant_message":"Story draft ready.\\n**STOP** — approve to write, edit to change, or decline."}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "the one stop is recorded as a gate, not a blocker" "raftkit_gate_shown" "$(last_event_field "$d/spool/events.jsonl" 'event')"
expect_eq "the gate rule is the one that matched" "stop-shown" "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"
printf '{"session_id":"s1","user_prompt":"go"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
expect_eq "the reply after a gate is flagged" "true" "$(last_event_field "$d/spool/events.jsonl" 'props.after_gate')"

# A prompt with no gate before it is not flagged.
d="$(new_sandbox)"
printf '{"session_id":"s1","user_prompt":"implement this story"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
expect_eq "an ordinary prompt is not flagged as answering a gate" "false" "$(last_event_field "$d/spool/events.jsonl" 'props.after_gate')"

# Renamed skills keep their v1 name alongside, so a dashboard series survives v2.
d="$(new_sandbox)"
printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-pm:story"}}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
expect_eq "a renamed skill records its v2 name" "story" "$(last_event_field "$d/spool/events.jsonl" 'props.skill_name')"
expect_eq "a renamed skill carries the v1 name it replaced" "user-story" "$(last_event_field "$d/spool/events.jsonl" 'props.legacy_name')"

# The capability-unavailable pattern keeps its leading `^` anchor — record.mjs
# scans trimmed lines, and the owned refusal format always starts one, so an
# unanchored pattern would misclassify any line that merely mentions the
# phrase mid-sentence. The anchor also has to tolerate Claude rendering the
# label bold (`**Missing:**` instead of plain `Missing:`) — both a plain and
# a bold refusal must still classify, and a line that only contains the
# phrase without starting with it must not.
d="$(new_sandbox)"; seed_skill "$d" s1
printf '{"session_id":"s1","last_assistant_message":"Missing: superpowers. Install it with: claude plugin install superpowers@claude-plugins-official"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "plain capability refusal classifies" "capability-unavailable" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"
expect_eq "plain capability refusal captures the detail" "superpowers" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.detail')"

d="$(new_sandbox)"; seed_skill "$d" s1
printf '{"session_id":"s1","last_assistant_message":"**Missing:** superpowers. Install it with: claude plugin install superpowers@claude-plugins-official"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "bold-prefixed capability refusal still classifies" "capability-unavailable" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"
expect_eq "bold-prefixed capability refusal captures the detail" "superpowers" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.detail')"

d="$(new_sandbox)"; seed_skill "$d" s1
printf '{"session_id":"s1","last_assistant_message":"The dev said Missing: superpowers. Install it with: something, but that was a quote."}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "a mid-sentence mention is not misclassified as a blocker" "raftkit_turn_completed" \
  "$(last_event_field "$d/spool/events.jsonl" 'event')"

d="$(new_sandbox)"; seed_skill "$d" s1
printf '{"session_id":"s1","last_assistant_message":"Done — all tests pass and the PR is up."}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "a normal turn is not a blocker" "raftkit_turn_completed" "$(last_event_field "$d/spool/events.jsonl" 'event')"

# The Stop hook carries no prompt, so it must recover the session's last one.
d="$(new_sandbox)"; seed_skill "$d" s9
echo "{\"session_id\":\"s9\",\"user_prompt\":\"implement story 123\",\"cwd\":\"$PWD\"}" \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
printf '{"session_id":"s9","last_assistant_message":"Can'"'"'t read the story — check your Asana connector, then retry."}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "blocker correlates the session's prompt" "implement story 123" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.prompt')"

# ---------------------------------------------------- 6. skill invocation
# Until this existed, `skill` was populated only by matchRefusal(), so a skill
# was recorded solely when it HARD-STOPPED — normal use was invisible while the
# disclosure claimed we collect "which skills you run". Both entry points are
# covered because there are two, verified against a live session.
d="$(new_sandbox)"
printf '{"session_id":"s1","hook_event_name":"UserPromptExpansion","command_name":"raftkit-dev:implement","command_args":"story 42"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
expect_eq "a typed slash command is recorded" "raftkit_skill_invoked" "$(last_event_field "$d/spool/events.jsonl" 'event')"
expect_eq "  with the skill name" "raftkit-dev:implement" "$(last_event_field "$d/spool/events.jsonl" 'props.skill')"
expect_eq "  and marked as typed" "typed" "$(last_event_field "$d/spool/events.jsonl" 'props.invocation')"

d="$(new_sandbox)"
printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-core:rules"}}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
expect_eq "a model-invoked skill is recorded" "raftkit-core:rules" "$(last_event_field "$d/spool/events.jsonl" 'props.skill')"
expect_eq "  and marked as model-invoked" "model" "$(last_event_field "$d/spool/events.jsonl" 'props.invocation')"

# A payload with neither field must not spool a nameless skill row.
d="$(new_sandbox)"
printf '{"session_id":"s1"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
expect_eq "a nameless skill payload is not recorded as a skill" "raftkit_unknown_event" "$(last_event_field "$d/spool/events.jsonl" 'event')"

# D6: the assertion above only checks the EVENT NAME is not "skill"-shaped —
# it still allows a raftkit_unknown_event row to be spooled. A PostToolUse or
# UserPromptExpansion event that never resolves to a skill name is not
# telemetry at all; it must leave the spool exactly as it was, not grow it by
# one line. Seed the spool with a real, unrelated event first so "unchanged"
# means something (a fresh/absent file passing trivially would prove nothing).
d="$(new_sandbox)"
echo "{\"session_id\":\"seed\",\"cwd\":\"$PWD\"}" | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
before_spool="$(cat "$d/spool/events.jsonl")"
printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{}}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
after_spool="$(cat "$d/spool/events.jsonl" 2>/dev/null)"
expect_eq "a nameless skill payload leaves the spool byte-identical (no raftkit_unknown_event line added)" \
  "$before_spool" "$after_spool"

# D8: a skill outside the raftkit-* namespace (the model exploring another
# installed plugin, or a developer typing a third-party slash command) is not
# RaftKit usage and must not be recorded — the dashboard exists to measure
# RaftKit adoption, not every plugin a developer happens to have installed.
d="$(new_sandbox)"
printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"superpowers:brainstorming"}}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
if [[ ! -f "$d/spool/events.jsonl" ]]; then
  echo "PASS: a non-raftkit-* skill invocation (superpowers:brainstorming) is not recorded"
else
  echo "FAIL: a non-raftkit-* skill invocation was spooled ($(last_event_field "$d/spool/events.jsonl" 'props.skill'))"
  failures=$((failures + 1))
fi

d="$(new_sandbox)"
printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"vercel:deploy"}}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
if [[ ! -f "$d/spool/events.jsonl" ]]; then
  echo "PASS: a non-raftkit-* skill invocation (vercel:deploy) is not recorded"
else
  echo "FAIL: a non-raftkit-* skill invocation was spooled ($(last_event_field "$d/spool/events.jsonl" 'props.skill'))"
  failures=$((failures + 1))
fi

# ...while a raftkit-* skill must still be recorded normally — this is a
# guard against a fix that overcorrects into recording nothing.
d="$(new_sandbox)"
printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:implement"}}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" skill >/dev/null 2>&1
expect_eq "a raftkit-* skill invocation is still recorded" "raftkit_skill_invoked" \
  "$(last_event_field "$d/spool/events.jsonl" 'event')"
expect_eq "  with the skill name preserved" "raftkit-dev:implement" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.skill')"

# The hooks must actually be wired, or none of the above ever fires in practice.
node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const modeFor = (ev, matcher) => ((h.hooks[ev] || [])
    .filter((m) => matcher === undefined || m.matcher === matcher)
    .flatMap((m) => m.hooks || []))
    .some((e) => (e.args || []).includes("skill"));
  process.exit(modeFor("UserPromptExpansion") && modeFor("PostToolUse", "Skill") ? 0 : 1);
'
check "both skill hooks are wired in hooks.json" ok $?

# ----------------------------------------------------------------- 7. flush
stub="$(new_sandbox)"
cat > "$stub/stub.mjs" <<'STUB'
import { createServer } from "node:http";
const code = Number(process.argv[2] || 200);
const srv = createServer((req, res) => {
  let b = ""; req.on("data", (c) => (b += c));
  req.on("end", () => { res.writeHead(code); res.end("{}"); });
});
srv.listen(0, () => console.log(srv.address().port));
// Self-destruct. The EXIT trap also kills these, but a stub that outlives its
// run is a process leak that compounds across invocations and starves later
// runs — so it must not depend on cleanup working.
setTimeout(() => process.exit(0), 120000);
STUB

start_stub() { # <code> -> echoes port
  # The PID is written to a file rather than tracked as a shell job: this
  # function is called inside a command substitution, so the background process
  # belongs to that subshell and `jobs -p` in the EXIT trap cannot see it.
  # Without this the stub servers survive the run and pile up across invocations.
  node "$stub/stub.mjs" "$1" > "$stub/port.$1" 2>/dev/null &
  echo $! >> "$stub/pids"
  for _ in $(seq 1 30); do   # up to 9s: a loaded machine starts node slowly
    [[ -s "$stub/port.$1" ]] && break
    sleep 0.3
  done
  cat "$stub/port.$1"
}

d="$(new_sandbox)"
port="$(start_stub 200)"
echo "{\"session_id\":\"s1\",\"cwd\":\"$PWD\"}" | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
check "flush exits 0 on success" ok $?
if [[ ! -f "$d/spool/events.jsonl" ]]; then
  echo "PASS: spool cleared after 2xx"
else
  echo "FAIL: spool retained after 2xx"
  failures=$((failures + 1))
fi

d="$(new_sandbox)"
port="$(start_stub 500)"
echo "{\"session_id\":\"s1\",\"cwd\":\"$PWD\"}" | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
check "flush exits 0 on server error" ok $?
if [[ -s "$d/spool/events.jsonl" ]]; then
  echo "PASS: spool retained after 5xx (events retry, never lost)"
else
  echo "FAIL: spool lost after 5xx"
  failures=$((failures + 1))
fi

d="$(new_sandbox)"
echo "{\"session_id\":\"s1\",\"cwd\":\"$PWD\"}" | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:1/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
check "flush exits 0 when the host is unreachable" ok $?
if [[ -s "$d/spool/events.jsonl" ]]; then
  echo "PASS: spool retained when offline"
else
  echo "FAIL: spool lost when offline"
  failures=$((failures + 1))
fi

d="$(new_sandbox)"
echo "{\"session_id\":\"s1\",\"cwd\":\"$PWD\"}" | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
RAFTKIT_TELEMETRY_DIR="$d" node "$FLUSH" >/dev/null 2>&1
if [[ -s "$d/spool/events.jsonl" ]]; then
  echo "PASS: no endpoint configured sends nothing and keeps the spool"
else
  echo "FAIL: spool cleared without an endpoint"
  failures=$((failures + 1))
fi

# -------------------------------------------- 8. governance docs + disclosure
# Full-prompt capture is deliberate, so the governance docs are the only thing
# standing between it and a surprised developer. These assert the docs describe
# what the code above actually does — no more, no less.
RULES="plugins/raftkit-core/skills/rules/SKILL.md"
README="README.md"

# Blockers must not be filed anywhere outward. These guard the removal: if
# someone reintroduces issue filing, the docs and the code disagree and this
# fails rather than quietly shipping a public write path again.
! grep -rq 'blocker\.mjs' plugins/raftkit-core/hooks/ 2>/dev/null
check "no blocker-filing hook remains" ok $?

! grep -rqE 'gh["'"'"' ]+issue|issue create|issue comment' plugins/raftkit-core/hooks/ 2>/dev/null
check "hooks never invoke gh issue" ok $?

GH_ISSUE_GUARD='gh["'"'"' ]+issue|issue create|issue comment|-X[[:space:]]*POST[[:space:]]+repos/[^[:space:]]+/issues|createIssue'
! grep -rqE "$GH_ISSUE_GUARD" plugins/raftkit-core/hooks/ 2>/dev/null
check "hooks never invoke gh issue (extended: REST POST or GraphQL createIssue)" ok $?

gh_issues_post_fixture='gh api -X POST repos/foo/bar/issues -f title=x'
grep -qE "$GH_ISSUE_GUARD" <<<"$gh_issues_post_fixture"
check "the extended guard catches a REST POST to repos/OWNER/REPO/issues via gh api" ok $?

gh_graphql_fixture='gh api graphql -f query=mutation{createIssue(input:{repositoryId:"R_1"}){issue{id}}}'
grep -qE "$GH_ISSUE_GUARD" <<<"$gh_graphql_fixture"
check "the extended guard catches a createIssue GraphQL mutation via gh api graphql" ok $?

# v2: the disclosure lives in the README (what developers read) and the rules
# skill states the one-stop rule the hook's gate event detects. Full-prompt
# capture is deliberate, so the README must say so plainly.
grep -qi 'dashboard' "$README"
check "README states blockers go to the dashboard" ok $?

# D1: free text is collected only where RaftKit ran. The README and the
# one-time notice must say exactly that, and the old unconditional claims —
# which the code no longer matches — must be gone.
grep -qi 'only in a session where a RaftKit skill ran' "$README" \
  && grep -qi 'first 512 characters' "$README" && grep -qi 'first 200 characters' "$README"
check "README states prompt and error text is collected only where a RaftKit skill ran, and how much" ok $?
! grep -qiE 'every prompt you submit, in full|anything from a repo you didn.t run RaftKit in' "$README"
check "README no longer claims full prompts everywhere or nothing from other repos" ok $?

grep -q 'RAFTKIT_TELEMETRY=off' "$README"
check "opt-out is stated in the README" ok $?

grep -q '^## One stop per run' "$RULES" && grep -qF '**STOP**' "$RULES"
check "rules states the one stop per run and its STOP marker" ok $?

node -e '
  const j = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/lib/refusals.json", "utf8"));
  const gate = j.refusals.find(r => r.severity === "gate");
  if (!gate) process.exit(1);
  if (!new RegExp(gate.pattern, "m").test(gate.example)) process.exit(2);
'
check "refusals.json carries exactly one gate rule whose example matches its pattern" ok $?

gates="$(grep -m1 'No skill ever auto-sends' CLAUDE.md)"
grep -qi 'exactly one exception' <<<"$gates" && grep -qi 'pr-auto-review' <<<"$gates"
check "CLAUDE.md's non-negotiable names exactly one exception" ok $?

grep -qi 'not.*an exception' <<<"$gates" && grep -qi 'dashboard' <<<"$gates"
check "CLAUDE.md states blocker telemetry is not an exception" ok $?

# An async hook's stdout AND JSON output are discarded — only its exit code is
# read. The SessionStart record hook must therefore stay synchronous, or the
# one-time disclosure below is written into a void and never seen once.
node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const entries = (h.hooks.SessionStart || []).flatMap((m) => m.hooks || []);
  const rec = entries.find((e) => (e.args || []).some((a) => /record\.mjs$/.test(a)));
  if (!rec) process.exit(1);
  process.exit(rec.async ? 1 : 0);
'
check "SessionStart record hook is not async, so its disclosure can render" ok $?

d="$(new_sandbox)"
first="$(echo '{"session_id":"n1","hook_event_name":"SessionStart"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
second="$(echo '{"session_id":"n2","hook_event_name":"SessionStart"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
if [[ "$first" == *systemMessage* && "$first" == *'RAFTKIT_TELEMETRY=off'* ]]; then
  echo "PASS: first run discloses collection on stdout"
else
  echo "FAIL: first run emitted no disclosure ('$first')"
  failures=$((failures + 1))
fi
expect_eq "disclosure is one-time, not once per session" "" "$second"

# D5: noticePending() only checks whether the marker FILE exists, not what
# notice version it recorded. A marker written by a pre-upgrade install (the
# format the code writes today: an ISO timestamp, nothing else) must not
# forever suppress a disclosure whose wording has since changed — the whole
# point of the marker is that the developer saw THIS notice, not some notice.
d="$(new_sandbox)"
echo "2020-01-01T00:00:00.000Z" > "$d/notice-shown"
stale_marker_out="$(echo '{"session_id":"pre-upgrade","hook_event_name":"SessionStart"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
if [[ "$stale_marker_out" == *systemMessage* && "$stale_marker_out" == *'RAFTKIT_TELEMETRY=off'* ]]; then
  echo "PASS: a pre-existing (pre-upgrade) notice-shown marker does not suppress the current notice"
else
  echo "FAIL: a stale notice-shown marker suppressed re-disclosure of the changed notice ('$stale_marker_out')"
  failures=$((failures + 1))
fi

# Version + description lockstep. The minimum is this story's introduced version;
# later work bumps further, and the repository version gate owns the exact one.
node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 8, 0];
  const cmp = v[0] - min[0] || v[1] - min[1] || v[2] - min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "raftkit-core version is at least 0.8.0 (telemetry bump held)" ok $?
node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-core/.claude-plugin/plugin.json", "utf8"));
  const entry = m.plugins.find((x) => x.name === "raftkit-core");
  process.exit(entry && entry.description === p.description ? 0 : 1);
'
check "marketplace description matches raftkit-core's manifest exactly" ok $?

# ================================================================ 10. hardening
# One assertion per defect from the runtime audit of the shipped hooks. Each is
# written to go red if its own fix is reverted and stay green otherwise.

# A stub that COUNTS the events it receives and can redirect, which the
# section-7 stub cannot. Writes "<port>" to stdout and the running event total
# to "$dir/count.<port>".
cat > "$stub/countstub.mjs" <<'STUB'
import { createServer } from "node:http";
import { writeFileSync } from "node:fs";
const code = Number(process.argv[2] || 200);
const location = process.argv[3] || "";
const countFile = process.argv[4];
let total = 0;
const srv = createServer((req, res) => {
  let b = "";
  req.on("data", (c) => (b += c));
  req.on("end", () => {
    try { total += (JSON.parse(b).batch || []).length; } catch { /* ignore */ }
    writeFileSync(countFile, String(total));
    const headers = location ? { Location: location } : {};
    res.writeHead(code, headers);
    res.end("{}");
  });
});
srv.listen(0, () => console.log(srv.address().port));
setTimeout(() => process.exit(0), 120000);
STUB

start_counting_stub() { # <code> <location> <countfile> -> echoes port
  local tag="c$RANDOM"
  # Seed with 0, not an empty file: "received nothing" has to be distinguishable
  # from "the count file was never written", or a stub that is never contacted
  # yields '' and every comparison against a number is vacuous.
  printf '0' > "$3"
  node "$stub/countstub.mjs" "$1" "$2" "$3" > "$stub/port.$tag" 2>/dev/null &
  echo $! >> "$stub/pids"
  for _ in $(seq 1 30); do   # up to 9s: a loaded machine starts node slowly
    [[ -s "$stub/port.$tag" ]] && break
    sleep 0.3
  done
  cat "$stub/port.$tag"
}

write_spool() { # <dir> <n> — n synthetic prompt events, oldest first
  mkdir -p "$1/spool"
  node -e '
    const fs = require("fs");
    let out = "";
    for (let i = 0; i < Number(process.argv[2]); i++) {
      out += JSON.stringify({
        event_id: "e" + i, ts: new Date().toISOString(),
        event: "raftkit_prompt_submitted", distinct_id: "x@y.z", props: { n: i },
      }) + "\n";
    }
    fs.writeFileSync(process.argv[1] + "/spool/events.jsonl", out);
  ' "$1" "$2"
}

# --- F2 end-to-end: an auth header in a real prompt must not reach the spool -
d="$(new_sandbox)"; seed_skill "$d" s1
echo '{"session_id":"s1","user_prompt":"why does curl -H \"Authorization: Bearer ghs_LIVETOKEN99887766554433\" 401","cwd":"'"$PWD"'"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
captured="$(last_event_field "$d/spool/events.jsonl" 'props.prompt')"
if [[ "$captured" == *"ghs_LIVETOKEN"* ]]; then
  echo "FAIL: Authorization header token reached the spool ('$captured')"
  failures=$((failures + 1))
else
  echo "PASS: Authorization header token never reaches the spool"
fi
[[ "$captured" == *"why does curl"* ]]
check "  and the rest of that prompt was captured, so the check means something" ok $?

# --- F3: the synchronous SessionStart path must fit its declared timeout ----
# It chained stdin + 2 git + `gh api user` + 2 more git at 3-4s each: 16.1s
# against a declared 15s, at which point the harness kills it and the one-time
# disclosure dies with it. `gh` is off this path entirely now and the local git
# calls are on a 1s budget.
hung="$(new_sandbox)"; mkdir -p "$hung/bin"
printf '#!/usr/bin/env bash\nsleep 60\n' > "$hung/bin/git"
cp "$hung/bin/git" "$hung/bin/gh"
chmod +x "$hung/bin/git" "$hung/bin/gh"
declared_timeout="$(node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const rec = (h.hooks.SessionStart || []).flatMap((m) => m.hooks || [])
    .find((e) => (e.args || []).some((a) => /record\.mjs$/.test(a)));
  process.stdout.write(String(rec.timeout));
')"
d="$(new_sandbox)"
sync_start=$(date +%s)
echo '{"session_id":"s1","hook_event_name":"SessionStart"}' \
  | PATH="$hung/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
sync_elapsed=$(( $(date +%s) - sync_start ))
# "Comfortably under" = at most half the budget, with every subprocess hung.
budget=$(( declared_timeout / 2 ))
if [[ "$sync_elapsed" -le "$budget" ]]; then
  echo "PASS: synchronous SessionStart worst case ${sync_elapsed}s is within half its ${declared_timeout}s timeout"
else
  echo "FAIL: synchronous SessionStart took ${sync_elapsed}s, over half the declared ${declared_timeout}s"
  failures=$((failures + 1))
fi
# The whole point of keeping it under: the disclosure has to survive.
if [[ -f "$d/notice-shown" ]]; then
  echo "PASS: the one-time disclosure still renders on the bounded path"
else
  echo "FAIL: disclosure lost on the synchronous path"
  failures=$((failures + 1))
fi

# --- F4: a repo you open must not be able to redirect telemetry -------------
# .claude/settings.json ships an `env` block and is checked into repos, so the
# endpoint override is only honoured under an explicit RAFTKIT_DEV=1.
node -e '
  const { execFileSync } = require("child_process");
  const read = (env) => JSON.parse(execFileSync(process.execPath, ["--input-type=module", "-e",
    "import { config } from \"./plugins/raftkit-core/hooks/lib/common.mjs\"; process.stdout.write(JSON.stringify(config()));"
  ], { encoding: "utf8", env: { ...process.env, ...env } }));
  const clear = { RAFTKIT_DEV: undefined, RAFTKIT_TELEMETRY_ENDPOINT: undefined };
  let bad = 0;
  // Hostile project env, no opt-in: ignored.
  const hostile = read({ ...clear, RAFTKIT_TELEMETRY_ENDPOINT: "https://evil.example/collect" });
  if (hostile.endpoint === "https://evil.example/collect") { console.error("  endpoint hijacked without RAFTKIT_DEV"); bad++; }
  // The override still works when deliberately opted in.
  //
  // CR-A: this used to point at "https://stub.example/x" — an off-box HTTPS
  // host. Once RAFTKIT_DEV=1 stops honouring an off-box HTTPS override (see
  // the new assertion right below), that URL would no longer take effect and
  // this specific assertion would become a false failure having nothing to
  // do with what it is meant to prove ("the RAFTKIT_DEV override mechanism
  // still works at all"). A loopback URL is opted-in AND still allowed post-fix.
  const ep = read({ ...clear, RAFTKIT_DEV: "1", RAFTKIT_TELEMETRY_ENDPOINT: "http://127.0.0.1:1/x" });
  if (ep.endpoint !== "http://127.0.0.1:1/x") { console.error("  RAFTKIT_DEV endpoint override stopped working"); bad++; }
  process.exit(bad === 0 ? 0 : 1);
' >/dev/null 2>&1
check "project env cannot redirect telemetry without RAFTKIT_DEV" ok $?

# CR-A: RAFTKIT_DEV=1 means "I am a developer deliberately testing hooks", not
# "accept any endpoint literally". An off-box HTTPS host must still be refused
# even when opted in — only loopback (the test suite's own stub servers) may
# bypass the cleartext-remote restriction endpointUsable() enforces elsewhere.
node -e '
  const { execFileSync } = require("child_process");
  const read = (env) => JSON.parse(execFileSync(process.execPath, ["--input-type=module", "-e",
    "import { config } from \"./plugins/raftkit-core/hooks/lib/common.mjs\"; process.stdout.write(JSON.stringify(config()));"
  ], { encoding: "utf8", env: { ...process.env, ...env } }));
  const clear = { RAFTKIT_DEV: undefined, RAFTKIT_TELEMETRY_ENDPOINT: undefined };
  const evil = read({ ...clear, RAFTKIT_DEV: "1", RAFTKIT_TELEMETRY_ENDPOINT: "https://evil.example/collect" });
  if (evil.endpoint === "https://evil.example/collect") { console.error("  off-box HTTPS override was accepted under RAFTKIT_DEV=1: " + evil.endpoint); process.exit(1); }
  process.exit(0);
' >/dev/null 2>&1
check "RAFTKIT_DEV=1 refuses an off-box HTTPS override (evil.example is not honoured)" ok $?

# Opting OUT must never require an opt-in. Explicitly without RAFTKIT_DEV.
for var in "RAFTKIT_TELEMETRY=off" "DO_NOT_TRACK=1"; do
  d="$(new_sandbox)"
  echo '{"session_id":"x"}' | env -u RAFTKIT_DEV "$var" RAFTKIT_TELEMETRY_DIR="$d" \
    node "$RECORD" session_start >/dev/null 2>&1
  if [[ ! -f "$d/spool/events.jsonl" ]]; then
    echo "PASS: $var still works with RAFTKIT_DEV unset"
  else
    echo "FAIL: $var stopped working when RAFTKIT_DEV was unset"
    failures=$((failures + 1))
  fi
done

# --- F5: the spool drains fully and stays bounded ---------------------------
# It took only the newest 500 and deleted the rest on success: 600 spooled
# events meant 500 sent and the oldest 100 destroyed, contradicting the file's
# own "a failed flush loses nothing" comment.
d="$(new_sandbox)"
cnt="$d/received"
port="$(start_counting_stub 200 "" "$cnt")"
write_spool "$d" 600
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
expect_eq "a spool over the batch cap is drained in full, nothing destroyed" "600" "$(cat "$cnt" 2>/dev/null)"
if [[ ! -f "$d/spool/events.jsonl" ]]; then
  echo "PASS: spool cleared only once every event was sent"
else
  echo "FAIL: spool retained after a complete drain"
  failures=$((failures + 1))
fi

# An offline developer must not grow the file forever.
d="$(new_sandbox)"
mkdir -p "$d/spool"
node -e '
  const fs = require("fs");
  const pad = "x".repeat(600);
  let out = "";
  for (let i = 0; i < 6000; i++) {
    out += JSON.stringify({ event_id: "old" + i, ts: "t", event: "raftkit_prompt_submitted",
                            distinct_id: "x", props: { prompt: pad } }) + "\n";
  }
  fs.writeFileSync(process.argv[1] + "/spool/events.jsonl", out);
' "$d"
before_bytes=$(wc -c < "$d/spool/events.jsonl" | tr -d ' ')
echo '{"session_id":"s1","user_prompt":"one more","cwd":"'"$PWD"'"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
after_bytes=$(wc -c < "$d/spool/events.jsonl" | tr -d ' ')
if [[ "$after_bytes" -lt "$before_bytes" ]]; then
  echo "PASS: an over-cap spool is pruned at append time ($before_bytes -> $after_bytes bytes)"
else
  echo "FAIL: spool grew unbounded ($before_bytes -> $after_bytes bytes)"
  failures=$((failures + 1))
fi
if grep -q 'raftkit_spool_dropped' "$d/spool/events.jsonl"; then
  echo "PASS: dropped events are recorded as data, not lost silently"
else
  echo "FAIL: spool pruning dropped events without recording it"
  failures=$((failures + 1))
fi

# --- F6: identity comes from the person, not the repo they happen to be in --
# `git config --get user.email` ran with no cwd, so a client repo's local
# address was pinned as the developer's identity for the whole 7-day TTL.
homedir="$(new_sandbox)"
printf '[user]\n\temail = global@raftlabs.com\n\tname = Global Dev\n' > "$homedir/.gitconfig"
clientrepo="$(new_sandbox)"
git -C "$clientrepo" init -q 2>/dev/null
git -C "$clientrepo" config user.email "someone@bigclient.example" 2>/dev/null
git -C "$clientrepo" config user.name "Client Local" 2>/dev/null
d="$(new_sandbox)"
( cd "$clientrepo" && echo '{"session_id":"s1"}' \
  | HOME="$homedir" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD_ABS" session_start >/dev/null 2>&1 )
who_id="$(last_event_field "$d/spool/events.jsonl" 'distinct_id')"
if [[ "$who_id" == *"bigclient.example"* ]]; then
  echo "FAIL: a client repo's local git email became the developer's identity ('$who_id')"
  failures=$((failures + 1))
else
  echo "PASS: identity resolves from HOME, not the repo in front of it ('$who_id')"
fi
# A resolve that found nothing must not be cached like a success.
node -e '
  const fs = require("fs");
  const p = process.argv[1] + "/identity.json";
  const c = JSON.parse(fs.readFileSync(p, "utf8"));
  // Age it by an hour and blank the email: a miss must expire fast.
  fs.writeFileSync(p, JSON.stringify({ ...c, email: "", distinct_id: "anon:zz",
                                       resolved_at: Date.now() - 60 * 60 * 1000 }));
' "$d"
echo '{"session_id":"s2"}' | HOME="$homedir" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
if [[ "$(last_event_field "$d/spool/events.jsonl" 'distinct_id')" == "anon:zz" ]]; then
  echo "FAIL: a failed identity resolve was cached with the full TTL and stayed sticky"
  failures=$((failures + 1))
else
  echo "PASS: a failed identity resolve expires quickly and is retried"
fi

# --- F9: no redirects, no cleartext -----------------------------------------
# A 307 would re-POST the whole batch, prompts included, to whatever host the
# redirect named.
d="$(new_sandbox)"
victim_cnt="$d/victim"
attacker_cnt="$d/attacker"
attacker_port="$(start_counting_stub 200 "" "$attacker_cnt")"
victim_port="$(start_counting_stub 307 "http://127.0.0.1:$attacker_port/collect" "$victim_cnt")"
write_spool "$d" 3
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$victim_port/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
expect_eq "a redirect does not forward the batch to the redirect target" "0" "$(cat "$attacker_cnt" 2>/dev/null)"
if [[ -s "$d/spool/events.jsonl" ]]; then
  echo "PASS: a redirected flush is treated as a failure and retains the spool"
else
  echo "FAIL: events lost to a redirect"
  failures=$((failures + 1))
fi

node --input-type=module -e '
  import { endpointUsable } from "./plugins/raftkit-core/hooks/lib/common.mjs";
  const cases = [
    ["https://raftkit.raftlabs.dev/api/telemetry", true],
    ["http://192.0.2.10/collect", false],
    ["http://evil.example/collect", false],
    ["http://127.0.0.1:8080/x", true],
    ["http://localhost:8080/x", true],
    ["not a url", false],
  ];
  let bad = 0;
  for (const [url, want] of cases) {
    if (endpointUsable(url) !== want) { console.error("  wrong verdict for " + url); bad++; }
  }
  process.exit(bad === 0 ? 0 : 1);
' >/dev/null 2>&1
check "the endpoint predicate refuses remote cleartext and allows loopback" ok $?

# ...and prove flush actually CONSULTS it. The predicate passing its own unit
# test says nothing about it being wired in: deleting the call site left the
# suite fully green until this assertion was added.
#
# Observable difference: a refused endpoint returns before the spool is claimed,
# so the file is untouched byte-for-byte. A flush that proceeds renames it away
# and rewrites it, which normalises the padding blank lines below.
d="$(new_sandbox)"
write_spool "$d" 2
printf '\n\n' >> "$d/spool/events.jsonl"
spool_sum() { cksum < "$1" | cut -d' ' -f1; }
before_sum="$(spool_sum "$d/spool/events.jsonl")"
# TEST-NET-1: reserved for documentation and guaranteed unroutable, so a
# regression here cannot reach a real host.
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://192.0.2.10:9/collect" \
  node "$FLUSH" >/dev/null 2>&1
expect_eq "flush refuses a remote cleartext endpoint before claiming the spool" \
  "$before_sum" "$(spool_sum "$d/spool/events.jsonl")"

# --- F10: two sessions flushing at once must not race -----------------------
# One process could delete the other's claim file mid-fetch.
d="$(new_sandbox)"
cnt="$d/received"
port="$(start_counting_stub 200 "" "$cnt")"
write_spool "$d" 5
mkdir -p "$d/spool"
printf '999999' > "$d/flush.lock"   # another flush is already draining
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
expect_eq "a second concurrent flush sends nothing while the lock is held" "0" "$(cat "$cnt" 2>/dev/null)"
if [[ -s "$d/spool/events.jsonl" ]]; then
  echo "PASS: the blocked flush left the other session's spool untouched"
else
  echo "FAIL: a locked-out flush destroyed the spool"
  failures=$((failures + 1))
fi
# A lock left by a killed process must not wedge telemetry forever.
node -e '
  const fs = require("fs");
  const p = process.argv[1] + "/flush.lock";
  const old = new Date(Date.now() - 10 * 60 * 1000);
  fs.utimesSync(p, old, old);
' "$d"
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" \
  node "$FLUSH" >/dev/null 2>&1
expect_eq "a stale lock is broken so a crash cannot wedge telemetry" "5" "$(cat "$cnt" 2>/dev/null)"

# --- F14: scrubbing cost must not scale with input size ---------------------
# The 2000-char output cap applied AFTER every pattern ran over the full input;
# an unterminated PEM made that quadratic (1MB 0.7s, 4MB 10.5s).
node --input-type=module -e '
  import { scrub } from "./plugins/raftkit-core/hooks/lib/scrub.mjs";
  const big = "-----BEGIN RSA PRIVATE KEY-----\n".repeat(700000); // ~21MB
  const t = Date.now();
  const out = scrub(big);
  const ms = Date.now() - t;
  if (ms > 1000) { console.error("  scrub took " + ms + "ms on " + big.length + " bytes"); process.exit(1); }
  // Redaction still happens before truncation — the ordering is load-bearing.
  if (!out.startsWith("[REDACTED:private-key]")) { console.error("  ordering broke: " + out.slice(0, 60)); process.exit(1); }
  process.exit(0);
' >/dev/null 2>&1
check "scrubbing a huge tool output stays bounded and still redacts first" ok $?

# ================================================================ 10b. scope (D1)
# In a session where no RaftKit skill runs, no prompt or error text is kept.
d="$(new_sandbox)"; sp="$d/spool/events.jsonl"
printf '{"session_id":"q1","user_prompt":"refactor the billing module for acme"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
expect_eq "a prompt in a session with no RaftKit skill is recorded without its text" "raftkit_prompt_submitted|" \
  "$(last_event_field "$sp" event)|$(last_event_field "$sp" props.prompt | sed 's/^undefined$//')"
printf '%s' '{"session_id":"q1","tool_name":"Bash","error":"Exit code 1\ncat: secrets.env: contents here"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" tool_failure >/dev/null 2>&1
expect_eq "a failed tool in such a session keeps its exit code, not its text" "1|" \
  "$(last_event_field "$sp" props.exit_code)|$(last_event_field "$sp" props.error | sed 's/^undefined$//')"
if grep -q 'acme\|secrets.env' "$sp"; then
  echo "FAIL: free text from a session with no RaftKit skill reached the spool"
  failures=$((failures + 1))
else
  echo "PASS: no free text from a session with no RaftKit skill reaches the spool"
fi
seed_skill "$d" q1
printf '{"session_id":"q1","user_prompt":"now implement the story"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
expect_eq "once a RaftKit skill ran, the prompt text is kept" "now implement the story" "$(last_event_field "$sp" props.prompt)"
long_prompt="$(printf 'please change the header layout %.0s' $(seq 1 40))"
printf '{"session_id":"q1","user_prompt":"%s"}' "$long_prompt" | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
expect_eq "  at most 512 characters of it" "512" "$(ev_len="$(last_event_field "$sp" props.prompt)" node -e 'process.stdout.write(String([...process.env.ev_len].length))')"
# The disclosure says the same thing the README does.
d="$(new_sandbox)"
notice="$(echo '{"session_id":"n9","hook_event_name":"SessionStart"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
[[ "$notice" == *'In a session where a RaftKit skill runs'* && "$notice" == *'prompts'* && "$notice" != *'Prompts preceding a stop'* ]]
check "the one-time notice states the free-text scope" ok $?

# ================================================================ 11. delivery
# v2's first STOP wedged delivery: the server rejected severity "gate", every
# flush 4xx'd whole, and nothing said so. These pin the client half of the fix.

# A stub that keeps every request body, so a test can inspect what was sent.
cat > "$stub/capstub.mjs" <<'STUB'
import { createServer } from "node:http";
import { writeFileSync } from "node:fs";
const [code, dir, reply] = [Number(process.argv[2] || 200), process.argv[3], process.argv[4] || "{}"];
let n = 0;
const srv = createServer((req, res) => {
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", () => {
    writeFileSync(`${dir}/body.${String(n++).padStart(4, "0")}.json`, Buffer.concat(chunks));
    res.writeHead(code); res.end(reply);
  });
});
srv.listen(0, () => console.log(srv.address().port));
setTimeout(() => process.exit(0), 120000);
STUB

start_capture_stub() { # <code> <dir> [reply] -> echoes port
  local tag="k$RANDOM"
  mkdir -p "$2"
  node "$stub/capstub.mjs" "$1" "$2" "${3:-{\}}" > "$stub/port.$tag" 2>/dev/null &
  echo $! >> "$stub/pids"
  for _ in $(seq 1 30); do   # up to 9s: a loaded machine starts node slowly
    [[ -s "$stub/port.$tag" ]] && break
    sleep 0.3
  done
  cat "$stub/port.$tag"
}

bodies() { # <capture dir> <node expression over `events` (all sent events) and `sizes` (bytes per body)>
  # eval runs only the expressions written in this file, never captured data.
  node -e '
    const fs = require("fs"); const dir = process.argv[1];
    const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.startsWith("body.")).sort() : [];
    const raw = files.map((f) => fs.readFileSync(dir + "/" + f));
    const sizes = raw.map((b) => b.length);
    const events = raw.flatMap((b) => JSON.parse(b.toString("utf8")).batch || []);
    process.stdout.write(String(eval(process.argv[2])));
  ' "$1" "$2" 2>/dev/null
}

# --- 900 KB batches: a server that caps bodies at 1 MB must never see a bigger one
d="$(new_sandbox)"; cap="$d/cap"
port="$(start_capture_stub 200 "$cap")"
mkdir -p "$d/spool"
node -e '
  const fs = require("fs"); const big = "x".repeat(2000); let out = "";
  for (let i = 0; i < 1200; i++) out += JSON.stringify({ event_id: "b" + i, ts: "2026-09-17T10:37:00.000Z",
    event: "raftkit_blocked", distinct_id: "x", props: { prompt: big, matched_line: big, detail: big, error: big, args: big } }) + "\n";
  fs.writeFileSync(process.argv[1] + "/spool/events.jsonl", out);
' "$d"
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" node "$FLUSH" >/dev/null 2>&1
expect_eq "every event of a large spool is delivered" "1200" "$(bodies "$cap" 'events.length')"
expect_eq "no request body exceeds 900 KB" "true" "$(bodies "$cap" 'sizes.length > 1 && Math.max(...sizes) <= 900000')"

# --- free text is clamped to 512 chars on the wire, even for events spooled before the clamp
expect_eq "free-text fields reach the server at 512 chars or fewer" "true" \
  "$(bodies "$cap" 'events.every((e) => ["prompt","matched_line","detail","error","args"].every((k) => e.properties[k].length <= 512))')"

# --- a severity the server does not know is sent as info, with the original kept
d="$(new_sandbox)"; cap="$d/cap"
port="$(start_capture_stub 200 "$cap")"
mkdir -p "$d/spool"
printf '%s\n' \
  '{"event_id":"g1","ts":"2026-09-17T10:37:00.000Z","event":"raftkit_gate_shown","distinct_id":"x","props":{"refusal_id":"stop-shown","severity":"gate"}}' \
  '{"event_id":"g2","ts":"2026-09-17T10:38:00.000Z","event":"raftkit_blocked","distinct_id":"x","props":{"refusal_id":"not-ready","severity":"blocker"}}' \
  > "$d/spool/events.jsonl"
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" node "$FLUSH" >/dev/null 2>&1
expect_eq "a gate event is sent with severity info" "info" "$(bodies "$cap" 'events.find((e) => e.event_id === "g1").properties.severity')"
expect_eq "  and keeps gate in severity_detail" "gate" "$(bodies "$cap" 'events.find((e) => e.event_id === "g1").properties.severity_detail')"
expect_eq "a known severity is sent unchanged" "blocker|undefined" \
  "$(bodies "$cap" 'events.find((e) => e.event_id === "g2").properties.severity + "|" + events.find((e) => e.event_id === "g2").properties.severity_detail')"

# --- a rejected flush says why, and when delivery stopped
d="$(new_sandbox)"; cap="$d/cap"
port="$(start_capture_stub 400 "$cap" '{"error":"invalid severity"}')"
write_spool "$d" 3
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" node "$FLUSH" >/dev/null 2>&1
expect_eq "a non-2xx flush writes last-flush-error with the status" "400" \
  "$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).status))' "$d/last-flush-error" 2>/dev/null)"
expect_eq "  and the server's reason" "true" \
  "$(node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).error.includes("invalid severity")))' "$d/last-flush-error" 2>/dev/null)"
# The streak's start is what "has not delivered since" means, so a repeat keeps it.
node -e '
  const fs = require("fs"); const p = process.argv[1];
  fs.writeFileSync(p, JSON.stringify({ ...JSON.parse(fs.readFileSync(p, "utf8")), ts: "2026-09-17T10:37:10.000Z" }));
' "$d/last-flush-error"
rm -f "$d/last-flush"
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" node "$FLUSH" >/dev/null 2>&1
expect_eq "a repeated failure keeps the time delivery first failed" "2026-09-17T10:37:10.000Z" \
  "$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).ts)' "$d/last-flush-error" 2>/dev/null)"
expect_eq "  and keeps the events for the next session" "3" "$(wc -l < "$d/spool/events.jsonl" | tr -d ' ')"

# The developer is told, at most once a day, while the error stands. An async
# hook's output is never shown, so only session start may spend the day's line.
echo '{"session_id":"w0","user_prompt":"hi"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
expect_eq "an async hook never spends the day's stuck-delivery message" "no" \
  "$([[ -f "$d/flush-warning-shown" ]] && echo yes || echo no)"
warn1="$(echo '{"session_id":"w1","hook_event_name":"SessionStart"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
warn2="$(echo '{"session_id":"w2","hook_event_name":"SessionStart"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
if [[ "$warn1" == *'RaftKit telemetry has not delivered since 2026-09-17'* ]]; then
  echo "PASS: session start tells the developer delivery is stuck, and since when"
else
  echo "FAIL: no stuck-delivery message at session start ('${warn1:0:160}')"
  failures=$((failures + 1))
fi
expect_eq "the stuck-delivery message is shown at most once a day" "" "$warn2"
node -e '
  const fs = require("fs"); const p = process.argv[1] + "/flush-warning-shown";
  fs.writeFileSync(p, String(Date.now() - 25 * 60 * 60 * 1000));
' "$d"
warn3="$(echo '{"session_id":"w3","hook_event_name":"SessionStart"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
if [[ "$warn3" == *'has not delivered since'* ]]; then
  echo "PASS: the stuck-delivery message returns the next day"
else
  echo "FAIL: the stuck-delivery message did not return after a day ('${warn3:0:120}')"
  failures=$((failures + 1))
fi

# A successful flush clears the error, and the message stops.
port="$(start_capture_stub 200 "$d/cap-ok")"
rm -f "$d/last-flush"
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:$port/api/telemetry" node "$FLUSH" >/dev/null 2>&1
expect_eq "a delivered flush removes last-flush-error" "no" "$([[ -f "$d/last-flush-error" ]] && echo yes || echo no)"
rm -f "$d/flush-warning-shown"
warn4="$(echo '{"session_id":"w4","hook_event_name":"SessionStart"}' | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start 2>/dev/null)"
expect_eq "no stuck-delivery message once delivery works" "" "$warn4"

# An offline flush is not a server rejection: nothing to report.
d="$(new_sandbox)"
write_spool "$d" 2
RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY_ENDPOINT="http://127.0.0.1:1/api/telemetry" node "$FLUSH" >/dev/null 2>&1
expect_eq "an unreachable endpoint writes no last-flush-error" "no" "$([[ -f "$d/last-flush-error" ]] && echo yes || echo no)"

# ================================================================ 12. the ledger
# Claude Code records each session's cost in its own config. SessionStart sends
# the previous session's cost fields once, as the ground truth the transcript
# count is calibrated against — and reads nothing else from that file.
d="$(new_sandbox)"; cfgd="$(new_sandbox)"
write_ledger() { # <config dir> <lastStartTime>
  node -e '
    const [dir, cwd, start] = process.argv.slice(1);
    require("fs").writeFileSync(dir + "/.claude.json", JSON.stringify({
      oauthAccount: { emailAddress: "SECRET_EMAIL@example.com" },
      projects: { [cwd]: {
        lastSessionId: "prev-0001", lastStartTime: Number(start), lastCost: 1.25, lastDuration: 60000, lastAPIDuration: 30000,
        lastTotalInputTokens: 10, lastTotalOutputTokens: 20, lastTotalCacheReadInputTokens: 300, lastTotalCacheCreationInputTokens: 40,
        lastModelUsage: { "claude-opus-5-5": { inputTokens: 10, outputTokens: 20, cacheReadInputTokens: 300, cacheCreationInputTokens: 40, costUSD: 1.25 } },
        mcpServers: { x: { env: { TOKEN: "SECRET_MCP_VALUE" } } }, allowedTools: ["SECRET_TOOL"],
      } },
    }));
  ' "$1" "$PWD" "$2"
}
write_ledger "$cfgd" 1790000000000
cost_field() { # <spool> <field|count> — a field of the one raftkit_session_cost event, or how many were sent
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const e = (fs.existsSync(p) ? fs.readFileSync(p, "utf8").trim().split("\n") : []).filter(Boolean).map((l) => JSON.parse(l)).filter((x) => x.event === "raftkit_session_cost");
    if (process.argv[2] === "count") { process.stdout.write(String(e.length)); process.exit(0); }
    let v = e.length === 1 ? e[0] : undefined;   // a field is read only when exactly one was sent
    for (const k of process.argv[2].split(".")) v = v == null ? undefined : v[k];
    process.stdout.write(String(v));
  ' "$1" "$2" 2>/dev/null
}
echo "{\"session_id\":\"s-new\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\",\"cwd\":\"$PWD\"}" \
  | CLAUDE_CONFIG_DIR="$cfgd" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
expect_eq "session start sends the previous session's ledger" "prev-0001" "$(cost_field "$d/spool/events.jsonl" props.cost_session_id)"
expect_eq "  with its token total" "370" "$(cost_field "$d/spool/events.jsonl" props.total)"
expect_eq "  its cost" "1.25" "$(cost_field "$d/spool/events.jsonl" props.cost_usd)"
expect_eq "  and its cost per model" "1.25" "$(cost_field "$d/spool/events.jsonl" 'props.by_model.claude-opus-5-5.cost_usd')"
if grep -q 'SECRET_' "$d/spool/events.jsonl"; then
  echo "FAIL: something other than the cost fields was read out of the Claude Code config"
  failures=$((failures + 1))
else
  echo "PASS: only the cost fields are read out of the Claude Code config"
fi
echo "{\"session_id\":\"s-new2\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\",\"cwd\":\"$PWD\"}" \
  | CLAUDE_CONFIG_DIR="$cfgd" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
expect_eq "the same ledger entry is sent once" "prev-0001" "$(cost_field "$d/spool/events.jsonl" props.cost_session_id)"
write_ledger "$cfgd" 1790000999000   # a resumed session's next segment
echo "{\"session_id\":\"s-new3\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\",\"cwd\":\"$PWD\"}" \
  | CLAUDE_CONFIG_DIR="$cfgd" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
expect_eq "a new segment of the ledger is sent" "2" "$(cost_field "$d/spool/events.jsonl" count)"

# The ledger is keyed by the project directory. A session in a subfolder is
# matched through CLAUDE_PROJECT_DIR, never by walking up to some parent's entry.
d="$(new_sandbox)"; sub="$PWD/plugins"
echo "{\"session_id\":\"s-sub\",\"hook_event_name\":\"SessionStart\",\"cwd\":\"$sub\"}" \
  | CLAUDE_CONFIG_DIR="$cfgd" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
expect_eq "a parent directory's ledger is never credited to a subfolder session" "0" "$(cost_field "$d/spool/events.jsonl" count)"
echo "{\"session_id\":\"s-sub2\",\"hook_event_name\":\"SessionStart\",\"cwd\":\"$sub\"}" \
  | CLAUDE_CONFIG_DIR="$cfgd" CLAUDE_PROJECT_DIR="$PWD" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
expect_eq "  while the session's own project directory finds it" "prev-0001" "$(cost_field "$d/spool/events.jsonl" props.cost_session_id)"

# Per-session state is bounded: files for sessions untouched in two weeks go.
d="$(new_sandbox)"; mkdir -p "$d/sessions"
echo '{}' > "$d/sessions/old-0001.tokens.json"; echo '{}' > "$d/sessions/new-0001.tokens.json"; echo '{}' > "$d/tokens.json"
node -e 'const fs=require("fs"); const t=new Date(Date.now()-20*86400000); fs.utimesSync(process.argv[1], t, t);' "$d/sessions/old-0001.tokens.json"
echo '{"session_id":"p1","hook_event_name":"SessionStart"}' | CLAUDE_CONFIG_DIR="$cfgd" RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" session_start >/dev/null 2>&1
expect_eq "session state older than two weeks is removed" "no" "$([[ -f "$d/sessions/old-0001.tokens.json" ]] && echo yes || echo no)"
expect_eq "  recent session state is kept" "yes" "$([[ -f "$d/sessions/new-0001.tokens.json" ]] && echo yes || echo no)"
expect_eq "  and the pre-v2.1 token state file is retired" "no" "$([[ -f "$d/tokens.json" ]] && echo yes || echo no)"

# ================================================================ 13. journeys
# One RaftKit run is one journey: it opens at a skill invocation, carries one
# journey_id on every event, and its STOP is paired with the human's reply.
hook() { # <telemetry dir> <mode> <json payload>
  printf '%s' "$3" | RAFTKIT_TELEMETRY_DIR="$1" node "$RECORD" "$2" >/dev/null 2>&1
}
events_json() { # <spool> — the whole spool as one JSON array
  node -e 'const fs=require("fs"); const p=process.argv[1];
    process.stdout.write(JSON.stringify(fs.existsSync(p) ? fs.readFileSync(p,"utf8").trim().split("\n").map((l)=>JSON.parse(l)) : []));' "$1"
}
ev() { # <spool> <node expression over `E` (all events)>
  # eval runs only the expressions written in this file, never spooled data.
  node -e 'const E=JSON.parse(require("fs").readFileSync(0,"utf8")); process.stdout.write(String(eval(process.argv[1])));' "$2" <<< "$(events_json "$1")" 2>/dev/null
}

# --- pairing: the first HUMAN prompt after the STOP is the reply
d="$(new_sandbox)"; sp="$d/spool/events.jsonl"
hook "$d" skill '{"session_id":"j1","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:implement"}}'
hook "$d" stop '{"session_id":"j1","last_assistant_message":"PR draft ready.\n**STOP** — approve to push, edit to change, or decline."}'
hook "$d" prompt '{"session_id":"j1","user_prompt":"<task-notification>\n<task-id>a1</task-id>\n<status>completed</status>\n</task-notification>"}'
hook "$d" stop '{"session_id":"j1","stop_hook_active":true,"last_assistant_message":"Still waiting on your go."}'
hook "$d" prompt '{"session_id":"j1","user_prompt":"go"}'
hook "$d" prompt '{"session_id":"j1","user_prompt":"thanks"}'
expect_eq "a task notification after the STOP is not the reply" "false|task_notification" \
  "$(ev "$sp" 'const p=E.filter(e=>e.event==="raftkit_prompt_submitted"); p[0].props.after_gate+"|"+p[0].props.prompt_kind')"
expect_eq "  and its text is never captured" "" \
  "$(ev "$sp" 'E.filter(e=>e.event==="raftkit_prompt_submitted")[0].props.prompt || ""')"
expect_eq "a Stop-hook loop turn is marked, and does not consume the gate" "true" \
  "$(ev "$sp" 'E.filter(e=>e.event==="raftkit_turn_completed").at(-1).props.stop_hook_active')"
expect_eq "the first human prompt after the STOP is the reply" "true|human" \
  "$(ev "$sp" 'const p=E.filter(e=>e.event==="raftkit_prompt_submitted"); p[1].props.after_gate+"|"+p[1].props.prompt_kind')"
expect_eq "  and only that one" "false" "$(ev "$sp" 'E.filter(e=>e.event==="raftkit_prompt_submitted")[2].props.after_gate')"

# --- one journey id and the skill's sha12 on every event of the run
sha12="$(shasum -a 256 plugins/raftkit-dev/skills/implement/SKILL.md | cut -c1-12)"
expect_eq "every event of the run carries the same journey_id" "1" \
  "$(ev "$sp" 'new Set(E.map(e=>e.props.journey_id)).size + (E.every(e=>e.props.journey_id) ? 0 : 100)')"
expect_eq "  and the skill's sha12" "$sha12" "$(ev "$sp" '[...new Set(E.map(e=>e.props.skill_sha12))].join(",")')"

# --- nested invocations stay in the run; the next run gets a new journey
d="$(new_sandbox)"; sp="$d/spool/events.jsonl"
hook "$d" skill '{"session_id":"j2","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:implement"}}'
hook "$d" skill '{"session_id":"j2","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-core:rules"}}'
hook "$d" skill '{"session_id":"j2","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:scope-guard"}}'
hook "$d" stop '{"session_id":"j2","last_assistant_message":"**STOP** — approve to push, edit to change, or decline."}'
hook "$d" skill '{"session_id":"j2","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:fix"}}'
hook "$d" skill '{"session_id":"j2","hook_event_name":"UserPromptExpansion","command_name":"raftkit-dev:fix","command_args":"bug 7"}'
expect_eq "a skill loaded inside an open run stays in that run" "1" \
  "$(ev "$sp" 'new Set(E.filter(e=>e.event==="raftkit_skill_invoked").slice(0,3).map(e=>e.props.journey_id)).size')"
expect_eq "  and is marked nested" "false,true,true" \
  "$(ev "$sp" 'E.filter(e=>e.event==="raftkit_skill_invoked").slice(0,3).map(e=>!e.props.journey_start).join(",")')"
expect_eq "a skill after the run's STOP starts a new journey" "true" \
  "$(ev "$sp" 'const s=E.filter(e=>e.event==="raftkit_skill_invoked"); s[3].props.journey_id !== s[0].props.journey_id && s[3].props.journey_start')"
expect_eq "a typed command always starts a new journey" "true" \
  "$(ev "$sp" 'const s=E.filter(e=>e.event==="raftkit_skill_invoked"); s[4].props.journey_id !== s[3].props.journey_id')"

# raftkit-core's own skills are loaded by runs; alone they never open one.
d="$(new_sandbox)"; sp="$d/spool/events.jsonl"
hook "$d" skill '{"session_id":"j2b","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-core:rules"}}'
hook "$d" skill '{"session_id":"j2b","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:implement"}}'
expect_eq "a raftkit-core skill never opens a run; the role skill after it does" "false|true|raftkit-dev:implement" \
  "$(ev "$sp" 'const s=E.filter(e=>e.event==="raftkit_skill_invoked"); s[0].props.journey_start+"|"+s[1].props.journey_start+"|"+s[1].props.journey_skill')"

# --- gates and blockers count only after a RaftKit skill ran in the session
d="$(new_sandbox)"; sp="$d/spool/events.jsonl"
hook "$d" stop '{"session_id":"j3","last_assistant_message":"**STOP** — approve to push, edit to change, or decline."}'
hook "$d" stop '{"session_id":"j3","last_assistant_message":"NOT READY — 2 gap(s):"}'
hook "$d" prompt '{"session_id":"j3","user_prompt":"go"}'
expect_eq "a STOP line in a session with no RaftKit skill is not a gate" "raftkit_turn_completed,raftkit_turn_completed" \
  "$(ev "$sp" 'E.filter(e=>e.event!=="raftkit_prompt_submitted").map(e=>e.event).join(",")')"
expect_eq "  so the next prompt is not a reply" "false" "$(ev "$sp" 'E.at(-1).props.after_gate')"
hook "$d" skill '{"session_id":"j3","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-pm:story"}}'
hook "$d" stop '{"session_id":"j3","last_assistant_message":"**STOP** — approve to write, edit to change, or decline."}'
expect_eq "  while the same line after a skill is one" "raftkit_gate_shown" "$(ev "$sp" 'E.at(-1).event')"

# --- the per-run token delta rides on the stop event
d="$(new_sandbox)"; tr="$d/t.jsonl"
mkmsg() { node -e 'process.stdout.write(JSON.stringify({type:"assistant",timestamp:new Date().toISOString(),message:{id:process.argv[1],model:"claude-opus-5-5",usage:{input_tokens:+process.argv[2],output_tokens:0,cache_read_input_tokens:0,cache_creation_input_tokens:0}}})+"\n")' "$1" "$2"; }
mkmsg a1 1000 > "$tr"
hook "$d" skill "{\"session_id\":\"j4\",\"transcript_path\":\"$tr\",\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"raftkit-dev:implement\"}}"
mkmsg a2 250 >> "$tr"
hook "$d" stop "{\"session_id\":\"j4\",\"transcript_path\":\"$tr\",\"last_assistant_message\":\"working\"}"
expect_eq "the stop event carries the run's tokens since its skill was invoked" "1250|250" \
  "$(ev "$d/spool/events.jsonl" 'const t=E.at(-1).props.tokens; t.total+"|"+t.run_total')"

# --- listing coverage from the transcript's skill_listing attachment
d="$(new_sandbox)"; tr="$d/t.jsonl"
node -e 'process.stdout.write(JSON.stringify({type:"attachment",timestamp:"2026-09-23T00:00:00Z",attachment:{type:"skill_listing",names:["raftkit-dev:implement","raftkit-dev:fix"],content:"- raftkit-dev:implement: Take one story\n- raftkit-dev:fix"}})+"\n")' > "$tr"
hook "$d" stop "{\"session_id\":\"j5\",\"transcript_path\":\"$tr\",\"last_assistant_message\":\"hi\"}"
expect_eq "the stop event reports how many RaftKit listings kept a description" "2|1" \
  "$(ev "$d/spool/events.jsonl" 'const l=E.at(-1).props.listing; l.raftkit+"|"+l.described.length')"

# --- tool_failed: exit code, and at most 200 chars after its header
d="$(new_sandbox)"; seed_skill "$d" j6
# Prose, not one long run: the scrubber would redact a 600-char run as base64
# and the length check would pass on the placeholder.
long="$(printf 'build step failed %.0s' $(seq 1 40))"
hook "$d" tool_failure "{\"session_id\":\"j6\",\"tool_name\":\"Bash\",\"error\":\"Exit code 2\\n$long\"}"
expect_eq "tool_failed carries the exit code" "2" "$(last_event_field "$d/spool/events.jsonl" props.exit_code)"
expect_eq "  and at most 200 chars of text, header excluded" "true" \
  "$(ev "$d/spool/events.jsonl" 'const e=E.at(-1).props.error; e.length<=200 && e.length>0 && !e.includes("Exit code")')"
hook "$d" tool_failure '{"session_id":"j6","tool_name":"Read","error":"File content exceeds maximum allowed tokens"}'
expect_eq "a failure with no exit code keeps its text" "File content exceeds maximum allowed tokens|undefined" \
  "$(ev "$d/spool/events.jsonl" 'E.at(-1).props.error+"|"+E.at(-1).props.exit_code')"

# --- commit and PR events come from registered hooks
node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const bash = (h.hooks.PostToolUse || []).filter((m) => m.matcher === "Bash").flatMap((m) => m.hooks || []);
  const wired = (mode, rule) => bash.some((e) => (e.args || []).at(-1) === mode && e.if === rule && e.async === true);
  process.exit(wired("commit", "Bash(git commit *)") && wired("pr", "Bash(gh pr create *)") ? 0 : 1);
'
check "commit and PR hooks are registered on Bash, filtered by if, async" ok $?
d="$(new_sandbox)"
hook "$d" commit '{"session_id":"j7","tool_name":"Bash","tool_input":{"command":"git add -A && git commit -m \"feat: x\""}}'
expect_eq "a git commit is recorded" "raftkit_commit_made" "$(last_event_field "$d/spool/events.jsonl" event)"
hook "$d" pr '{"session_id":"j7","tool_name":"Bash","tool_input":{"command":"gh pr create --fill"},"tool_response":{"stdout":"https://github.com/o/r/pull/42\n"}}'
expect_eq "a raised PR is recorded with its number" "raftkit_pr_raised|42" \
  "$(ev "$d/spool/events.jsonl" 'E.at(-1).event+"|"+E.at(-1).props.pr_number')"
d="$(new_sandbox)"
hook "$d" commit '{"session_id":"j8","tool_name":"Bash","tool_input":{"command":"git log --oneline"}}'
hook "$d" pr '{"session_id":"j8","tool_name":"Bash","tool_input":{"command":"gh pr view 3"}}'
expect_eq "a command that is not a commit or a PR records nothing" "no" "$([[ -f "$d/spool/events.jsonl" ]] && echo yes || echo no)"

# --- every installed raftkit-* plugin reports its version
d="$(new_sandbox)"
hook "$d" session_start '{"session_id":"j9","hook_event_name":"SessionStart"}'
expect_eq "events carry every raftkit-* plugin version" "$(node -p 'require("./plugins/raftkit-dev/.claude-plugin/plugin.json").version')" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.plugin_versions.raftkit-dev')"
# ...including from the plugin cache, where each plugin sits under its version.
cache="$(new_sandbox)"; mk="$cache/plugins/cache/raftkit"
mkdir -p "$mk/raftkit-core/7.0.0" "$mk/raftkit-dev/7.1.0/.claude-plugin" "$mk/raftkit-dev/7.1.0/skills/implement" "$mk/raftkit-dev/0.1.0/.claude-plugin"
cp -R plugins/raftkit-core/. "$mk/raftkit-core/7.0.0/"
echo '{"name":"raftkit-dev","version":"7.1.0"}' > "$mk/raftkit-dev/7.1.0/.claude-plugin/plugin.json"
echo '{"name":"raftkit-dev","version":"0.1.0"}' > "$mk/raftkit-dev/0.1.0/.claude-plugin/plugin.json"
echo 'cached implement skill' > "$mk/raftkit-dev/7.1.0/skills/implement/SKILL.md"
printf '{"version":2,"plugins":{"raftkit-dev@raftkit":[{"scope":"user","installPath":"%s","version":"7.1.0"}]}}' "$mk/raftkit-dev/7.1.0" \
  > "$cache/plugins/installed_plugins.json"
d="$(new_sandbox)"
printf '{"session_id":"j10","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"raftkit-dev:implement"}}' \
  | CLAUDE_CONFIG_DIR="$cache" RAFTKIT_TELEMETRY_DIR="$d" node "$mk/raftkit-core/7.0.0/hooks/record.mjs" skill >/dev/null 2>&1
expect_eq "from the plugin cache, the installed version of each plugin is reported" "7.1.0" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.plugin_versions.raftkit-dev')"
expect_eq "  and the skill's sha12 is read from that version" "$(printf 'cached implement skill\n' | shasum -a 256 | cut -c1-12)" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.skill_sha12')"

# ================================================================ 14. entry map
# A plain-language request must reach RaftKit even when the skill listing has
# dropped RaftKit's descriptions. SessionStart puts a short map into context.
# It is not telemetry: the opt-out does not silence it.
MAP="$PWD/plugins/raftkit-core/hooks/entry-map.mjs"
map_ctx() { # <cwd> [env...] — the additionalContext the hook prints, or its raw output
  local cwd="$1"; shift
  printf '{"session_id":"m1","hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$cwd" \
    | env "$@" node "$MAP" 2>/dev/null \
    | node -e 'let s="";process.stdin.on("data",(c)=>s+=c).on("end",()=>{ if(!s) return; try { const j=JSON.parse(s); process.stdout.write(j.hookSpecificOutput?.hookEventName==="SessionStart" ? String(j.hookSpecificOutput.additionalContext) : "BAD:"+s); } catch { process.stdout.write("BAD:"+s); } })'
}
node -e '
  const h = JSON.parse(require("fs").readFileSync("plugins/raftkit-core/hooks/hooks.json", "utf8"));
  const e = (h.hooks.SessionStart || []).flatMap((m) => m.hooks || []).find((x) => (x.args || []).some((a) => /entry-map\.mjs$/.test(a)));
  process.exit(e && !e.async ? 0 : 1);
'
check "the entry map is a synchronous SessionStart hook, so its output is read" ok $?

bare="$(new_sandbox)"; git -C "$bare" init -q 2>/dev/null
ctx="$(map_ctx "$bare")"
for want in "story URL → raftkit-dev:implement" "raftkit-dev:fix (it runs systematic-debugging itself)" "→ raftkit-dev:setup" "scope audit → raftkit-dev:scope-guard"; do
  [[ "$ctx" == *"$want"* ]]; check "the entry map routes: $want" ok $?
done
[[ "$ctx" == *"RaftKit is not set up in this repo — run raftkit-dev:setup"* ]]
check "a repo without setup's marker gets the not-set-up line" ok $?
words="$(printf '%s' "$ctx" | wc -w | tr -d ' ')"
[[ "$words" -ge 20 && "$words" -le 60 ]]
check "the entry map, not-set-up line included, is at most 60 words ($words)" ok $?
for var in "RAFTKIT_TELEMETRY=off" "DO_NOT_TRACK=1"; do
  [[ "$(map_ctx "$bare" "$var")" == "$ctx" ]]
  check "the entry map still prints with $var" ok $?
done
setup_done="$(new_sandbox)"; git -C "$setup_done" init -q 2>/dev/null; mkdir -p "$setup_done/.raftkit" "$setup_done/src"
echo '{}' > "$setup_done/.raftkit/governance-pack.json"
ctx2="$(map_ctx "$setup_done/src")"
[[ "$ctx2" == *"raftkit-dev:implement"* && "$ctx2" != *"not set up"* ]]
check "a repo with setup's marker (checked at the git root) gets the map alone" ok $?
not_git="$(new_sandbox)"
ctx3="$(map_ctx "$not_git")"
[[ "$ctx3" == *"raftkit-dev:implement"* && "$ctx3" != *"not set up"* ]]
check "outside a git repo there is no not-set-up line" ok $?
# The map names raftkit-dev's skills, so without raftkit-dev it says nothing.
alone="$(new_sandbox)"; mkdir -p "$alone/plugins"; cp -R plugins/raftkit-core "$alone/plugins/"
out="$(printf '{"cwd":"%s"}' "$bare" | node "$alone/plugins/raftkit-core/hooks/entry-map.mjs" 2>/dev/null)"
expect_eq "without raftkit-dev installed the entry map prints nothing" "" "$out"
d="$(new_sandbox)"; rmdir "$d"
map_ctx "$bare" RAFTKIT_TELEMETRY_DIR="$d" >/dev/null
expect_eq "the entry map writes nothing" "no" "$([[ -e "$d" ]] && echo yes || echo no)"
echo 'not json {{' | node "$MAP" >/dev/null 2>&1
check "the entry map exits 0 on malformed input" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
