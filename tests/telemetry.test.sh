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
#   8. issue filing dedups by fingerprint and honours the storm guard
set -uo pipefail
cd "$(dirname "$0")/.."

HOOKS="plugins/raftkit-core/hooks"
RECORD="$HOOKS/record.mjs"
FLUSH="$HOOKS/flush.mjs"
BLOCKER="$HOOKS/blocker.mjs"

failures=0
tmpdirs=()
cleanup() {
  # Stub servers first — their PID file lives inside one of the tmpdirs.
  for d in "${tmpdirs[@]:-}"; do
    [[ -n "$d" && -f "$d/pids" ]] && while read -r pid; do
      [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    done < "$d/pids"
  done
  for d in "${tmpdirs[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done
}
trap cleanup EXIT

# Make the suite hermetic.
#
# identity() shells out to `gh api user` on every cold cache, and each test runs
# in a fresh sandbox, so an unauthenticated or slow `gh` — which is exactly what
# CI has — turns 22 identity resolutions into 22 network timeouts and blows the
# job's time budget. Tests must not touch the network.
#
# Individual tests that care about `gh` behaviour prepend their own stub, which
# takes precedence over this one.
STUB_BIN="$(mktemp -d)"
tmpdirs+=("$STUB_BIN")
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

# Never let the suite reach the real telemetry endpoint.
#
# The shipped config now points at production, so any test that runs flush.mjs
# without an explicit override would POST real events into the live database.
# Default to "send nowhere"; the flush tests set their own stub-server URL.
export RAFTKIT_TELEMETRY_ENDPOINT=""
# Same reasoning for issue filing — the shipped default is now `true`.
export RAFTKIT_FILE_ISSUES=false

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

new_sandbox() { # echoes a fresh telemetry dir
  local d
  d="$(mktemp -d)"
  tmpdirs+=("$d")
  echo "$d"
}

# A fake `gh` that records its arguments instead of touching GitHub.
# $1 = dir, $2 = "empty" | "existing" (what `issue list` returns)
make_fake_gh() {
  local dir="$1" mode="$2"
  mkdir -p "$dir/bin"
  {
    echo '#!/usr/bin/env bash'
    echo "echo \"GH: \$*\" >> \"$dir/gh.log\""
    echo 'if [ "$1" = "issue" ] && [ "$2" = "list" ]; then'
    if [[ "$mode" == "existing" ]]; then
      echo '  echo "[{\"number\":42,\"state\":\"OPEN\"}]"'
    else
      echo '  echo "[]"'
    fi
    echo 'fi'
    echo 'exit 0'
  } > "$dir/bin/gh"
  chmod +x "$dir/bin/gh"
}

# `grep -c` prints 0 AND exits 1 on no match, so a naive `|| echo 0` yields "0\n0".
count_gh() { # <log> <pattern>
  [[ -f "$1" ]] || { echo 0; return; }
  grep -c "$2" "$1" 2>/dev/null || true
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
if [[ "$repo_val" == sha256:* && "$repo_val" != *raftkit* ]]; then
  echo "PASS: repo identity is hashed, never the repo name"
else
  echo "FAIL: repo identity leaked or malformed ('$repo_val')"
  failures=$((failures + 1))
fi
branch_val="$(last_event_field "$d/spool/events.jsonl" 'props.branch_kind')"
if [[ "$branch_val" != *telemetry* ]]; then
  echo "PASS: only the branch prefix is captured"
else
  echo "FAIL: full branch name leaked ('$branch_val')"
  failures=$((failures + 1))
fi

# ------------------------------------------------------------- 2. scrubbing
d="$(new_sandbox)"
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
node -e '
  import("./plugins/raftkit-core/hooks/lib/scrub.mjs").then(({ scrub }) => {
    const cases = [
      ["ghp_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHH1234", "github token"],
      ["AKIAIOSFODNN7EXAMPLE", "aws key id"],
      ["xoxb-1234567890-abcdefghij", "slack token"],
      ["-----BEGIN RSA PRIVATE KEY-----\nabc\n-----END RSA PRIVATE KEY-----", "pem block"],
      ["password: hunter2supersecret", "password assignment"],
      ["Authorization: Bearer abcdefghijklmnopqrstuvwxyz", "auth header"],
      ["https://user:pa55word@example.com/x", "url credentials"],
    ];
    let bad = 0;
    for (const [input, label] of cases) {
      const out = scrub(input);
      if (!out.includes("REDACTED")) { console.error("  unscrubbed: " + label); bad++; }
    }
    const clean = "please run the tests and fix the failing case";
    if (scrub(clean) !== clean) { console.error("  clean text was altered"); bad++; }
    process.exit(bad === 0 ? 0 : 1);
  }).catch(() => process.exit(1));
' >/dev/null 2>&1
check "scrubber removes every credential class, leaves clean text alone" ok $?

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
echo '{"session_id":"x"}' | RAFTKIT_TELEMETRY_DIR=/proc/nonexistent/nope node "$RECORD" stop >/dev/null 2>&1
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
d="$(new_sandbox)"
printf '{"session_id":"s1","last_assistant_message":"NOT READY — 2 gap(s):\\n- Section 3 missing"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "hard stop is classified as blocked" "raftkit_blocked" "$(last_event_field "$d/spool/events.jsonl" 'event')"
expect_eq "correct refusal id" "gate0-not-ready" "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"

d="$(new_sandbox)"
printf '{"session_id":"s1","last_assistant_message":"Done — all tests pass and the PR is up."}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "a normal turn is not a blocker" "raftkit_turn_completed" "$(last_event_field "$d/spool/events.jsonl" 'event')"

# The Stop hook carries no prompt, so it must recover the session's last one.
d="$(new_sandbox)"
echo "{\"session_id\":\"s9\",\"user_prompt\":\"implement story 123\",\"cwd\":\"$PWD\"}" \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
printf '{"session_id":"s9","last_assistant_message":"Can'"'"'t read the story — check your Asana connector, then retry."}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "blocker correlates the session's prompt" "implement story 123" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.prompt')"

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
STUB

start_stub() { # <code> -> echoes port
  # The PID is written to a file rather than tracked as a shell job: this
  # function is called inside a command substitution, so the background process
  # belongs to that subshell and `jobs -p` in the EXIT trap cannot see it.
  # Without this the stub servers survive the run and pile up across invocations.
  node "$stub/stub.mjs" "$1" > "$stub/port.$1" 2>/dev/null &
  echo $! >> "$stub/pids"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
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

# ---------------------------------------------------------- 8. issue filing
BLOCK_EVENT='{"ts":"2026-08-03T09:00:00Z","event":"raftkit_blocked","distinct_id":"x@y.z","props":{"refusal_id":"gate0-not-ready","skill":"story-readiness","severity":"blocker","matched_line":"NOT READY — 2 gap(s):","session_id":"s1","repo":"sha256:abc","branch_kind":"feat","prompt":"implement","plugin_versions":{"raftkit-core":"0.7.0"},"os":"darwin"}}'

# Default posture: observe-only, no filing.
# The kill switch for filing, set explicitly rather than read from the shipped
# config — this must keep testing the behaviour after the default flips.
d="$(new_sandbox)"; make_fake_gh "$d" empty
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=false \
  node "$BLOCKER" >/dev/null 2>&1
if [[ ! -f "$d/gh.log" ]]; then
  echo "PASS: file_issues=false files nothing"
else
  echo "FAIL: filed an issue while file_issues was false"
  failures=$((failures + 1))
fi

# Telemetry opt-out must also stop filing, independently of file_issues.
d="$(new_sandbox)"; make_fake_gh "$d" empty
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_TELEMETRY=off \
  node "$BLOCKER" >/dev/null 2>&1
if [[ ! -f "$d/gh.log" ]]; then
  echo "PASS: RAFTKIT_TELEMETRY=off files nothing even with filing enabled"
else
  echo "FAIL: filed an issue while telemetry was opted out"
  failures=$((failures + 1))
fi

d="$(new_sandbox)"; make_fake_gh "$d" empty
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true \
  RAFTKIT_ISSUE_REPO="scratch/repo" node "$BLOCKER" >/dev/null 2>&1
expect_eq "unseen blocker creates one issue" "1" "$(count_gh "$d/gh.log" 'issue create')"

d="$(new_sandbox)"; make_fake_gh "$d" existing
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true \
  RAFTKIT_ISSUE_REPO="scratch/repo" node "$BLOCKER" >/dev/null 2>&1
expect_eq "known blocker creates no duplicate" "0" "$(count_gh "$d/gh.log" 'issue create')"
expect_eq "known blocker comments instead" "1" "$(count_gh "$d/gh.log" 'issue comment')"

# Volatile numbers must not fork the fingerprint, or dedup silently stops working.
d="$(new_sandbox)"; make_fake_gh "$d" empty
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
fp_a="$(grep -o 'raftkit-fingerprint: [a-f0-9]*' "$d/gh.log" | head -1)"
d2="$(new_sandbox)"; make_fake_gh "$d2" empty
echo "${BLOCK_EVENT/2 gap/9 gap}" | PATH="$d2/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d2" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
fp_b="$(grep -o 'raftkit-fingerprint: [a-f0-9]*' "$d2/gh.log" | head -1)"
expect_eq "fingerprint ignores volatile counts" "$fp_a" "$fp_b"

# Storm guard.
d="$(new_sandbox)"; make_fake_gh "$d" empty
for i in 1 2 3 4 5; do
  printf '{"ts":"t","event":"raftkit_blocked","props":{"refusal_id":"r%s","skill":"s%s","severity":"blocker","matched_line":"Can'"'"'t do thing %s — reason","session_id":"one-session"}}' "$i" "$i" "$i" \
    | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
done
expect_eq "storm guard caps issues per session at 3" "3" "$(count_gh "$d/gh.log" 'issue create')"

# info-severity stops are noise, not defects.
d="$(new_sandbox)"; make_fake_gh "$d" empty
printf '{"event":"raftkit_blocked","props":{"refusal_id":"pr-nothing-to-raise","skill":"pr","severity":"info","matched_line":"nothing to raise — no commits","session_id":"i"}}' \
  | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
if [[ ! -f "$d/gh.log" ]]; then
  echo "PASS: info-severity stops are never filed"
else
  echo "FAIL: filed an issue for an info-severity stop"
  failures=$((failures + 1))
fi

# Unauthenticated gh must degrade silently, not crash the hook.
d="$(new_sandbox)"
mkdir -p "$d/bin"; printf '#!/usr/bin/env bash\nexit 1\n' > "$d/bin/gh"; chmod +x "$d/bin/gh"
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
check "unauthenticated gh exits 0 without filing" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
