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
#   9. the governance docs match the shipped behaviour, the one-time disclosure
#      actually renders, and the manifests stay in version/description lockstep
set -uo pipefail
cd "$(dirname "$0")/.."

HOOKS="plugins/raftkit-core/hooks"
RECORD="$HOOKS/record.mjs"
FLUSH="$HOOKS/flush.mjs"
BLOCKER="$HOOKS/blocker.mjs"
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
d="$(new_sandbox)"
printf '{"session_id":"s1","last_assistant_message":"NOT READY — 2 gap(s):\\n- Section 3 missing"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "hard stop is classified as blocked" "raftkit_blocked" "$(last_event_field "$d/spool/events.jsonl" 'event')"
expect_eq "correct refusal id" "gate0-not-ready" "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"

# The capability-unavailable pattern has no leading `^` anchor precisely so a
# refusal Claude renders with a bold label (`**Missing:**` instead of plain
# `Missing:`) still classifies — an anchored pattern regressed this once.
d="$(new_sandbox)"
printf '{"session_id":"s1","last_assistant_message":"**Missing:** superpowers. Install it with: claude plugin install superpowers@claude-plugins-official"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" stop >/dev/null 2>&1
expect_eq "bold-prefixed capability refusal still classifies" "capability-unavailable" \
  "$(last_event_field "$d/spool/events.jsonl" 'props.refusal_id')"

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

# -------------------------------------------- 9. governance docs + disclosure
# Auto-filing and full-prompt capture are deliberate, so the governance docs are
# the only thing standing between them and a surprised developer. These assert
# the docs describe what the code above actually does — no more, no less.
HOUSE_RULES="plugins/raftkit-core/skills/house-rules/SKILL.md"
WRITE_PROTOCOL="plugins/raftkit-core/skills/write-protocol/SKILL.md"

carveout="$(awk '/^\*\*The auto-file carve-out/,/^## find-skills/' "$HOUSE_RULES")"
grep -qiE 'creates?\b' <<<"$carveout" \
  && grep -qiE 'comments?\b' <<<"$carveout" \
  && grep -qiE 'reopens?\b' <<<"$carveout"
check "carve-out names all three automatic writes (create, comment, reopen)" ok $?

# The reopen overrides a human's triage decision, so it must be named, not implied.
grep -qiE 'reopens?\b' <<<"$carveout"
check "carve-out names the reopen specifically" ok $?

grep -qi 'every prompt' "$HOUSE_RULES" && grep -qi 'failed tool call' "$HOUSE_RULES"
check "house-rules states every prompt and every failed tool call is captured" ok $?

grep -q 'RAFTKIT_TELEMETRY=off' "$HOUSE_RULES" && grep -q 'RAFTKIT_TELEMETRY=off' "$WRITE_PROTOCOL"
check "opt-out is stated in house-rules AND write-protocol, not just the README" ok $?

gates="$(grep -m1 'No skill ever auto-sends' CLAUDE.md)"
grep -qi 'exception' <<<"$gates" \
  && grep -qi 'telemetry hooks' <<<"$gates" \
  && grep -qi 'client repo' <<<"$gates"
check "CLAUDE.md's non-negotiable names the hook-layer auto-file exception" ok $?

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
  for _ in 1 2 3 4 5 6 7 8 9 10; do
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

# --- F1: the public issue must never carry the raw prompt -------------------
# This repo is PUBLIC. A hard stop inside a client repo was publishing that
# client's prompt to a search-indexed page under the developer's own identity.
# Analytics are unaffected — the endpoint still receives the full prompt — so
# the issue carries a correlation id to look it up by instead.
d="$(new_sandbox)"; make_fake_gh "$d" empty
LEAK_EVENT='{"ts":"2026-08-03T09:00:00Z","event_id":"evt-corr-9911","event":"raftkit_blocked","distinct_id":"x@y.z","props":{"refusal_id":"gate0-not-ready","skill":"story-readiness","severity":"blocker","matched_line":"NOT READY — 2 gap(s):","session_id":"sess-corr-4422","repo":"sha256:abc","branch_kind":"feat","prompt":"migrate ACMEBANK trade-settlement ledger to the new schema","plugin_versions":{"raftkit-core":"0.10.0"},"os":"darwin"}}'
echo "$LEAK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
if grep -q 'ACMEBANK trade-settlement' "$d/gh.log" 2>/dev/null; then
  echo "FAIL: the raw prompt was published into the GitHub issue body"
  failures=$((failures + 1))
