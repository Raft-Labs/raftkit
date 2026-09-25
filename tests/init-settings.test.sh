#!/usr/bin/env bash
# Proves scripts/merge-settings.mjs is a real fail-closed merge, not a naive overwrite:
#   1. no existing file -> all managed keys written
#   2. existing unmanaged keys -> preserved byte-for-byte
#   3. existing enabledPlugins -> merged additively, nothing dropped
#   4. conflicting managed scalar -> nothing written, conflict reported (exit 2)
#   5. invalid JSON input -> nothing written, reason emitted (exit 1)
#   6. re-run with identical input -> byte-identical output, zero diff
#   7. wrong-shaped existing container (string/array where object/array expected) ->
#      conflict, never silently coerced (exit 2)
#   8. valid JSON with a non-object root ([]/string/null/number) -> rejected like
#      invalid JSON, never spread into a fresh settings object (exit 1)
set -uo pipefail
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0 NO_COLOR=1
cd "$(dirname "$0")/.."
SCRIPT="plugins/raftkit-dev/skills/setup/scripts/merge-settings.mjs"

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

check_eq() { # <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected [$2], got [$3])"
    failures=$((failures + 1))
  fi
}

newtmp() { local d; d="$(mktemp -d)"; tmpdirs+=("$d"); echo "$d"; }

# 0. Target's parent directory does not exist yet (the real .claude/ case) -> created
d0="$(newtmp)"
target0="$d0/.claude/settings.json"
node "$SCRIPT" "$target0" >/dev/null 2>&1
check "nested parent dir: script exits ok" ok $?
[[ -f "$target0" ]]
check "nested parent dir: settings.json created under .claude/" ok $?

# 1. No existing file -> all managed keys written
d1="$(newtmp)"
target="$d1/settings.json"
node "$SCRIPT" "$target" >/dev/null 2>&1
check "fresh file: script exits ok" ok $?
[[ -f "$target" ]]
check "fresh file: settings.json created" ok $?
model_val="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).model)' "$target" 2>/dev/null)"
check_eq "fresh file: model set to opusplan" "opusplan" "$model_val"
rk_val="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(s.extraKnownMarketplaces.raftkit.source.repo)' "$target" 2>/dev/null)"
check_eq "fresh file: raftkit marketplace registered" "Raft-Labs/raftkit" "$rk_val"

# 2. Existing unmanaged keys preserved byte-for-byte
d2="$(newtmp)"
target2="$d2/settings.json"
cat > "$target2" <<'EOF'
{
  "someTeamSetting": {
    "nested": true,
    "value": 42
  },
  "statusLine": {
    "type": "command",
    "command": "bash ./my-statusline.sh"
  }
}
EOF
node "$SCRIPT" "$target2" >/dev/null 2>&1
check "unmanaged keys: script exits ok" ok $?
unmanaged_val="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(JSON.stringify(s.someTeamSetting))' "$target2" 2>/dev/null)"
check_eq "unmanaged keys: someTeamSetting untouched" '{"nested":true,"value":42}' "$unmanaged_val"
status_cmd="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(s.statusLine.command)' "$target2" 2>/dev/null)"
check_eq "unmanaged keys: statusLine untouched" "bash ./my-statusline.sh" "$status_cmd"

# 3. Existing enabledPlugins merged additively, nothing dropped
d3="$(newtmp)"
target3="$d3/settings.json"
cat > "$target3" <<'EOF'
{
  "enabledPlugins": {
    "some-other-plugin@some-marketplace": true
  }
}
EOF
node "$SCRIPT" "$target3" >/dev/null 2>&1
check "enabledPlugins merge: script exits ok" ok $?
other_present="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(!!s.enabledPlugins["some-other-plugin@some-marketplace"])' "$target3" 2>/dev/null)"
check_eq "enabledPlugins merge: pre-existing entry kept" "true" "$other_present"
core_present="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(!!s.enabledPlugins["raftkit-core@raftkit"])' "$target3" 2>/dev/null)"
check_eq "enabledPlugins merge: raftkit-core added" "true" "$core_present"

