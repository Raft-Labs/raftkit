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
# Tokens are ceil(chars/4), a model-agnostic estimate: words undercount them.
ctoks() { node -e 'let s="";process.stdin.setEncoding("utf8").on("data",d=>s+=d).on("end",()=>process.stdout.write(String(Math.ceil([...s].length/4))))'; }
words() { cat "$@" 2>/dev/null | wc -w | tr -d ' '; }
tokens() { cat "$@" 2>/dev/null | ctoks; }
# assets/ holds payloads shipped verbatim into a client repo, outside the skill's
# own budget; the ones a model reads (all but templates/) are budgeted per file.
mdcat() { find "$1" -name '*.md' -type f -not -path '*/assets/*' -print0 | xargs -0 cat 2>/dev/null; }
mdwords() { mdcat "$1" | wc -w | tr -d ' '; }
mdtokens() { mdcat "$1" | ctoks; }
plugincat() { find "plugins/$1/skills" -name '*.md' -type f -print0 | xargs -0 cat; }
cap() { node -e 'const b=+process.argv[1]; process.stdout.write(b>0?String(Math.floor(b*process.argv[2])):"none")' "$1" "$headroom"; }
fits() { [[ "$1" =~ ^[1-9][0-9]*$ && "$2" =~ ^[0-9]+$ ]] && (( $1 <= $2 )); } # <count> <cap>: a missing count or budget fails
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

  c="$(cap "$(jsonq ".skills[\"$key\"].skill_md")")"; n="$(words "$f")"; fits "$n" "$c"
  check "S4 $key SKILL.md within budget ($n <= $c words)" ok $?
  c="$(cap "$(jsonq ".skills[\"$key\"].skill_md_tokens")")"; n="$(tokens "$f")"; fits "$n" "$c"
  check "S4t $key SKILL.md within budget ($n <= $c tokens)" ok $?

  c="$(cap "$(jsonq ".skills[\"$key\"].total")")"; n="$(mdwords "$dir")"; fits "$n" "$c"
  check "S5 $key directory within budget ($n <= $c words)" ok $?
  c="$(cap "$(jsonq ".skills[\"$key\"].total_tokens")")"; n="$(mdtokens "$dir")"; fits "$n" "$c"
  check "S5t $key directory within budget ($n <= $c tokens)" ok $?

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
    # Any 16-digit Asana GID, not only the three constants: a decision or task
    # GID in a skill goes stale the same way.
    ! grep -rqE '(^|[^0-9])1[0-9]{15}([^0-9]|$)' "$dir"
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
  for d in plugins/raftkit-core/skills/*/ plugins/raftkit-pm/skills/*/ plugins/raftkit-dev/skills/*/ plugins/raftkit-qa/skills/*/ plugins/raftkit-hasura/skills/*/ plugins/raftkit-docs/skills/*/; do
    key="$(basename "$(dirname "$(dirname "$d")")")/$(basename "$d")"
    grep -qxF "$key" <<<"$listed" || unlisted="$unlisted $key"
  done
  [[ -z "$unlisted" ]]; check "S15 strict: every skill on disk has a budget entry${unlisted:+ (missing:$unlisted)}" ok $?

  for plugin in raftkit-core raftkit-pm raftkit-dev raftkit-qa raftkit-docs raftkit-hasura; do
    c="$(cap "$(jsonq ".plugins[\"$plugin\"]")")"; n="$(plugincat "$plugin" | wc -w | tr -d ' ')"; fits "$n" "$c"
    check "S16 strict: $plugin skills total within budget ($n <= $c words)" ok $?
    c="$(cap "$(jsonq ".plugin_tokens[\"$plugin\"]")")"; n="$(plugincat "$plugin" | ctoks)"; fits "$n" "$c"
    check "S16t strict: $plugin skills total within budget ($n <= $c tokens)" ok $?
  done

  ! grep -rlE '1194107417268910|1216778429401199|1215260732424760' plugins --include='*.md' | grep -v 'raftkit-core/skills/rules/' | grep -q .
  check "S17 strict: GIDs appear only in raftkit-core/skills/rules" ok $?