else
  echo "PASS: issue body carries no raw prompt"
fi
if grep -q 'evt-corr-9911' "$d/gh.log" 2>/dev/null; then
  echo "PASS: issue body carries the telemetry correlation id instead"
else
  echo "FAIL: issue body has no correlation id to look the context up by"
  failures=$((failures + 1))
fi
if grep -q 'sess-corr-4422' "$d/gh.log" 2>/dev/null; then
  echo "PASS: issue body carries the session id"
else
  echo "FAIL: issue body is missing the session id"
  failures=$((failures + 1))
fi
# Triage still needs the non-sensitive context, so prove it survived the cut.
if grep -q 'NOT READY' "$d/gh.log" && grep -q 'gate0-not-ready' "$d/gh.log" \
   && grep -q 'sha256:abc' "$d/gh.log" && grep -q 'raftkit-core@0.10.0' "$d/gh.log"; then
  echo "PASS: issue retains refusal, skill, hashed repo and versions for triage"
else
  echo "FAIL: issue lost triage context it should have kept"
  failures=$((failures + 1))
fi

# --- F2 end-to-end: an auth header in a real prompt must not reach the spool -
d="$(new_sandbox)"
echo '{"session_id":"s1","user_prompt":"why does curl -H \"Authorization: Bearer ghs_LIVETOKEN99887766554433\" 401","cwd":"'"$PWD"'"}' \
  | RAFTKIT_TELEMETRY_DIR="$d" node "$RECORD" prompt >/dev/null 2>&1
captured="$(last_event_field "$d/spool/events.jsonl" 'props.prompt')"
if [[ "$captured" == *"ghs_LIVETOKEN"* ]]; then
  echo "FAIL: Authorization header token reached the spool ('$captured')"
  failures=$((failures + 1))
else
  echo "PASS: Authorization header token never reaches the spool"
fi

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
# .claude/settings.json ships an `env` block and is checked into repos, so these
# three are only honoured under an explicit RAFTKIT_DEV=1.
node -e '
  const { execFileSync } = require("child_process");
  const read = (env) => JSON.parse(execFileSync(process.execPath, ["--input-type=module", "-e",
    "import { config } from \"./plugins/raftkit-core/hooks/lib/common.mjs\"; process.stdout.write(JSON.stringify(config()));"
  ], { encoding: "utf8", env: { ...process.env, ...env } }));
  const clear = { RAFTKIT_DEV: undefined, RAFTKIT_TELEMETRY_ENDPOINT: undefined,
                  RAFTKIT_ISSUE_REPO: undefined, RAFTKIT_FILE_ISSUES: undefined };
  let bad = 0;
  // Hostile project env, no opt-in: ignored.
  const hostile = read({ ...clear, RAFTKIT_TELEMETRY_ENDPOINT: "https://evil.example/collect",
                                   RAFTKIT_ISSUE_REPO: "attacker/evil" });
  if (hostile.endpoint === "https://evil.example/collect") { console.error("  endpoint hijacked without RAFTKIT_DEV"); bad++; }
  if (hostile.issue_repo !== "Raft-Labs/raftkit") { console.error("  issue_repo hijacked without RAFTKIT_DEV: " + hostile.issue_repo); bad++; }
  // Opted in, but the repo allowlist still holds.
  const dev = read({ ...clear, RAFTKIT_DEV: "1", RAFTKIT_ISSUE_REPO: "attacker/evil" });
  if (dev.issue_repo !== "Raft-Labs/raftkit") { console.error("  non-RaftLabs issue_repo accepted under RAFTKIT_DEV: " + dev.issue_repo); bad++; }
  // A RaftLabs repo is still overridable under the opt-in.
  const ok = read({ ...clear, RAFTKIT_DEV: "1", RAFTKIT_ISSUE_REPO: "Raft-Labs/scratch" });
  if (ok.issue_repo !== "Raft-Labs/scratch") { console.error("  RAFTKIT_DEV override stopped working: " + ok.issue_repo); bad++; }
  const ep = read({ ...clear, RAFTKIT_DEV: "1", RAFTKIT_TELEMETRY_ENDPOINT: "https://stub.example/x" });
  if (ep.endpoint !== "https://stub.example/x") { console.error("  RAFTKIT_DEV endpoint override stopped working"); bad++; }
  process.exit(bad === 0 ? 0 : 1);