# 3a. The managed plugins are raftkit-dev plus exactly its declared dependencies,
#     so the engine list cannot drift from plugin.json again (it once named 5 of 6).
node -e '
  const fs=require("fs");
  const deps=JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).dependencies;
  const want=["raftkit-dev@raftkit", ...deps.map((d)=>typeof d==="string"?`${d}@raftkit`:`${d.name}@${d.marketplace}`)].sort();
  const got=Object.keys(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).enabledPlugins).sort();
  process.exit(JSON.stringify(want)===JSON.stringify(got)?0:1);
' "$target"
check "3a enabledPlugins are raftkit-dev and exactly its declared dependencies" ok $?
! grep -qE 'claude-md-management|code-simplifier' plugins/raftkit-dev/.claude-plugin/plugin.json "$target"
check "3a raftkit-dev no longer depends on claude-md-management or the code-simplifier plugin" ok $?

# 3b. Wrong-shaped existing values -> conflict, never silently coerced
#     (a string spread into {...str} or [...str] corrupts it into a char map/array)
assert_shape_conflict() { # <name> <fixture-json>
  local name="$1" fixture="$2"
  local d target before_hash exit_code after_hash out
  d="$(newtmp)"
  target="$d/settings.json"
  printf '%s' "$fixture" > "$target"
  before_hash="$(shasum "$target")"
  out="$(node "$SCRIPT" "$target" 2>&1)"
  exit_code=$?
  check "$name: exit code is exactly 2" ok $([[ $exit_code -eq 2 ]] && echo 0 || echo 1)
  after_hash="$(shasum "$target")"
  check_eq "$name: file left byte-identical" "$before_hash" "$after_hash"
}

assert_shape_conflict "wrong-shape permissions.allow (string)" '{"permissions": {"allow": "Bash(git status:*)"}}'
assert_shape_conflict "wrong-shape permissions (array)" '{"permissions": ["not", "an", "object"]}'
assert_shape_conflict "wrong-shape enabledPlugins (array)" '{"enabledPlugins": ["raftkit-core@raftkit"]}'
assert_shape_conflict "wrong-shape attribution (string)" '{"attribution": "none"}'
assert_shape_conflict "wrong-shape extraKnownMarketplaces (string)" '{"extraKnownMarketplaces": "none"}'

# 3c. Valid JSON whose ROOT isn't an object -> rejected like invalid JSON (exit 1),
#     never silently spread into a fresh settings object (that would discard the
#     original array/scalar root without a trace).
assert_root_rejected() { # <name> <fixture-json>
  local name="$1" fixture="$2"
  local d target before_content exit_code after_content out
  d="$(newtmp)"
  target="$d/settings.json"
  printf '%s' "$fixture" > "$target"
  before_content="$(cat "$target")"
  out="$(node "$SCRIPT" "$target" 2>&1)"
  exit_code=$?
  check_eq "$name: exit code is exactly 1" "1" "$exit_code"
  after_content="$(cat "$target")"
  check_eq "$name: file left untouched" "$before_content" "$after_content"
  [[ -n "$out" ]]
  check "$name: a reason is emitted" ok $?
}

assert_root_rejected "array root" '[]'
assert_root_rejected "string root" '"just a string"'
assert_root_rejected "null root" 'null'
assert_root_rejected "number root" '42'

# Specifically prove the corruption Codex flagged does not happen: a string
# permissions.allow must never become a per-character array in the output.
d3c="$(newtmp)"
target3c="$d3c/settings.json"
printf '%s' '{"permissions": {"allow": "Bash(git status:*)"}}' > "$target3c"
node "$SCRIPT" "$target3c" >/dev/null 2>&1
untouched_allow="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).permissions.allow)' "$target3c" 2>/dev/null)"
check_eq "wrong-shape permissions.allow: value never coerced into a char array" "Bash(git status:*)" "$untouched_allow"