fi

# Model-read files outside any skill's budget carry their own entry in `files`:
# the commands and every assets/ markdown file except the doc templates.
budgeted="$( { ls plugins/*/commands/*.md 2>/dev/null; find plugins -path '*/assets/*' -name '*.md' -type f -not -path '*/assets/templates/*'; node -e 'console.log(Object.keys(JSON.parse(require("fs").readFileSync("tests/budgets.json","utf8")).files||{}).join("\n"))'; } | grep . | sort -u)"
nfiles=0
for f in $budgeted; do
  nfiles=$((nfiles + 1))
  [[ -f "$f" ]]; check "S18 budgeted file exists: $f" ok $?
  c="$(cap "$(jsonq ".files?.[\"$f\"]?.words")")"; n="$(words "$f")"; fits "$n" "$c"
  check "S19 $f within budget ($n <= $c words)" ok $?
  c="$(cap "$(jsonq ".files?.[\"$f\"]?.tokens")")"; n="$(tokens "$f")"; fits "$n" "$c"
  check "S19t $f within budget ($n <= $c tokens)" ok $?
  if [[ "$f" == */commands/* ]]; then
    desc_words="$(fm "$f" | sed -n 's/^description: *//p' | head -1 | wc -w | tr -d ' ')"
    [[ "$desc_words" -ge 1 && "$desc_words" -le 60 ]]
    check "S20 $f description is 1-60 words ($desc_words)" ok $?
  fi
done


# --- eval bundle: policy cases plus one trigger case per skill ---
# `claude plugin eval <plugin>` loads only that plugin, so a case sits with the
# plugin whose skill it exercises. Groups are `policy` (a guarantee) and
# `trigger` (the right skill fires for a typical request); nothing else.
cases="$(find plugins -mindepth 4 -maxdepth 4 -type d -path 'plugins/*/evals/*' -not -path '*/evals/results/*' -not -path '*/evals/mocks/*' | sort)"
npolicy=0; bad=""; fired=""
while IFS= read -r d; do
  [[ -n "$d" ]] || continue
  plugin="$(cut -d/ -f2 <<<"$d")"; group="$(cut -d/ -f4 <<<"$d")"; name="$(cut -d/ -f5 <<<"$d")"
  case "$group" in
    policy) npolicy=$((npolicy + 1)) ;;
    trigger)
      g="$d/graders/skill-fired.md"
      skill="$(sed -n "s/^input_match: .*)?\([a-z][a-z-]*\)\"'\$/\1/p" "$g" 2>/dev/null | head -1)"
      if grep -qx 'type: tool_used' "$g" 2>/dev/null && grep -qx 'tool: Skill' "$g" && [[ "$skill" == "$name" && -d "plugins/$plugin/skills/$skill" ]]; then
        fired="$fired $plugin/$skill"
      else
        bad="$bad $d(trigger-grader)"
      fi ;;
    *) bad="$bad $d(group)" ;;
  esac
  [[ -f "$d/prompt.md" ]] || bad="$bad $d(no-prompt)"
  ls "$d"/graders/*.md >/dev/null 2>&1 || bad="$bad $d(no-grader)"
  owner="$(sed -n 's/.*\(raftkit-[a-z]*\):[a-z-]*.*/\1/p' "$d/prompt.md" 2>/dev/null | head -1)"
  [[ -z "$owner" || "$owner" == "$plugin" ]] || bad="$bad $d(names-$owner)"
done <<<"$cases"
[[ -z "$bad" ]]; check "E1 every eval case is policy/ or trigger/, has a prompt and a grader, and sits with its plugin${bad:+ (bad:$bad)}" ok $?
[[ "$npolicy" -ge 10 && "$npolicy" -le 14 ]]; check "E2 about twelve policy cases ($npolicy)" ok $?

