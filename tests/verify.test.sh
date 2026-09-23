#!/usr/bin/env bash
# Contract suite for plugins/raftkit-dev/scripts/verify.mjs (2.5, contract C2):
# gate commands come from setup's detect-toolchain.mjs; one line on green;
# failing names plus at most 20 lines each on red; green results cached under
# the git common dir keyed by tree hash, never reused on a dirty tree; red never
# cached. The pre-push hook keeps running its gates in full.
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
cd "$(dirname "$0")/.." || exit 2
REPO_ROOT="$PWD"
VERIFY="$REPO_ROOT/plugins/raftkit-dev/scripts/verify.mjs"

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
newtmp() { local d; d="$(mktemp -d)"; tmpdirs+=("$d"); echo "$d"; }

# Isolated git: the developer's config, hooks and templates are never read.
ISO="$(newtmp)"; : > "$ISO/gitconfig"
giso() { HOME="$ISO" XDG_CONFIG_HOME="$ISO/xdg" GIT_CONFIG_GLOBAL="$ISO/gitconfig" GIT_CONFIG_NOSYSTEM=1 "$@"; }
COUNT="$(newtmp)/count"; : > "$COUNT"
export VCOUNT="$COUNT"
runs() { cat "$COUNT"; }

# Each script appends its initial to $VCOUNT; test prints 30 lines and fails
# while a tracked FAIL file exists; lint prints a line even when green, and
# writes an untracked file while a tracked GEN file exists, and deletes an
# untracked CLEANME file.
mkrepo() { # <dir>
  local d="$1"
  mkdir -p "$d"
  cat > "$d/package.json" <<'JSON'
{
  "name": "fixture",
  "scripts": {
    "test": "node -e \"const fs=require('fs'); fs.appendFileSync(process.env.VCOUNT,'t'); if (fs.existsSync('FAIL')) { for (let i=1;i<=30;i++) console.log('failure line '+i); process.exit(1) }\"",
    "lint": "node -e \"const fs=require('fs'); fs.appendFileSync(process.env.VCOUNT,'l'); if (fs.existsSync('GEN')) fs.writeFileSync('generated.txt','x'); fs.rmSync('CLEANME',{force:true}); console.log('LINT-GREEN-NOISE')\"",
    "typecheck": "node -e \"require('fs').appendFileSync(process.env.VCOUNT,'c')\""
  }
}
JSON
  echo '{}' > "$d/package-lock.json"
  ( cd "$d" && giso git init -q -b main && giso git add -A && giso git -c user.email=t@t -c user.name=t commit -qm init )
}
commit_all() { ( cd "$1" && giso git add -A && giso git -c user.email=t@t -c user.name=t commit -qm "$2" ); }
v() { OUT="$(cd "$1" && shift && giso node "$VERIFY" "$@" 2>&1)"; RC=$?; }
lines() { printf '%s\n' "$OUT" | grep -c . ; }

R="$(newtmp)/repo"; mkrepo "$R"

# ---- green, one line, then cached -------------------------------------------
: > "$COUNT"; v "$R"
[[ $RC -eq 0 && "$(lines)" -eq 1 ]] && grep -q '^verify: green' <<<"$OUT" && [[ "$(runs)" == tlc ]]
check "V1 green: exit 0, exactly one line, each gate ran once" ok $?
! grep -q 'LINT-GREEN-NOISE' <<<"$OUT"
check "V2 a green gate's own output is never printed" ok $?
: > "$COUNT"; v "$R"
[[ $RC -eq 0 && "$(lines)" -eq 1 && -z "$(runs)" ]] && grep -q 'cached' <<<"$OUT"
check "V3 an unchanged clean tree reuses the cached result and runs nothing" ok $?
cache="$(cd "$R" && giso git rev-parse --path-format=absolute --git-common-dir)/raftkit/verify.json"
tree="$(cd "$R" && giso git rev-parse 'HEAD^{tree}')"
[[ -f "$cache" ]] && grep -q "$tree" "$cache"
check "V4 the cache lives at <git common dir>/raftkit/verify.json keyed by the tree hash" ok $?