# 4. Conflicting managed scalar -> nothing written, conflict reported
d4="$(newtmp)"
target4="$d4/settings.json"
cat > "$target4" <<'EOF'
{
  "model": "sonnet"
}
EOF
before_hash="$(shasum "$target4")"
node "$SCRIPT" "$target4" >/tmp/init-settings-conflict-out.$$ 2>&1
exit_code=$?
check "conflict: script exits non-zero" fail $exit_code
check_eq "conflict: exit code is exactly 2" "2" "$exit_code"
after_hash="$(shasum "$target4")"
check_eq "conflict: file left byte-identical" "$before_hash" "$after_hash"
grep -qi "model" /tmp/init-settings-conflict-out.$$
check "conflict: report names the conflicting key" ok $?
rm -f /tmp/init-settings-conflict-out.$$

# 5. Invalid JSON input -> nothing written, reason emitted
d5="$(newtmp)"
target5="$d5/settings.json"
echo '{ this is not json' > "$target5"
before_content="$(cat "$target5")"
node "$SCRIPT" "$target5" >/tmp/init-settings-invalid-out.$$ 2>&1
exit_code=$?
check "invalid JSON: script exits non-zero" fail $exit_code
check_eq "invalid JSON: exit code is exactly 1" "1" "$exit_code"
after_content="$(cat "$target5")"
check_eq "invalid JSON: file left untouched" "$before_content" "$after_content"
[[ -s /tmp/init-settings-invalid-out.$$ ]]
check "invalid JSON: a reason is emitted" ok $?
rm -f /tmp/init-settings-invalid-out.$$

# W. Worktree keys (C6): phases branch from local HEAD; a Node repo also shares
#    node_modules. A differing baseRef conflicts; symlinkDirectories is a union.
jget() { node -e 'let v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for (const k of process.argv[2].split(".").filter(Boolean)) v=v?.[k]; console.log(v===undefined?"undefined":JSON.stringify(v))' "$1" "$2" 2>/dev/null; }
dw="$(newtmp)"; tw="$dw/settings.json"
node "$SCRIPT" "$tw" --node >/dev/null 2>&1
check "W1 fresh Node repo: script exits ok" ok $?
check_eq "W1 worktree.baseRef is head" '"head"' "$(jget "$tw" '.worktree.baseRef')"
check_eq "W1 worktree.symlinkDirectories shares node_modules" '["node_modules"]' "$(jget "$tw" '.worktree.symlinkDirectories')"
dw2="$(newtmp)"; tw2="$dw2/settings.json"
node "$SCRIPT" "$tw2" >/dev/null 2>&1
check_eq "W2 non-Node repo: baseRef still head" '"head"' "$(jget "$tw2" '.worktree.baseRef')"
check_eq "W2 non-Node repo: no symlinkDirectories written" 'undefined' "$(jget "$tw2" '.worktree.symlinkDirectories')"
dw3="$(newtmp)"; tw3="$dw3/settings.json"
printf '%s' '{"worktree": {"symlinkDirectories": [".cache"]}}' > "$tw3"
node "$SCRIPT" "$tw3" --node >/dev/null 2>&1
check_eq "W3 existing symlinkDirectories kept, node_modules appended" '[".cache","node_modules"]' "$(jget "$tw3" '.worktree.symlinkDirectories')"
dw4="$(newtmp)"; tw4="$dw4/settings.json"
printf '%s' '{"worktree": {"baseRef": "fresh"}}' > "$tw4"
before_w4="$(shasum "$tw4")"
out_w4="$(node "$SCRIPT" "$tw4" --node 2>&1)"; rc_w4=$?
check_eq "W4 differing worktree.baseRef: exit code is exactly 2" "2" "$rc_w4"
check_eq "W4 differing worktree.baseRef: file left byte-identical" "$before_w4" "$(shasum "$tw4")"
grep -q 'worktree.baseRef' <<<"$out_w4"
check "W4 conflict report names worktree.baseRef" ok $?
assert_shape_conflict "W5 wrong-shape worktree (string)" '{"worktree": "head"}'
d_w6="$(newtmp)"; t_w6="$d_w6/settings.json"
printf '%s' '{"worktree": {"symlinkDirectories": "node_modules"}}' > "$t_w6"
node "$SCRIPT" "$t_w6" --node >/dev/null 2>&1
check_eq "W6 wrong-shape symlinkDirectories (string): exit code is exactly 2" "2" "$?"