uncovered=""
for s in plugins/*/skills/*/; do
  key="$(basename "$(dirname "$(dirname "$s")")")/$(basename "$s")"
  [[ " $fired " == *" $key "* ]] || uncovered="$uncovered $key"
done
[[ -z "$uncovered" ]]; check "E3 every skill has one trigger case whose skill-fired grader names it${uncovered:+ (uncovered:$uncovered)}" ok $?

# Mocks only: a case gets no tool that writes or reaches a network, and a
# prompt without frontmatter gets no tools at all, so its skill never loads.
nofm=""
for p in plugins/*/evals/*/*/prompt.md; do
  fmp="$(fm "$p")"
  grep -qE '^max_turns: [1-9][0-9]*$' <<<"$fmp" && grep -qE '^allowed_tools: \[.*\bSkill\b.*\]$' <<<"$fmp" \
    && ! grep -qE '^allowed_tools: .*\b(Bash|Write|Edit|NotebookEdit|WebFetch|WebSearch)\b' <<<"$fmp" || nofm="$nofm $p"
done
[[ -z "$nofm" ]]; check "E4 every eval prompt declares max_turns and read-only allowed_tools with Skill${nofm:+ (bad:$nofm)}" ok $?

# The harness schema (`claude plugin eval` validates keys strictly and compiles
# regex with JS RegExp), so a typo fails here, not in a paid run.
node - <<'NODE'
const fs = require("fs"), path = require("path");
const PROMPT = new Set(["schema_version","name","description","tags","plugins","runs","expected_outcome","model","max_turns","timeout_seconds","allowed_tools","artifact_publish","growthbook_overrides","append_system_prompt","env"]);
const KEYS = {
  regex: ["target","pattern","flags","match"], tool_order: ["before","after"],
  tool_used: ["tool","input_match","min","max"], file_exists: ["path","exists"],
  llm: ["criteria","focus"], baseline: ["baseline_file","criteria"],
};
const TARGETS = new Set(["last_message","trace","files","mock_calls"]);
function scalar(v) {
  if (/^'.*'$/.test(v)) {
    const inner = v.slice(1, -1);
    if (inner.replace(/''/g, "").includes("'")) throw new Error(`single-quoted value holds a bare ' (YAML needs ''): ${v}`);
    return inner.replace(/''/g, "'");
  }
  if (/^".*"$/.test(v)) return JSON.parse(v);
  if (/^\[.*\]$/.test(v)) return v.slice(1, -1).split(",").map((s) => scalar(s.trim())).filter((s) => s !== "");
  if (/^-?\d+(\.\d+)?$/.test(v)) return Number(v);
  if (v === "true" || v === "false") return v === "true";
  return v;
}
function parse(file) {
  const src = fs.readFileSync(file, "utf8");
  if (/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(src)) throw new Error(`${path.basename(file)}: control character`);
  const m = src.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) return null;
  const fm = {};
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^([a-z_]+): (.*)$/);
    if (!kv) throw new Error(`unparseable frontmatter line: ${line}`);
    fm[kv[1]] = scalar(kv[2].trim());
  }
  return { fm, body: m[2].trim() };
}
const bad = [];
for (const plugin of fs.readdirSync("plugins")) {
  const evals = path.join("plugins", plugin, "evals");
  if (!fs.existsSync(evals)) continue;
  for (const group of fs.readdirSync(evals)) {
    if (group === "results" || group === "mocks" || !fs.statSync(path.join(evals, group)).isDirectory()) continue;
    for (const c of fs.readdirSync(path.join(evals, group))) {
      const dir = path.join(evals, group, c);
      try {
        const p = parse(path.join(dir, "prompt.md"));
        if (!p) throw new Error("prompt.md has no frontmatter");
        for (const k of Object.keys(p.fm)) if (!PROMPT.has(k)) throw new Error(`prompt.md: unknown key ${k}`);
        if (!Number.isInteger(p.fm.max_turns) || p.fm.max_turns < 1 || p.fm.max_turns > 200) throw new Error("prompt.md: max_turns out of range");
        if (!p.body) throw new Error("prompt.md: empty prompt");
        for (const g of fs.readdirSync(path.join(dir, "graders"))) {
          const r = parse(path.join(dir, "graders", g));
          if (!r) throw new Error(`${g}: no frontmatter, so the harness skips it`);
          const { fm, body } = r, keys = KEYS[fm.type];
          if (!keys) throw new Error(`${g}: type must be one of ${Object.keys(KEYS).join(" | ")}`);
          for (const k of Object.keys(fm)) if (!["type","name","weight","arm",...keys].includes(k)) throw new Error(`${g}: unknown key ${k} for type ${fm.type}`);
          if (fm.weight !== undefined && !(fm.weight > 0)) throw new Error(`${g}: weight must be positive`);
          if (fm.arm !== undefined && !["with-only","both"].includes(fm.arm)) throw new Error(`${g}: bad arm`);
          if (fm.type === "regex") {
            const pattern = fm.pattern ?? body, flags = fm.flags ?? "", match = fm.match ?? "contains";
            if (!pattern) throw new Error(`${g}: no pattern`);
            if (!/^[dgimsuvy]*$/.test(flags)) throw new Error(`${g}: bad flags ${flags}`);
            new RegExp(pattern, flags);
            if (!/^(contains|not_contains|count:\d+)$/.test(match)) throw new Error(`${g}: bad match ${match}`);
            if (fm.target !== undefined && !TARGETS.has(fm.target)) throw new Error(`${g}: bad target ${fm.target}`);
          }
          if (fm.type === "tool_used") {
            if (typeof fm.tool !== "string" || !fm.tool) throw new Error(`${g}: no tool`);
            if (fm.input_match !== undefined) new RegExp(fm.input_match);
            for (const k of ["min","max"]) if (fm[k] !== undefined && !(Number.isInteger(fm[k]) && fm[k] >= 0)) throw new Error(`${g}: bad ${k}`);
          }
          if ((fm.type === "llm" || fm.type === "baseline") && !(fm.criteria ?? body)) throw new Error(`${g}: no criteria`);
          if (/TODO: describe/.test(fm.criteria ?? fm.pattern ?? body)) throw new Error(`${g}: still the blank init template`);
        }
      } catch (e) { bad.push(`${dir}: ${e.message}`); }
    }
  }
}
if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
NODE
check "E5 every eval prompt and grader parses under the harness schema, and every regex compiles" ok $?

