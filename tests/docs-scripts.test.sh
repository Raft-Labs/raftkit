#!/usr/bin/env bash
# Deterministic (offline) suite for the docs skill (Story B, Asana 1216756365676677).
#
# AC → evidence matrix (deterministic tests here; behavioral eval bundle authored
# pre-implementation and structurally verified — plugin/no-plugin EXECUTION is
# deferred to M3 · raftkit-dev final plugin evaluation, never claimed here):
#   AC-1  mode routing .............. D19 (contract strings)      + eval cases
#   AC-2  preflight branches ........ D5 (audit branch detection) + eval cases
#   AC-3  handoff consumption ....... D19                          + eval cases
#   AC-4  spec-first ................ D19                          + eval cases
#   AC-5  seven-step lifecycle ...... D19                          + eval cases
#   AC-6  no silent mutation ........ D19 (+ scripts never mutate: D12, D21)
#   AC-7  completion parity ......... D8–D10 (stale / no-impact evidence)
#   AC-8  reverse engineering ....... D17 (unresolved-conflict reporting) + eval cases
#   AC-9  architecture generalization D3, D4, D6, D15, D18
#   AC-10 deterministic scripts ..... D7–D16, D21 (flags, evidence, safety, git)
#   AC-11 fixture coverage red-first  D1 + this whole suite, observed red first
#   AC-12 eval bundle authored ...... D20 (structural + no-leak; execution deferred)
#   AC-13 Story A integration ....... D19 (capability-preflight reference)
#   AC-14 manifests/PR boundaries ... D22 (+ scripts/validate.sh in CI)
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
tmpdirs=()
cleanup() { for d in "${tmpdirs[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done; }
trap cleanup EXIT

check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}

SKILL=plugins/raftkit-dev/skills/docs
AUDIT=$SKILL/scripts/audit-docs.mjs
VALIDATE=$SKILL/scripts/validate-docs.mjs
FIX=tests/fixtures/docs

run_audit()    { OUT=$(node "$AUDIT" "$@" 2>&1); RC=$?; }
run_validate() { OUT=$(node "$VALIDATE" "$@" 2>&1); RC=$?; }