# O. Opt-in lines (2.3): each writes only when named, and never allowlists a push,
#    a PR or an Asana write.
allow_of() { node -e 'console.log((JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).permissions?.allow ?? []).join("\n"))' "$1" 2>/dev/null; }
mf="$(newtmp)/package.json"; printf '%s' '{"scripts":{"test":"vitest run","lint":"eslint .","lint:ci":"eslint --max-warnings 0 ."}}' > "$mf"
do1="$(newtmp)"; to1="$do1/settings.json"; node "$SCRIPT" "$to1" >/dev/null 2>&1
! grep -qE 'git (fetch|switch|add|commit)|run ' <<<"$(allow_of "$to1")" && [[ "$(jget "$to1" '.env')" == undefined ]]
check "O1 without an opt-in no local-git or gate rule and no env is written" ok $?
do2="$(newtmp)"; to2="$do2/settings.json"
node "$SCRIPT" "$to2" --allow-local --pm npm --manifest "$mf" --scripts "test lint:ci" >/dev/null 2>&1
a2="$(allow_of "$to2")"
for r in 'Bash(git fetch *)' 'Bash(git switch *)' 'Bash(git add *)' 'Bash(git commit *)' 'Bash(npm run test *)' 'Bash(npm run lint:ci *)'; do grep -qxF "$r" <<<"$a2" || { echo "  missing: $r"; false; }; done
check "O2 --allow-local adds local git fetch/switch/add/commit and one rule per approved gate script" ok $?
added2="$(comm -13 <(allow_of "$to1" | sort) <(sort <<<"$a2"))"
[[ "$(wc -l <<<"$added2" | tr -d ' ')" -eq 6 ]] && ! grep -qiE 'push|gh |pr |asana|mcp__|Bash\(\*|git \*' <<<"$added2" && ! grep -qF 'npm run lint *' <<<"$added2"
check "O3 the opt-in adds exactly those six rules: no push, PR, Asana, all of git, or unapproved script" ok $?
do4="$(newtmp)"; to4="$do4/settings.json"
node "$SCRIPT" "$to4" --allow-local --pm npm --manifest "$mf" --scripts "deploy" >/dev/null 2>&1; rc4=$?
[[ $rc4 -eq 1 && ! -e "$to4" ]]
check "O4 a gate script missing from the manifest is refused and nothing is written" ok $?
accepted=0
for bad in 'test;rm' '$(x)' '-x' 'push'; do
  d="$(newtmp)"; node "$SCRIPT" "$d/s.json" --allow-local --pm npm --manifest "$mf" --scripts "$bad" >/dev/null 2>&1
  [[ $? -eq 1 && ! -e "$d/s.json" ]] || { echo "  accepted: $bad"; accepted=1; }
done
check "O5 injection-shaped or unknown script names are refused" ok $accepted
d="$(newtmp)"; node "$SCRIPT" "$d/s.json" --allow-local --pm "npm;x" --manifest "$mf" --scripts test >/dev/null 2>&1
[[ $? -eq 1 && ! -e "$d/s.json" ]]
check "O6 an unknown package manager is refused" ok $?
do7="$(newtmp)"; to7="$do7/settings.json"; node "$SCRIPT" "$to7" --sg-push-sweep-off >/dev/null 2>&1
check_eq "O7 --sg-push-sweep-off sets env.SG_PUSH_SWEEP to 0" '"0"' "$(jget "$to7" '.env.SG_PUSH_SWEEP')"
do8="$(newtmp)"; to8="$do8/settings.json"; printf '%s' '{"env":{"SG_PUSH_SWEEP":"1"}}' > "$to8"; b8="$(shasum "$to8")"
node "$SCRIPT" "$to8" --sg-push-sweep-off >/dev/null 2>&1; rc8=$?
[[ $rc8 -eq 2 && "$b8" == "$(shasum "$to8")" ]]
check "O8 an existing different SG_PUSH_SWEEP is a conflict and nothing is written" ok $?
do9="$(newtmp)"; to9="$do9/settings.json"; node "$SCRIPT" "$to9" --disable-plugins "expo@claude-plugins-official,pyright-lsp@claude-plugins-official" >/dev/null 2>&1
[[ "$(node -e 'const s=require(process.argv[1]); console.log(s.enabledPlugins["expo@claude-plugins-official"]===false && s.enabledPlugins["pyright-lsp@claude-plugins-official"]===false)' "$to9" 2>/dev/null)" == true ]]
check "O9 --disable-plugins turns each named plugin off at project scope" ok $?
accepted=0
for managed in raftkit-dev@raftkit superpowers@claude-plugins-official 'x;y@z'; do
  d="$(newtmp)"; node "$SCRIPT" "$d/s.json" --disable-plugins "$managed" >/dev/null 2>&1
  [[ $? -eq 1 && ! -e "$d/s.json" ]] || { echo "  accepted: $managed"; accepted=1; }
