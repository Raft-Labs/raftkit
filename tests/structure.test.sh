#!/usr/bin/env bash
# Structural contract for RaftKit v2 skills. Replaces the prose-pin suites:
# it checks shape, size and the one-stop rule, never wording. Budgets live in
# tests/budgets.json. While `strict` is false (mid-migration) a listed skill
# that is not on disk is skipped; once true, every skill directory on disk
# must be listed and every repo-wide invariant applies to all plugins.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
export NODE_DISABLE_COLORS=1 FORCE_COLOR=0

failures=0
check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}
jsonq() { node -e 'const j=JSON.parse(require("fs").readFileSync("tests/budgets.json","utf8")); const v=eval("j"+process.argv[1]); process.stdout.write(typeof v==="object"?JSON.stringify(v):String(v))' "$1"; }
words() { cat "$@" 2>/dev/null | wc -w | tr -d ' '; }
# assets/ holds payloads shipped verbatim (templates, prompts), not instructions
# the model reads to act — they are excluded from the instruction budget.
mdwords() { find "$1" -name '*.md' -type f -not -path '*/assets/*' -print0 | xargs -0 cat 2>/dev/null | wc -w | tr -d ' '; }
fm() { awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' "$1"; }

node -e 'JSON.parse(require("fs").readFileSync("tests/budgets.json","utf8"))'
check "S0 budgets.json is valid JSON" ok $?

strict="$(jsonq '.strict')"
headroom="$(jsonq '.headroom')"
listed="$(node -e 'const j=JSON.parse(require("fs").readFileSync("tests/budgets.json","utf8")); console.log(Object.keys(j.skills).join("\n"))')"

present=()
for key in $listed; do
  dir="plugins/${key%/*}/skills/${key#*/}"
  if [[ "$strict" != true && "$(jsonq ".skills[\"$key\"].v2")" != true ]]; then
    continue  # not rewritten yet; the old skill under this name is not held to v2 budgets
  fi
  if [[ ! -d "$dir" ]]; then
    check "S1 listed skill exists on disk: $key" fail 0
    continue
  fi
  present+=("$key")
  skill="${key#*/}"; plugin="${key%/*}"; f="$dir/SKILL.md"
  [[ -f "$f" ]]; check "S1 $key has SKILL.md" ok $?

  [[ "$(fm "$f" | sed -n 's/^name: *//p' | head -1)" == "$skill" ]]
  check "S2 $key frontmatter name matches its directory" ok $?

  as_is="$(jsonq ".skills[\"$key\"].as_is")"   # moved verbatim from v1; shape checks do not apply

  desc_words="$(fm "$f" | sed -n 's/^description: *//p' | head -1 | wc -w | tr -d ' ')"
  if [[ "$as_is" == true ]]; then
    [[ "$desc_words" -ge 1 ]]
    check "S3 $key (moved as is) has a description" ok $?
  else
    [[ "$desc_words" -ge 1 && "$desc_words" -le 60 ]]
    check "S3 $key description is 1-60 words ($desc_words)" ok $?
  fi

  cap="$(node -e "process.stdout.write(String(Math.floor($(jsonq ".skills[\"$key\"].skill_md")*$headroom)))")"
  n="$(words "$f")"; [[ "$n" -le "$cap" ]]
  check "S4 $key SKILL.md within budget ($n <= $cap words)" ok $?

  cap="$(node -e "process.stdout.write(String(Math.floor($(jsonq ".skills[\"$key\"].total")*$headroom)))")"
  n="$(mdwords "$dir")"; [[ "$n" -le "$cap" ]]
  check "S5 $key directory within budget ($n <= $cap words)" ok $?

  stops="$(grep -rhc '^\*\*STOP\*\*' "$dir" --include='*.md' 2>/dev/null | awk '{s+=$1} END{print s+0}')"
  if [[ "$key" == "raftkit-core/rules" ]]; then
    # rules owns the contract, so it carries the line itself as the canonical
    # example. It is not a run and cannot stop one.
    [[ "$stops" -eq 1 ]]
    check "S6 $key carries the one canonical STOP line ($stops)" ok $?
  elif [[ "$(jsonq ".skills[\"$key\"].writes")" == true ]]; then
    [[ "$stops" -le 1 ]]; check "S6 $key shows at most one STOP line ($stops)" ok $?
  else
    [[ "$stops" -eq 0 ]]; check "S6 $key writes nothing, so shows no STOP line ($stops)" ok $?
  fi

  if [[ "$as_is" != true ]]; then
    ! grep -qE '^## (Reference files|Asana rendering|Out of scope)' "$f"
    check "S7 $key carries no index, rendering-footer or out-of-scope section" ok $?
  fi

  if [[ "$key" != "raftkit-core/rules" && "$as_is" != true ]]; then
    ! grep -rqF 'Plain English out' "$dir"
    check "S8 $key does not restate the plain-language guardrail" ok $?
    ! grep -rqiE 'never from memory or this repo|silence is not (approval|confirmation)|custom fields, milestones' "$dir"
    check "S9 $key does not restate live-fetch, gate or free-tier boilerplate" ok $?
    ! grep -rqE '1194107417268910|1216778429401199|1215260732424760' "$dir"
    check "S10 $key carries no GID (they live only in raftkit-core/rules)" ok $?
  fi

  if [[ "$plugin" == raftkit-pm || "$plugin" == raftkit-qa ]]; then
    ! grep -qE '\.mjs\b' "$f"
    check "S11 $key (Claude apps, no shell) never invokes a .mjs script" ok $?
  fi
done

# --- repo-wide invariants ---
agreement=plugins/raftkit-core/skills/working-agreement/references/working-agreement.md
[[ "$(shasum -a 256 "$agreement" | cut -d' ' -f1)" == "$(jsonq '.working_agreement_sha256')" ]]
check "S12 the working agreement matches its pinned sha256 (edits are deliberate, cleared with Ashit)" ok $?

body_words="$(tail -n +3 "$agreement" | wc -w | tr -d ' ')"
[[ "$body_words" -le 310 ]]
check "S13 the working agreement body is within 310 words ($body_words)" ok $?

node -e '
  const fs=require("fs"); const j=JSON.parse(fs.readFileSync("plugins/raftkit-core/hooks/lib/refusals.json","utf8"));
  const strict=JSON.parse(fs.readFileSync("tests/budgets.json","utf8")).strict;
  let bad=0;
  for (const r of j.refusals) {
    if (!new RegExp(r.pattern,"m").test(r.example)) { console.error("example does not match pattern:", r.id); bad++; }
    if (r.id==="generic-cant") continue;
    const p="plugins/"+r.source;
    if (!fs.existsSync(p)) { console.error("source missing:", r.id, p); bad++; continue; }
    // the pin is only worth having if the string it pins is still emitted
    if (!new RegExp(r.pattern,"m").test(fs.readFileSync(p,"utf8"))) { console.error("pattern matches nothing in its source:", r.id, p); bad++; }
  }
  process.exit(bad?1:0);
'
check "S14 every refusals.json rule matches its example and is still emitted by its source" ok $?

if [[ "$strict" == true ]]; then
  unlisted=""
  for d in plugins/raftkit-core/skills/*/ plugins/raftkit-pm/skills/*/ plugins/raftkit-dev/skills/*/ plugins/raftkit-qa/skills/*/; do
    key="$(basename "$(dirname "$(dirname "$d")")")/$(basename "$d")"
    grep -qxF "$key" <<<"$listed" || unlisted="$unlisted $key"
  done
  [[ -z "$unlisted" ]]; check "S15 strict: every skill on disk has a budget entry${unlisted:+ (missing:$unlisted)}" ok $?

  for plugin in raftkit-core raftkit-pm raftkit-dev raftkit-qa raftkit-docs; do
    cap="$(node -e "process.stdout.write(String(Math.floor($(jsonq ".plugins[\"$plugin\"]")*$headroom)))")"
    n="$(find "plugins/$plugin/skills" -name '*.md' -type f -print0 | xargs -0 cat | wc -w | tr -d ' ')"
    [[ "$n" -le "$cap" ]]; check "S16 strict: $plugin skills total within budget ($n <= $cap words)" ok $?
  done

  ! grep -rlE '1194107417268910|1216778429401199|1215260732424760' plugins --include='*.md' | grep -v 'raftkit-core/skills/rules/' | grep -q .
  check "S17 strict: GIDs appear only in raftkit-core/skills/rules" ok $?
fi

echo
echo "structure: ${#present[@]} skill(s) checked, $failures failure(s)"
[[ "$failures" -eq 0 ]]