# scripts/check-plain-language.mjs owns banned phrases, sentence length, the
# output fence and the internal label; a grader repeating it is a second copy.
# Countable criteria go to native regex graders, not a paid llm judge.
dup=""; counted=""
for g in plugins/*/evals/*/*/graders/*.md; do
  [[ -f "$g" ]] || continue
  grep -qiE 'utilize|leverage|WEESLD|```output|\{25\}|25 words|glossary' "$g" && dup="$dup $g"
  grep -qx 'type: llm' "$g" && grep -qE 'Requires founder review|\*\*STOP\*\*' "$g" && counted="$counted $g"
done
[[ -z "$dup" ]]; check "E6 no eval grader duplicates check-plain-language.mjs${dup:+ (dup:$dup)}" ok $?
[[ -z "$counted" ]]; check "E7 no llm grader carries a countable criterion${counted:+ (countable:$counted)}" ok $?

grep -qF 'claude plugin eval' docs/maintainers/evals.md 2>/dev/null && grep -qF -- '--allow-real-servers' docs/maintainers/evals.md
check "E8 docs/maintainers/evals.md says how to run the evals, and never with real servers" ok $?

echo
echo "structure: ${#present[@]} skill(s) and $nfiles file(s) checked, $failures failure(s)"
[[ "$failures" -eq 0 ]]