done
check "O10 a RaftKit plugin, an engine or a malformed id is never disabled" ok $accepted
do11="$(newtmp)"; to11="$do11/settings.json"; printf '%s' '{"enabledPlugins":{"expo@claude-plugins-official":true}}' > "$to11"; b11="$(shasum "$to11")"
node "$SCRIPT" "$to11" --disable-plugins expo@claude-plugins-official >/dev/null 2>&1; rc11=$?
[[ $rc11 -eq 2 && "$b11" == "$(shasum "$to11")" ]]
check "O11 disabling a plugin the project explicitly enables is a conflict" ok $?
mf12="$(newtmp)/package.json"; printf '%s' '{"scripts":{"test":"vitest run","deploy":"sst deploy","push":"git push origin HEAD","db:reset":"prisma migrate reset","pretest":"x","testing":"y"}}' > "$mf12"
accepted=0
for bad in deploy push db:reset pretest testing 'test deploy'; do
  d="$(newtmp)"; node "$SCRIPT" "$d/s.json" --allow-local --pm npm --manifest "$mf12" --scripts "$bad" >/dev/null 2>&1
  [[ $? -eq 1 && ! -e "$d/s.json" ]] || { echo "  accepted: $bad"; accepted=1; }
done
check "O12 a manifest script that is not a test, lint or typecheck gate is refused, even when it exists" ok $accepted
d12="$(newtmp)"; node "$SCRIPT" "$d12/s.json" --allow-local --pm npm --manifest "$mf12" --scripts test >/dev/null 2>&1
grep -qxF 'Bash(npm run test *)' <<<"$(allow_of "$d12/s.json")"
check "O13 the gate script in that same manifest is still allowed" ok $?

# M. merge-claude-md.mjs (2.4): the working agreement + design standard spliced
#    byte-exact into a marker-delimited block, sha-verified, pure without --write.
MERGE_MD="plugins/raftkit-dev/skills/setup/scripts/merge-claude-md.mjs"
REAL_CORE="plugins/raftkit-core"
mkcore() { local c; c="$(newtmp)"; mkdir -p "$c/skills/working-agreement/references"
  cp "$REAL_CORE/skills/working-agreement/references/working-agreement.md" "$REAL_CORE/skills/working-agreement/references/design-standard.md" "$c/skills/working-agreement/references/"; echo "$c"; }