# ---- dirty trees never reuse --------------------------------------------------
echo "// edit" >> "$R/package.json.note"; : > "$COUNT"; v "$R"
[[ $RC -eq 0 && "$(runs)" == tlc ]] && grep -q 'uncommitted' <<<"$OUT"
check "V5 an untracked file makes the tree dirty: every gate runs again" ok $?
: > "$COUNT"; v "$R"
[[ "$(runs)" == tlc ]]
check "V6 a dirty tree never reuses a result, even its own previous run" ok $?
commit_all "$R" "note"; : > "$COUNT"; v "$R"
[[ $RC -eq 0 && "$(runs)" == tlc ]]
check "V7 a new commit is a new tree: every gate runs" ok $?
: > "$COUNT"; v "$R" --only lint
[[ $RC -eq 0 && -z "$(runs)" ]] && grep -q 'lint' <<<"$OUT" && ! grep -q 'test' <<<"$OUT"
check "V8 --only lint on a verified tree reuses lint's result and names only lint" ok $?
echo y > "$R/fresh.txt"; commit_all "$R" "fresh"; echo z > "$R/scratch.txt"; v "$R"; rm "$R/scratch.txt"; : > "$COUNT"; v "$R"
[[ "$(runs)" == tlc ]]
check "V6b a result from a dirty run is never stored for HEAD's tree" ok $?
touch "$R/GEN"; commit_all "$R" "gen"; v "$R"; rm -f "$R/generated.txt"; : > "$COUNT"; v "$R"; rm -f "$R/generated.txt" "$R/GEN"; commit_all "$R" "ungen"
[[ "$(runs)" == tlc ]]
check "V6c a gate that dirties the tree while it runs is not cached" ok $?
echo w > "$R/fresh2.txt"; commit_all "$R" "fresh2"; touch "$R/CLEANME"; v "$R"; : > "$COUNT"; v "$R"
[[ "$(runs)" == tlc ]]
check "V6d a run that started dirty is never stored, even when a gate cleaned the tree" ok $?
echo x > "$R/other.txt"; commit_all "$R" "other"; : > "$COUNT"; v "$R" --only lint
[[ $RC -eq 0 && "$(runs)" == l ]]
check "V9 --only lint runs lint alone" ok $?

# ---- red: failing names plus at most 20 lines each, never cached ------------
touch "$R/FAIL"; commit_all "$R" "break"; : > "$COUNT"; v "$R"
[[ $RC -eq 1 ]] && grep -q '^verify: red' <<<"$OUT" && grep -q 'test' <<<"$(head -1 <<<"$OUT")" \
  && grep -q 'failure line 30' <<<"$OUT" && ! grep -q 'failure line 10$' <<<"$OUT" \
  && [[ "$(grep -c '^failure line' <<<"$OUT")" -le 20 ]] && ! grep -q 'LINT-GREEN-NOISE' <<<"$OUT"
check "V10 red: exit 1, the failing gate named, at most its last 20 lines, no green output" ok $?
[[ "$(runs)" == tlc ]]
check "V11 a red gate does not stop the others: every gate still ran" ok $?
: > "$COUNT"; v "$R"
[[ $RC -eq 1 && "$(runs)" == t ]] && grep -q 'lint (cached)' <<<"$OUT"
check "V12 a red result is never cached: the same tree re-runs the red gate and reuses the greens" ok $?

# ---- refusals and postures ----------------------------------------------------
: > "$COUNT"; v "$R" --only deploy
[[ $RC -eq 2 && -z "$(runs)" ]]
check "V13 --only with an unknown gate exits 2 and runs nothing" ok $?
U="$(newtmp)/undetermined"; mkrepo "$U"; rm "$U/package-lock.json"; commit_all "$U" "no lockfile"
: > "$COUNT"; v "$U"
[[ $RC -eq 2 && -z "$(runs)" ]] && grep -qi 'setup' <<<"$OUT"
check "V14 an undetermined package manager exits 2, runs nothing and points to setup" ok $?
N="$(newtmp)/nonnode"; mkdir -p "$N" && echo "# x" > "$N/README.md" && ( cd "$N" && giso git init -q -b main ) && commit_all "$N" "init"
v "$N"
[[ $RC -eq 0 && "$(lines)" -eq 1 ]] && grep -qi 'nothing to run' <<<"$OUT"
check "V15 a repo with no Node manifest has nothing to run" ok $?
P="$(newtmp)/partial"; mkrepo "$P"
node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(process.argv[1])); delete p.scripts.typecheck; fs.writeFileSync(process.argv[1], JSON.stringify(p))' "$P/package.json"; commit_all "$P" "no typecheck"
: > "$COUNT"; v "$P"
[[ $RC -eq 0 && "$(runs)" == tl ]] && grep -q 'no typecheck script' <<<"$OUT"
check "V16 an absent gate is named, never invented" ok $?
printf 'not json' > "$cache"; rm -f "$R/FAIL"; commit_all "$R" "fix"; : > "$COUNT"; v "$R"
[[ $RC -eq 0 && "$(runs)" == tlc ]]
check "V17 an unreadable cache is ignored, never fatal" ok $?