# D1 · fixture directories match the approved neutral names exactly
expected="architectural-adr broken-links code-no-docs excluded-secret-paths flat-ownership-indexed greenfield-handoff hybrid module-indexed no-impact out-of-root-symlink routine-no-adr stale-doc unknown-inference"
actual=$(find "$FIX" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ' | sed 's/ $//')
[[ "$actual" == "$expected" ]]
check "D1 fixture set matches the approved neutral names" ok $?

# D2 · project-independence (generic invariants, no name denylist):
#      no absolute user paths, no file:// links, fixture secrets are FAKE-only,
#      and every relative reference in the skill resolves inside the plugin.
! grep -rEl '/Users/|/home/[a-z]|file://' "$SKILL" "$FIX" plugins/raftkit-dev/evals/docs 2>/dev/null | grep -q .
check "D2a no absolute user paths or file:// links" ok $?
! grep -rL 'FAKE' "$FIX/excluded-secret-paths/.env" "$FIX/excluded-secret-paths/keys/service.key" 2>/dev/null | grep -q .
check "D2b fixture secret files carry only FAKE sentinel values" ok $?
node -e '
  const fs = require("fs"), path = require("path");
  const skill = "plugins/raftkit-dev/skills/docs";
  const md = fs.readFileSync(path.join(skill, "SKILL.md"), "utf8");
  const refs = [...md.matchAll(/\]\((?!https?:)([^)#]+)\)|`(references\/[\w./-]+|scripts\/[\w./-]+)`/g)]
    .map((m) => m[1] || m[2]).filter(Boolean);
  for (const r of refs) if (!fs.existsSync(path.join(skill, r))) { console.error("dangling: " + r); process.exit(1); }
' 2>/dev/null
check "D2c SKILL.md references resolve inside the plugin boundary" ok $?

# D3/D4 · audit discovers both architectures
run_audit --root "$FIX/module-indexed" --json
[[ $RC -eq 0 ]] && grep -q '"convention": *"module-indexed"' <<<"$OUT"
check "D3 audit detects the module-indexed convention" ok $?
run_audit --root "$FIX/flat-ownership-indexed" --json
[[ $RC -eq 0 ]] && grep -q '"convention": *"flat-ownership-indexed"' <<<"$OUT"
check "D4 audit detects the flat-ownership-indexed convention" ok $?

# D5 · audit detects the preflight branches
run_audit --root "$FIX/greenfield-handoff" --json
grep -q '"branch": *"greenfield-handoff"' <<<"$OUT"
check "D5a greenfield handoff branch detected" ok $?
run_audit --root "$FIX/code-no-docs" --json
grep -q '"branch": *"existing-code-no-docs"' <<<"$OUT"
check "D5b existing-code-no-docs branch detected" ok $?
run_audit --root "$FIX/module-indexed" --json
grep -q '"branch": *"living-docs"' <<<"$OUT"
check "D5c living-docs branch detected" ok $?

# D6 · both architectures validate clean
run_validate --root "$FIX/module-indexed"
check "D6a module-indexed validates clean" ok $RC
run_validate --root "$FIX/flat-ownership-indexed"
check "D6b flat-ownership-indexed validates clean" ok $RC

# D7 · broken links fail, naming the file
run_validate --root "$FIX/broken-links"
[[ $RC -eq 1 ]] && grep -q 'feature-b.md' <<<"$OUT" && grep -q 'gone.md' <<<"$OUT"
check "D7 broken link reported with source and target" ok $?

# D8 · stale doc versus an explicitly selected change set
chg="$(mktemp)"; tmpdirs+=("$chg")
printf 'src/pay.js\n' > "$chg"
run_validate --root "$FIX/stale-doc" --changed "$chg"
[[ $RC -eq 1 ]] && grep -q 'api-pay.md' <<<"$OUT" && grep -q 'src/pay.js' <<<"$OUT"
check "D8 stale doc flagged, naming doc and inspected change" ok $?

# D9 · no-impact reports its evidence (change set, roots, ownership source)
chg2="$(mktemp)"; tmpdirs+=("$chg2")
printf 'CHANGES.txt\n' > "$chg2"
run_validate --root "$FIX/no-impact" --changed "$chg2"
[[ $RC -eq 0 ]] && grep -q 'Docs: not impacted — ' <<<"$OUT" \
  && grep -q 'CHANGES.txt' <<<"$OUT" && grep -q 'docs/project' <<<"$OUT" && grep -qi 'ownership' <<<"$OUT"
check "D9 no-impact line carries change set, roots, ownership evidence" ok $?

# D10 · no change-set input -> stale/no-impact not evaluated, never guessed
run_validate --root "$FIX/no-impact"
grep -q 'not evaluated — no change set provided' <<<"$OUT"
check "D10 missing change set reported as not evaluated" ok $?

# D11 · argument order: flags in any position; a flag is never a path
run_validate --json --root "$FIX/module-indexed"
check "D11a --json before --root works" ok $RC
run_validate --root "$FIX/module-indexed" --json
check "D11b --json after --root works" ok $RC
run_validate --json
[[ $RC -eq 2 ]]
check "D11c bare --json is not treated as a path (bad input, exit 2)" ok $?

# D12 · no file is written without an explicit output path; --out is root-confined
sandbox="$(mktemp -d)"; tmpdirs+=("$sandbox")
cp -R "$FIX/module-indexed" "$sandbox/repo"
before=$(find "$sandbox/repo" -type f | wc -l)
( cd "$sandbox" && node "$OLDPWD/$VALIDATE" --root repo --json >/dev/null 2>&1 )
after=$(find "$sandbox/repo" -type f | wc -l)
[[ "$before" -eq "$after" ]] && [[ -z "$(find "$sandbox" -maxdepth 1 -type f)" ]]
check "D12a no report file without an explicit output path" ok $?
run_validate --root "$sandbox/repo" --json --out "$sandbox/repo/report.json"
[[ $RC -eq 0 && -f "$sandbox/repo/report.json" ]]
check "D12b --out inside the root writes the report" ok $?
run_validate --root "$sandbox/repo" --json --out "$sandbox/outside.json"
[[ $RC -eq 2 && ! -f "$sandbox/outside.json" ]]
check "D12c --out outside the root is refused, nothing written" ok $?

# D13 · root confinement on changed paths and symlinks
chg3="$(mktemp)"; tmpdirs+=("$chg3")
printf '../../etc/passwd\n' > "$chg3"
run_validate --root "$FIX/no-impact" --changed "$chg3"
[[ $RC -eq 2 ]] && grep -qi 'outside' <<<"$OUT"
check "D13a traversal in the changed list is rejected" ok $?
symdir="$(mktemp -d)"; tmpdirs+=("$symdir")
cp -R "$FIX/out-of-root-symlink" "$symdir/repo"
printf 'outside content\n' > "$symdir/outside.md"
ln -s ../../outside.md "$symdir/repo/docs/project/escape.md"
run_validate --root "$symdir/repo"
grep -qi 'symlink' <<<"$OUT" && ! grep -q 'outside content' <<<"$OUT"
check "D13b out-of-root symlink refused, never followed" ok $?

# D14 · excluded paths are metadata only; secret values never in output
secdir="$(mktemp -d)"; tmpdirs+=("$secdir")
cp -R "$FIX/excluded-secret-paths" "$secdir/repo"
mkdir -p "$secdir/repo/node_modules/pkg" && printf 'module.exports = 1;\n' > "$secdir/repo/node_modules/pkg/index.js"
run_audit --root "$secdir/repo" --json
! grep -q 'FAKE-VALUE-FOR-TEST-ONLY' <<<"$OUT" && ! grep -q 'FAKE-KEY-MATERIAL' <<<"$OUT"
check "D14a secret values never appear in audit output" ok $?
run_validate --root "$secdir/repo" --json
! grep -q 'FAKE-VALUE-FOR-TEST-ONLY' <<<"$OUT" && ! grep -q 'node_modules/pkg/index.js' <<<"$OUT"
check "D14b secret/vendor contents excluded from validation output" ok $?

# D15 · convention conflict: descriptor vs discovery -> report both, exit 2, ask.
# The descriptor is project-owned, so it lives INSIDE the repo root (F2 rejects
# an out-of-root descriptor); write it into the fixture and clean it up.
conv="$FIX/module-indexed/.raftkit-docs-convention.json"; tmpdirs+=("$conv")
printf '{"convention":"flat-ownership-indexed"}\n' > "$conv"
run_validate --root "$FIX/module-indexed" --convention "$conv"
[[ $RC -eq 2 ]] && grep -q 'module-indexed' <<<"$OUT" && grep -q 'flat-ownership-indexed' <<<"$OUT" \
  && grep -qi 'which convention' <<<"$OUT"
check "D15 convention conflict names both sources and asks the human" ok $?

# D16 · git change-set resolution: no shell, validated refs, SHAs, renames, spaces
gitdir="$(mktemp -d)"; tmpdirs+=("$gitdir")
cp -R "$FIX/stale-doc/." "$gitdir/repo" 2>/dev/null || { mkdir -p "$gitdir/repo"; cp -R "$FIX/stale-doc/"* "$gitdir/repo/"; }
git -C "$gitdir/repo" init -q -b main
git -C "$gitdir/repo" -c user.email=t@t -c user.name=t add -A
git -C "$gitdir/repo" -c user.email=t@t -c user.name=t commit -qm base
printf 'exports.pay = () => 2;\n' > "$gitdir/repo/src/pay.js"
mkdir -p "$gitdir/repo/src/deep dir" && printf 'x\n' > "$gitdir/repo/src/deep dir/with space.js"
git -C "$gitdir/repo" mv docs/project/api/api-pay.md docs/project/api/api-payments.md
git -C "$gitdir/repo" -c user.email=t@t -c user.name=t add -A
git -C "$gitdir/repo" -c user.email=t@t -c user.name=t commit -qm change
run_validate --root "$gitdir/repo" --base main~1 --json
grep -qE '"baseSha": *"[0-9a-f]{7,}"' <<<"$OUT" && grep -q 'src/pay.js' <<<"$OUT" && grep -q 'with space.js' <<<"$OUT"
check "D16a git base resolved to SHA; changed set includes spaced path" ok $?
grep -q 'api-pay.md' <<<"$OUT" && grep -q 'api-payments.md' <<<"$OUT"
check "D16b rename reported with old and new names" ok $?
run_validate --root "$gitdir/repo" --base 'no-such-ref'
[[ $RC -eq 2 ]]
check "D16c unknown ref is bad input, not an empty change set" ok $?
run_validate --root "$gitdir/repo" --base '--evil'
[[ $RC -eq 2 ]]
check "D16d flag-shaped ref rejected (no shell, validated input)" ok $?

# D17 · conflicting discovery signals -> unresolved conflicts surfaced
run_audit --root "$FIX/unknown-inference" --json
grep -q '"unresolvedConflicts"' <<<"$OUT" && grep -qv '"unresolvedConflicts": *\[\]' <<<"$OUT"
check "D17 ambiguous convention signals reported as unresolved" ok $?

# D18 · ADR seam detection
run_audit --root "$FIX/architectural-adr" --json
grep -q '"adrSeam": *true' <<<"$OUT"
check "D18a ADR seam detected where present" ok $?
run_audit --root "$FIX/routine-no-adr" --json
grep -q '"adrSeam": *false' <<<"$OUT"
check "D18b no ADR seam invented where absent" ok $?

# D19 · SKILL.md carries the approved contract verbatim
S=$SKILL/SKILL.md
grep -qF 'Docs: not impacted — <reason>' "$S" 2>/dev/null;                       check "D19a no-impact line in contract" ok $?
grep -qF 'Docs: updated and verified —' "$S" 2>/dev/null;                        check "D19b updated-and-verified line in contract" ok $?
grep -qF 'No approved planning output covers this' "$S" 2>/dev/null;             check "D19c init refusal line in contract" ok $?
grep -qF 'docs mode:' "$S" 2>/dev/null;                                          check "D19d mode announcement in contract" ok $?
grep -q 'identify' "$S" 2>/dev/null && grep -q 'classify' "$S" 2>/dev/null && grep -q 're-verify' "$S" 2>/dev/null
check "D19e seven-step lifecycle present" ok $?
grep -qi 'never writes to Asana' "$S" 2>/dev/null;                               check "D19f no-Asana rule stated" ok $?
grep -q 'confirmed' "$S" 2>/dev/null && grep -q 'inferred' "$S" 2>/dev/null && grep -q 'unknown' "$S" 2>/dev/null
check "D19g confirmed/inferred/unknown marking stated" ok $?
grep -q 'capability-preflight' "$S" 2>/dev/null;                                 check "D19h capability-preflight contract referenced" ok $?
grep -qi 'in-memory' "$S" 2>/dev/null && grep -qi 'project-owned' "$S" 2>/dev/null
check "D19i in-memory discovery + approved project-owned persistence" ok $?

# D20 · eval bundle: authored, structurally valid, no answer leakage
n=$(find plugins/raftkit-dev/evals/docs -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 10 ]] \
  && ! find plugins/raftkit-dev/evals/docs -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/docs -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "D20a >=10 eval cases each with prompt.md + graders" ok $?
! grep -l 'Docs: not impacted —' plugins/raftkit-dev/evals/docs/*/prompt.md 2>/dev/null | grep -q .
check "D20b prompts do not leak the expected no-impact copy" ok $?

# D21 · scripts leave no temporary files behind
tcount_before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'docs-skill-*' 2>/dev/null | wc -l)
run_validate --root "$FIX/module-indexed" --json >/dev/null
tcount_after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'docs-skill-*' 2>/dev/null | wc -l)
[[ "$tcount_before" -eq "$tcount_after" ]]
check "D21 no temp files left behind" ok $?

# D22 · manifests: version + description lockstep for Story B. The version
# check asserts Story B's minimum introduced version (>= 0.13.0, numeric
# comparison) — later program stories bump further on the shared integration
# branch, and the repository version gate owns the exact current version.
node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 13, 0];
  const cmp = v[0] - min[0] || v[1] - min[1] || v[2] - min[2];
  process.exit(cmp >= 0 ? 0 : 1);
'
check "D22a raftkit-dev version is at least 0.13.0 (story B bump held)" ok $?
node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  const entry = m.plugins.find(x => x.name === "raftkit-dev");
  process.exit(entry.description === p.description && /\bdocs\b/.test(p.description) ? 0 : 1);
'
check "D22b description lockstep includes docs" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