body_of() { node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8"); const m=s.match(/^<!-- raftkit:working-agreement begin sha256=([0-9a-f]{64}) -->\n([\s\S]*?)^<!-- raftkit:working-agreement end -->$/m); if(!m) process.exit(1); process.stdout.write(m[2])' "$1"; }
marker_sha() { grep -oE '^<!-- raftkit:working-agreement begin sha256=[0-9a-f]{64} -->$' "$1" | grep -oE '[0-9a-f]{64}'; }
expected_body() { cat "$1/skills/working-agreement/references/working-agreement.md"; printf '\n'; cat "$1/skills/working-agreement/references/design-standard.md"; }
sha() { shasum -a 256 | cut -d' ' -f1; }
core="$(mkcore)"
dm1="$(newtmp)"
out_m1="$(node "$MERGE_MD" --core "$core" --claude-md "$dm1/CLAUDE.md" 2>&1)"; rc_m1=$?
[[ $rc_m1 -eq 0 && ! -e "$dm1/CLAUDE.md" ]] && grep -qi 'would create' <<<"$out_m1"
check "M1 without --write the script only reports what it would do and writes nothing" ok $?
node "$MERGE_MD" --core "$core" --claude-md "$dm1/CLAUDE.md" --write >/dev/null 2>&1
check "M2 --write creates CLAUDE.md" ok $?
[[ "$(body_of "$dm1/CLAUDE.md" | sha)" == "$(expected_body "$core" | sha)" && "$(marker_sha "$dm1/CLAUDE.md")" == "$(expected_body "$core" | sha)" ]]
check "M2 the block body is byte-exact to the two sources and its marker carries that sha256" ok $?
wa_len="$(wc -c < "$REAL_CORE/skills/working-agreement/references/working-agreement.md" | tr -d ' ')"
[[ "$(body_of "$dm1/CLAUDE.md" | head -c "$wa_len" | sha)" == "$(node -e 'console.log(require("./tests/budgets.json").working_agreement_sha256)')" ]]
check "M3 the installed working agreement matches the sha256 pinned in tests/budgets.json" ok $?
dm4="$(newtmp)"; printf '# Team notes\n\nKeep this.\n' > "$dm4/CLAUDE.md"; orig4="$(cat "$dm4/CLAUDE.md")"
node "$MERGE_MD" --core "$core" --claude-md "$dm4/CLAUDE.md" --write >/dev/null 2>&1
[[ "$(head -c ${#orig4} "$dm4/CLAUDE.md")" == "$orig4" && "$(grep -c '^<!-- raftkit:working-agreement begin' "$dm4/CLAUDE.md")" -eq 1 ]]
check "M4 an existing CLAUDE.md keeps its content byte-exact and gains one block" ok $?
dm4b="$(newtmp)"; printf '# No trailing newline' > "$dm4b/CLAUDE.md"
node "$MERGE_MD" --core "$core" --claude-md "$dm4b/CLAUDE.md" --write >/dev/null 2>&1
grep -qi 'no changes' <<<"$(node "$MERGE_MD" --core "$core" --claude-md "$dm4b/CLAUDE.md" --write 2>&1)" && grep -qx '# No trailing newline' "$dm4b/CLAUDE.md"
check "M4b a CLAUDE.md without a trailing newline gets the block on its own lines, found again on re-run" ok $?
h4="$(shasum "$dm4/CLAUDE.md")"; out_m5="$(node "$MERGE_MD" --core "$core" --claude-md "$dm4/CLAUDE.md" --write 2>&1)"
[[ "$h4" == "$(shasum "$dm4/CLAUDE.md")" ]] && grep -qi 'no changes' <<<"$out_m5"
check "M5 a re-run on unchanged sources writes nothing and says no changes" ok $?
printf '\n## After the block\n\nStill mine.\n' >> "$dm4/CLAUDE.md"
before_block="$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8"); process.stdout.write(s.slice(0, s.indexOf("<!-- raftkit:working-agreement begin")))' "$dm4/CLAUDE.md")"
after_block="$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8"); const e="<!-- raftkit:working-agreement end -->\n"; process.stdout.write(s.slice(s.indexOf(e)+e.length))' "$dm4/CLAUDE.md")"
printf '\nA new rule.\n' >> "$core/skills/working-agreement/references/design-standard.md"
h6="$(shasum "$dm4/CLAUDE.md")"; node "$MERGE_MD" --core "$core" --claude-md "$dm4/CLAUDE.md" >/dev/null 2>&1
check_eq "M6 plan mode on a changed source still writes nothing" "$h6" "$(shasum "$dm4/CLAUDE.md")"
node "$MERGE_MD" --core "$core" --claude-md "$dm4/CLAUDE.md" --write >/dev/null 2>&1
[[ "$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8"); process.stdout.write(s.slice(0, s.indexOf("<!-- raftkit:working-agreement begin")))' "$dm4/CLAUDE.md")" == "$before_block" ]] \
  && [[ "$(node -e 'const s=require("fs").readFileSync(process.argv[1],"utf8"); const e="<!-- raftkit:working-agreement end -->\n"; process.stdout.write(s.slice(s.indexOf(e)+e.length))' "$dm4/CLAUDE.md")" == "$after_block" ]] \
  && [[ "$(body_of "$dm4/CLAUDE.md" | sha)" == "$(expected_body "$core" | sha)" ]]
check "M7 a re-run replaces only the marked block; text before and after it is untouched" ok $?
refused() { # <name> <file> -> exit 2 and byte-identical
  local h rc; h="$(shasum "$2" 2>/dev/null)"; node "$MERGE_MD" --core "$core" --claude-md "$2" --write >/dev/null 2>&1; rc=$?
  [[ $rc -eq 2 && "$h" == "$(shasum "$2" 2>/dev/null)" ]]; check "$1" ok $?
}
dm8="$(newtmp)"; printf 'x\n<!-- raftkit:working-agreement begin sha256=%064d -->\nno end\n' 0 > "$dm8/CLAUDE.md"
refused "M8 a begin marker with no end marker is a conflict and nothing is written" "$dm8/CLAUDE.md"
dm9="$(newtmp)"; { cat "$dm1/CLAUDE.md"; cat "$dm1/CLAUDE.md"; } > "$dm9/CLAUDE.md"
refused "M9 two blocks are a conflict and nothing is written" "$dm9/CLAUDE.md"
dm10="$(newtmp)"; printf '# real\n' > "$dm10/AGENTS.md"; ln -s AGENTS.md "$dm10/CLAUDE.md"
refused "M10 a symlinked CLAUDE.md is a conflict and nothing is written" "$dm10/CLAUDE.md"
dm11="$(newtmp)"; { printf '# Notes\n\n'; cat "$REAL_CORE/skills/working-agreement/references/working-agreement.md"; } > "$dm11/CLAUDE.md"
refused "M11 an unmarked copy of the working agreement is a conflict, never a second copy" "$dm11/CLAUDE.md"
dm12="$(newtmp)"; empty_core="$(newtmp)"
node "$MERGE_MD" --core "$empty_core" --claude-md "$dm12/CLAUDE.md" --write >/dev/null 2>&1; rc12=$?
[[ $rc12 -eq 1 && ! -e "$dm12/CLAUDE.md" ]]
check "M12 a missing source file exits 1 and writes nothing" ok $?
[[ -z "$(find "$dm1" "$dm4" -mindepth 1 ! -name CLAUDE.md)" ]]
check "M13 no temporary file is left beside CLAUDE.md" ok $?
core14="$(mkcore)"; ds14="$core14/skills/working-agreement/references/design-standard.md"
printf '%s' "$(cat "$ds14")" > "$ds14.tmp" && mv "$ds14.tmp" "$ds14"
dm14="$(newtmp)"; node "$MERGE_MD" --core "$core14" --claude-md "$dm14/CLAUDE.md" --write >/dev/null 2>&1; rc14=$?
[[ $rc14 -eq 0 && "$(marker_sha "$dm14/CLAUDE.md")" == "$(expected_body "$core14" | sha)" ]] \
  && grep -qi 'no changes' <<<"$(node "$MERGE_MD" --core "$core14" --claude-md "$dm14/CLAUDE.md" --write 2>&1)"
check "M14 a source without a trailing newline still verifies, and its re-run finds no changes" ok $?

# 6. Re-run with identical input -> byte-identical output, zero diff
d6="$(newtmp)"
target6="$d6/settings.json"
node "$SCRIPT" "$target6" >/dev/null 2>&1
first_hash="$(shasum "$target6")"
node "$SCRIPT" "$target6" >/dev/null 2>&1
check "idempotent re-run: script exits ok" ok $?
second_hash="$(shasum "$target6")"
check_eq "idempotent re-run: byte-identical output" "$first_hash" "$second_hash"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