# ---- nothing run is never green; a cached green has a bypass and an age limit --
mkscripts() { # <dir> <scripts json>
  mkdir -p "$1" && printf '{"name":"f","scripts":%s}' "$2" > "$1/package.json" && echo '{}' > "$1/package-lock.json"
  ( cd "$1" && giso git init -q -b main ) && commit_all "$1" "init"
}
VAR="$(newtmp)/variants"; mkscripts "$VAR" '{"test:unit":"node -e \"require(\\\"fs\\\").appendFileSync(process.env.VCOUNT,\\\"u\\\")\"","lint:ci":"node -e 0"}'
: > "$COUNT"; v "$VAR"
[[ $RC -eq 2 && -z "$(runs)" && "$(lines)" -eq 1 ]] && grep -q 'nothing was run' <<<"$OUT" && grep -q 'test:unit' <<<"$OUT" && grep -q 'lint:ci' <<<"$OUT"
check "V19 gates only under other names (test:unit, lint:ci): exit 2, nothing run, each named" ok $?
MIX="$(newtmp)/mixed"; mkscripts "$MIX" '{"test":"node -e \"require(\\\"fs\\\").appendFileSync(process.env.VCOUNT,\\\"t\\\")\"","lint:ci":"node -e 0"}'
: > "$COUNT"; v "$MIX"
[[ $RC -eq 2 && "$(runs)" == t && "$(lines)" -eq 1 ]] && ! grep -q '^verify: green' <<<"$OUT" && grep -q 'lint:ci not run' <<<"$OUT" && grep -q 'no typecheck script' <<<"$OUT"
check "V20 a gate verify does not run makes the result incomplete, never green" ok $?
NONE="$(newtmp)/nogates"; mkscripts "$NONE" '{"build":"node -e 0"}'
v "$NONE"
[[ $RC -eq 2 ]] && grep -q 'nothing was run' <<<"$OUT"
check "V21 a Node repo with no gate script exits 2: nothing run is never exit 0" ok $?
F="$(newtmp)/fresh"; mkrepo "$F"; v "$F"; : > "$COUNT"; v "$F" --fresh
[[ $RC -eq 0 && "$(runs)" == tlc ]] && ! grep -q 'cached' <<<"$OUT"
check "V22 --fresh re-runs every gate on a verified clean tree" ok $?
fcache="$(cd "$F" && giso git rev-parse --path-format=absolute --git-common-dir)/raftkit/verify.json"
node -e 'const fs=require("fs"); const c=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); for (const e of c) for (const r of Object.values(e.results)) r.at=new Date(Date.now()-2*3600e3).toISOString(); fs.writeFileSync(process.argv[1], JSON.stringify(c))' "$fcache"
: > "$COUNT"; v "$F"
[[ $RC -eq 0 && "$(runs)" == tlc ]]
check "V23 a cached green older than an hour is not reused" ok $?

# ---- the pre-push hook keeps its full gates ---------------------------------
HOOK="$REPO_ROOT/plugins/raftkit-dev/skills/setup/assets/pre-push"
! grep -qE 'verify\.mjs|verify\.json|raftkit/verify' "$HOOK" && grep -q '__QUALITY_SCRIPTS__' "$HOOK"
check "V18 the pre-push hook still runs every approved gate itself, with no cache" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
