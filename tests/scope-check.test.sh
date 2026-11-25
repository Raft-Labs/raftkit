#!/usr/bin/env bash
# Contract suite for plugins/raftkit-dev/scripts/scope-check.mjs, the
# deterministic scope pre-filter (not the gate). Each case builds a throwaway
# git history around the fixture plan record in tests/fixtures/scope-check/ and
# checks one flag: an unplanned file (BEYOND candidate), an [AC] with no test
# in the diff (MISSING), a table row added after the plan hash (ADDED AFTER
# PLAN), and a test commit that does not precede its implementation (ORDER).
# The plan record itself is always in scope. Exit 0 clean, 1 flags, 2 not run.
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
cd "$(dirname "$0")/.." || exit 2
ROOT="$PWD"
SC="$ROOT/plugins/raftkit-dev/scripts/scope-check.mjs"
FIX="$ROOT/tests/fixtures/scope-check"

failures=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
expect_eq() { # <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "PASS: $1"; else
    echo "FAIL: $1"; printf '  expected: %s\n' "$2"; printf '  actual:   %s\n' "$3"; failures=$((failures + 1)); fi
}

# Isolated git: the developer's config, hooks and templates are never read.
: > "$TEST_ROOT/gitconfig"
g() { HOME="$TEST_ROOT" XDG_CONFIG_HOME="$TEST_ROOT/xdg" GIT_CONFIG_GLOBAL="$TEST_ROOT/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
  git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
REC=docs/specs/feat/42-badge.md

# The table hash, computed here independently of the script: the table's data
# rows, each trimmed, joined by newlines, sha256 hex.
table_hash() { node -e '
  const L = require("fs").readFileSync(0, "utf8").split("\n");
  const h = L.findIndex((l) => l.trim().startsWith("|") && (l.includes("[AC]") || l.includes("Done when")));
  const rows = [];
  for (let i = h + 2; i < L.length && L[i].trim().startsWith("|"); i++) rows.push(L[i].trim());
  process.stdout.write(require("crypto").createHash("sha256").update(rows.join("\n")).digest("hex"));
'; }
# render [extra-row-file] [rehash]: the fixture record, hashed; an extra row is
# appended to the table after hashing, or before it when rehash is given.
render() {
  local body extra="${1:-}" rehash="${2:-}"
  body="$(cat "$FIX/${RECFIX:-record.md}")"
  [[ -n "$extra" ]] && body="$(awk -v row="$(cat "$extra")" '{print} /^\| 2 \|/{print row}' <<<"$body")"
  local hashed="$body"
  [[ -n "$extra" && -z "$rehash" ]] && hashed="$(cat "$FIX/record.md")"
  mkdir -p "$R/$(dirname "$REC")"
  printf '%s\n' "${body//\{\{HASH\}\}/$(table_hash <<<"$hashed")}" > "$R/$REC"
}
touchf() { local f; for f in "$@"; do mkdir -p "$R/$(dirname "$f")"; echo "$RANDOM" >> "$R/$f"; done; }
cm() { local msg="$1"; shift; touchf "$@"; g add -A >/dev/null; g commit -qm "$msg"; }
newrepo() {
  R="$(mktemp -d "$TEST_ROOT/repo.XXXX")"
  g init -q -b main; touchf README.md; g add -A; g commit -qm init
  BASE="$(g rev-parse HEAD)"
  g checkout -qb feat/42-badge
  render; g add -A; g commit -qm "docs: plan record"
}
good_build() {
  cm "test: badge" src/badge.test.ts; cm "feat: badge" src/badge.ts
  cm "test: guest" src/guest.test.ts; cm "feat: guest" src/guest.ts src/shared/util.ts
}
sc() { (cd "$R" && node "$SC" "$@" 2>&1); echo "exit $?"; }

# A · a red-first build of every planned file, record included, is clean
newrepo; good_build
expect_eq "a red-first build of the plan is clean, the plan record included" \
  "scope-check: clean — 0 flags
exit 0" "$(sc --base "$BASE")"

# B · a changed file no row plans, committed or not, is a BEYOND candidate
newrepo; good_build; cm "feat: extra" src/extra.ts; touchf notes/scratch.md
expect_eq "an unplanned file is a BEYOND candidate, uncommitted ones included" \
  "scope-check: 2 flag(s)
BEYOND candidate: notes/scratch.md
BEYOND candidate: src/extra.ts
exit 1" "$(sc --base "$BASE")"

# C · an [AC] whose test file is not in the diff is MISSING
newrepo; cm "test: badge" src/badge.test.ts; cm "feat: badge" src/badge.ts
expect_eq "an [AC] with no test file in the diff is MISSING" \
  "scope-check: 1 flag(s)
MISSING: [AC] A guest sees no badge — no test file in the diff (src/guest.test.ts)
exit 1" "$(sc --base "$BASE")"

# D · a row added after the plan was hashed is flagged even when the hash line
#     is rewritten to match: the plan is the table as first committed, so its
#     files stay BEYOND candidates
newrepo; good_build
render "$FIX/added-row.md" rehash; g add -A; g commit -qm "docs: widen plan"
cm "test: admin" src/admin.test.ts; cm "feat: admin" src/admin.ts
expect_eq "a row added after the plan hash is flagged, rehash or not" \
  "scope-check: 3 flag(s)
BEYOND candidate: src/admin.test.ts
BEYOND candidate: src/admin.ts
ADDED AFTER PLAN: [AC] Admins see every badge
exit 1" "$(sc --base "$BASE")"

# L · widening a row's source files after the plan does not plan the file
newrepo; good_build
perl -pi -e 's/`src\/badge.ts` \|$/`src\/badge.ts`, `src\/extra.ts` |/' "$R/$REC"
g add -A; g commit -qm "docs: widen row"; cm "feat: extra" src/extra.ts
expect_eq "a row widened after the plan is flagged and its new file stays a BEYOND candidate" \
  "scope-check: 2 flag(s)
BEYOND candidate: src/extra.ts
ADDED AFTER PLAN: changed — [AC] A member sees their tier badge
exit 1" "$(sc --base "$BASE")"

# M · deleting a row after the plan does not clear its MISSING flag
newrepo; cm "test: badge" src/badge.test.ts; cm "feat: badge" src/badge.ts
perl -ni -e 'print unless /^\| 2 \|/' "$R/$REC"; g add -A; g commit -qm "docs: drop row"
expect_eq "a row deleted after the plan is flagged and stays MISSING" \
  "scope-check: 2 flag(s)
MISSING: [AC] A guest sees no badge — no test file in the diff (src/guest.test.ts)
ADDED AFTER PLAN: removed — [AC] A guest sees no badge
exit 1" "$(sc --base "$BASE")"

# N · rows sharing one test file: the test commit is found by its subject
RECFIX=shared-test.md newrepo
cm "test: [AC] One" src/checkout.test.ts; cm "feat: one" src/one.ts
cm "test: [AC] Two" src/checkout.test.ts src/two.ts
expect_eq "a shared test file committed with the second row's code is an ORDER flag" \
  "scope-check: 1 flag(s)
ORDER: [AC] Two — its test and implementation share a commit
exit 1" "$(sc --base "$BASE")"

# O · rows sharing one test file whose test commit no subject names: reported, never a silent pass
RECFIX=shared-test.md newrepo
cm "add checkout tests" src/checkout.test.ts; cm "feat: one" src/one.ts; cm "feat: two" src/two.ts
expect_eq "an unattributable shared test file is reported as not checked" \
  "scope-check: clean — 0 flags
ORDER not checked: [AC] One — shared test file
ORDER not checked: [AC] Two — shared test file
exit 0" "$(sc --base "$BASE")"

# E · a table that already differs from its hash when first committed
R="$(mktemp -d "$TEST_ROOT/repo.XXXX")"
g init -q -b main; touchf README.md; g add -A; g commit -qm init; BASE="$(g rev-parse HEAD)"
g checkout -qb feat/42-badge; render "$FIX/added-row.md"; g add -A; g commit -qm "docs: plan record"
good_build; cm "test: admin" src/admin.test.ts; cm "feat: admin" src/admin.ts
expect_eq "a table changed between hashing and its first commit is flagged" \
  "scope-check: 1 flag(s)
ADDED AFTER PLAN: the table does not match the hash recorded when it was planned
exit 1" "$(sc --base "$BASE")"

# F · implementation committed before its test
newrepo; cm "feat: badge" src/badge.ts; cm "test: badge" src/badge.test.ts
cm "test: guest" src/guest.test.ts; cm "feat: guest" src/guest.ts
expect_eq "an implementation committed before its test is an ORDER flag" \
  "scope-check: 1 flag(s)
ORDER: [AC] A member sees their tier badge — its implementation was committed before its test
exit 1" "$(sc --base "$BASE")"

# G · test and implementation in one commit is not red-first
newrepo; cm "feat: badge with test" src/badge.test.ts src/badge.ts
cm "test: guest" src/guest.test.ts; cm "feat: guest" src/guest.ts
expect_eq "a test committed with its implementation is an ORDER flag" \
  "scope-check: 1 flag(s)
ORDER: [AC] A member sees their tier badge — its test and implementation share a commit
exit 1" "$(sc --base "$BASE")"

# H · a test with no implementation after it, where the row plans source
newrepo; cm "test: badge" src/badge.test.ts; cm "feat: badge" src/badge.ts; cm "test: guest" src/guest.test.ts
expect_eq "a planned implementation that never follows its test is an ORDER flag" \
  "scope-check: 1 flag(s)
ORDER: [AC] A guest sees no badge — no implementation commit after its test
exit 1" "$(sc --base "$BASE")"

# I · --hash prints the table hash the record must carry
newrepo
expect_eq "--hash prints the plan-table hash" \
  "plan-table sha256: $(table_hash < "$FIX/record.md")
exit 0" "$(sc --hash)"

# K · fix's record keys its table on the bug's Done when items
R="$(mktemp -d "$TEST_ROOT/repo.XXXX")"
g init -q -b main; touchf README.md; g add -A; g commit -qm init; BASE="$(g rev-parse HEAD)"
g checkout -qb fix/7-decline; mkdir -p "$R/docs/specs/fix"
body="$(cat "$FIX/fix-record.md")"; printf '%s\n' "${body//\{\{HASH\}\}/$(table_hash <<<"$body")}" > "$R/docs/specs/fix/7-decline.md"
g add -A; g commit -qm "docs: plan record"
expect_eq "a Done when item with no repro test in the diff is MISSING" \
  'scope-check: 1 flag(s)
MISSING: A declined card shows "Payment declined — try another card." — no test file in the diff (src/decline.test.ts)
exit 1' "$(sc --base "$BASE")"
cm "test: decline repro" src/decline.test.ts; cm "fix: decline message" src/checkout.ts
expect_eq "a red repro commit before its fix is clean" "scope-check: clean — 0 flags
exit 0" "$(sc --base "$BASE")"

# J · inputs that make a check impossible are exit 2, never a pass
newrepo; good_build
expect_eq "no --base is not run" "scope-check: --base <sha> is required; nothing was checked
exit 2" "$(sc)"
expect_eq "a base that is not a commit is not run" "scope-check: nosuchref is not a commit here; nothing was checked
exit 2" "$(sc --base nosuchref)"
expect_eq "a missing record is not run" "scope-check: no plan record at docs/specs/none.md; nothing was checked
exit 2" "$(sc --base "$BASE" --record docs/specs/none.md)"
printf '# plan\n\nno table\n' > "$R/docs/specs/empty.md"
expect_eq "a record with no [AC] table is not run" "scope-check: no [AC] table in docs/specs/empty.md; nothing was checked
exit 2" "$(sc --base "$BASE" --record docs/specs/empty.md)"

echo
if [[ "$failures" -gt 0 ]]; then echo "$failures test(s) failed"; exit 1; fi
echo "all tests passed"