' >/dev/null 2>&1
check "project env cannot redirect telemetry or issue filing without RAFTKIT_DEV" ok $?

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

# --- F7: the no-session storm bucket must reset ------------------------------
# It never did: three lifetime occurrences permanently disabled filing for every
# event that arrived without a session id.
d="$(new_sandbox)"; make_fake_gh "$d" empty
printf '{"no-session":99}' > "$d/issue-counts.json"
printf '{"ts":"t","event_id":"e1","event":"raftkit_blocked","props":{"refusal_id":"rz","skill":"sz","severity":"blocker","matched_line":"Can'"'"'t do the thing — reason"}}' \
  | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
expect_eq "an exhausted lifetime no-session bucket does not block filing forever" "1" "$(count_gh "$d/gh.log" 'issue create')"

# --- F8: a dedup search that did not run proves nothing ---------------------
# safeExec returns "" on a non-zero exit, which parsed to [] — "nothing found" —
# so a rate limit or a network blip filed a duplicate.
d="$(new_sandbox)"; mkdir -p "$d/bin"
cat > "$d/bin/gh" <<'GHSTUB'
#!/usr/bin/env bash
echo "GH: $*" >> "GHLOG"
if [ "$1" = "auth" ]; then exit 0; fi
if [ "$1" = "issue" ] && [ "$2" = "list" ]; then exit 1; fi   # rate limited
exit 0
GHSTUB
sed -i.bak "s|GHLOG|$d/gh.log|" "$d/bin/gh"; chmod +x "$d/bin/gh"
echo "$BLOCK_EVENT" | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
expect_eq "a failed dedup search files nothing rather than a duplicate" "0" "$(count_gh "$d/gh.log" 'issue create')"

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

# --- F12: the storm counter must not be trimmed out by other sessions -------
# The .slice(-20) trim kept INSERTION order, so a long session's own counter was
# evicted by newer sessions and its cap silently reset.
d="$(new_sandbox)"; make_fake_gh "$d" empty
node -e '
  const fs = require("fs");
  // "mine" first, then 25 newer sessions — the exact shape that evicted it.
  const counts = { mine: 0 };
  for (let i = 0; i < 25; i++) counts["other-" + i] = 1;
  fs.writeFileSync(process.argv[1] + "/issue-counts.json", JSON.stringify(counts));
' "$d"
for i in 1 2 3 4 5; do
  printf '{"ts":"t","event_id":"e%s","event":"raftkit_blocked","props":{"refusal_id":"r%s","skill":"s%s","severity":"blocker","matched_line":"Can'"'"'t do thing %s — reason","session_id":"mine"}}' "$i" "$i" "$i" "$i" \
    | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$BLOCKER" >/dev/null 2>&1
done
expect_eq "the storm cap holds even when many other sessions are on the books" "3" "$(count_gh "$d/gh.log" 'issue create')"

# --- F13: the detached blocker must receive the whole event -----------------
# record.mjs wrote to the child's stdin and exited immediately; anything past
# the 64KB pipe buffer was still in flight and the child got truncated JSON.
d="$(new_sandbox)"; make_fake_gh "$d" empty
printf '{"session_id":"s-handoff","last_assistant_message":"NOT READY — 2 gap(s):\\n- Section 3 missing"}' \
  | PATH="$d/bin:$PATH" RAFTKIT_TELEMETRY_DIR="$d" RAFTKIT_FILE_ISSUES=true node "$RECORD" stop >/dev/null 2>&1
check "record.mjs exits 0 after handing the event to the detached blocker" ok $?
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -f "$d/gh.log" ]] && break
  sleep 0.3
done
expect_eq "the blocker received a complete, parseable event and acted on it" "1" "$(count_gh "$d/gh.log" 'issue create')"

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

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
