#!/usr/bin/env bash
# Contract suite for the plain-language guardrail (raftkit board — plain
# English output across all skills).
#
# The checker (scripts/check-plain-language.mjs) scans every ```output
# fenced block repo-wide for banned filler (word-boundary matched,
# case-insensitive), over-length sentences (measured after rejoining
# hard-wrapped lines, regardless of how the next line is cased),
# block-average sentence length, named or
# numeric HTML entities, correctly nested inner code fences, an
# unterminated fence (whose content is still checked, not dropped), and a
# leaked internal-only label (WEESLD, any case, word-boundary matched).
# This suite pins: the contract exists in raftkit-core:rules, the real repo
# content is clean, and — so a green run here is trustworthy, not a rubber
# stamp — each negative-control fixture deliberately fails exactly the rule
# it names (with the exact exit code and violation text asserted, not just
# "nonzero"), and each positive-control fixture deliberately passes. It no
# longer requires every skill to restate the guardrail (v2 inherits it) and
# no longer pins a minimum skill or output-block count.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

failures=0
check() { # <name> <expected: ok|fail> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}
check_exit() { # <name> <expected exit code> <actual exit code>
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected exit $expected, got $actual)"
    failures=$((failures + 1))
  fi
}
check_contains() { # <name> <haystack> <needle>
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected output to contain: $needle)"
    failures=$((failures + 1))
  fi
}

RULES=plugins/raftkit-core/skills/rules/SKILL.md
REF=plugins/raftkit-core/skills/rules/references/plain-language.md

# --- CONTRACT: rules names it, plain-language.md carries it ---

grep -qF '## Plain output' "$RULES" && grep -qF 'plain-language.md' "$RULES"
check "PL1 rules names the plain-language contract and links the reference" ok $?

[[ -f "$REF" ]]
check "PL2 plain-language.md exists" ok $?

grep -qF '## Banned phrases' "$REF" && grep -qF '## Never shown to a human' "$REF" && grep -qF '```output' "$REF"
check "PL3 plain-language.md carries the banned list, the WEESLD carve-out, and the output-fence convention" ok $?

# --- CHECKER: exists, is itself valid JS, and its usage/target errors are
# distinguishable from "clean" and from "violations found" ---

CHECKER=scripts/check-plain-language.mjs
[[ -f "$CHECKER" ]]
check "PL6a checker script exists" ok $?

node --check "$CHECKER" >/dev/null 2>&1
check "PL6b checker script is syntactically valid" ok $?

node "$CHECKER" >/dev/null 2>&1
check_exit "PL6c no target given exits 2 (a usage error, never 'clean')" 2 $?

out="$(node "$CHECKER" "tests/fixtures/plain-language/does-not-exist.md" 2>&1)"; code=$?
check_exit "PL6d a nonexistent target exits 2 (never mistaken for 'violations found')" 2 "$code"
check_contains "PL6d reports which target it couldn't read" "$out" "cannot read target"

FIX=tests/fixtures/plain-language


# --- NEGATIVE CONTROLS: prove the checker actually catches problems ---
#
# Each assertion pins the exact exit code (1, not merely "nonzero" — a bad
# target also exits nonzero, at 2, and that must not read as a pass here)
# and the specific violation text, not just that *something* failed.

out="$(node "$CHECKER" "$FIX/bad-banned-phrase.md" 2>&1)"; code=$?
check_exit "PL7a rejects a banned filler phrase (exit 1)" 1 "$code"
check_contains "PL7a names the phrase" "$out" 'banned phrase "leverage"'

out="$(node "$CHECKER" "$FIX/bad-long-sentence.md" 2>&1)"; code=$?
check_exit "PL7b rejects a sentence over 25 words (exit 1)" 1 "$code"
check_contains "PL7b reports the word count" "$out" "sentence over 25 words (34)"

out="$(node "$CHECKER" "$FIX/bad-weesld-leak.md" 2>&1)"; code=$?
check_exit "PL7c rejects a leaked WEESLD label (exit 1)" 1 "$code"
check_contains "PL7c names the leaked label" "$out" 'internal-only label "WEESLD"'

out="$(node "$CHECKER" "$FIX/bad-html-entity.md" 2>&1)"; code=$?
check_exit "PL7d rejects a named HTML entity (exit 1)" 1 "$code"
check_contains "PL7d names the entity violation" "$out" "HTML entity found"

out="$(node "$CHECKER" "$FIX/bad-numeric-entity.md" 2>&1)"; code=$?
check_exit "PL7h rejects a numeric HTML entity (exit 1)" 1 "$code"
check_contains "PL7h names the entity violation" "$out" "HTML entity found"

node "$CHECKER" "$FIX/good.md" >/dev/null 2>&1
check_exit "PL7e accepts a compliant output block, no over-firing (exit 0)" 0 $?

out="$(node "$CHECKER" "$FIX/bad-unterminated-fence.md" 2>&1)"; code=$?
check_exit "PL7f rejects an unterminated \`\`\`output fence (exit 1)" 1 "$code"
check_contains "PL7f names it as unterminated" "$out" "unterminated"
check_contains "PL7m an unterminated fence's content is still checked, not dropped" "$out" 'internal-only label "WEESLD"'

out="$(node "$CHECKER" "$FIX/bad-nested-fence.md" 2>&1)"; code=$?
check_exit "PL7g rejects a violation hidden behind two levels of nested code fence (exit 1)" 1 "$code"
check_contains "PL7g still finds the violation past both inner fences" "$out" 'banned phrase "leverage"'

out="$(node "$CHECKER" "$FIX/bad-block-average.md" 2>&1)"; code=$?
check_exit "PL7i rejects a block averaging over 15 words/sentence (exit 1)" 1 "$code"
check_contains "PL7i reports the block average, not the per-sentence cap" "$out" "block averages"

out="$(node "$CHECKER" "$FIX/bad-lowercase-weesld.md" 2>&1)"; code=$?
check_exit "PL7j rejects a lowercase weesld leak (exit 1)" 1 "$code"
check_contains "PL7j names the leaked label regardless of case" "$out" 'internal-only label "WEESLD"'

node "$CHECKER" "$FIX/good-boundaries.md" >/dev/null 2>&1
check_exit "PL7k accepts near-miss words that only contain a banned phrase as a substring (exit 0)" 0 $?

out="$(node "$CHECKER" "$FIX/bad-wrapped-long-sentence.md" 2>&1)"; code=$?
check_exit "PL7l rejects a >25-word sentence hard-wrapped across lines, next line lowercase (exit 1)" 1 "$code"
check_contains "PL7l reports the word count" "$out" "sentence over 25 words (39)"

# PL7n covers a real bug in an earlier join heuristic: a wrap was only
# treated as a continuation when the next line started lowercase, so a
# sentence wrapped right before a capitalized word or acronym escaped the
# cap entirely. The join condition no longer looks at the next line's case.
out="$(node "$CHECKER" "$FIX/bad-wrapped-uppercase-sentence.md" 2>&1)"; code=$?
check_exit "PL7n rejects a >25-word sentence wrapped before a capitalized continuation (exit 1)" 1 "$code"
check_contains "PL7n reports the word count" "$out" "sentence over 25 words (32)"

# --- REAL CONTENT: every existing output block in the repo passes ---

real_out="$(node "$CHECKER" plugins 2>&1)"
real_exit=$?
[[ "$real_exit" -eq 0 ]]
check "PL8 every existing output-fenced block in plugins/ passes the checker" ok $?
[[ "$real_exit" -ne 0 ]] && echo "$real_out"

grep -qE '^checked [0-9]+ output block' <<<"$real_out"
check "PL9 the checker actually scanned blocks, not a silent zero-match pass" ok $?

# The floor is the real measured count at merge time (59, via both the
# checker's own tally and `grep -rEc '^[[:space:]]*```output[[:space:]]*$'
# plugins/`), minus a small safety margin -- not a stale number carried
# over from either branch this suite was built from.

# --- EVAL BUNDLE: cases live with the plugin whose skill they exercise ---
#
# A case is run by `claude plugin eval <plugin>`, which loads only that plugin.
# A prompt that says "you are running raftkit-pm:estimate" therefore has to sit
# under raftkit-pm, or the skill under test is not loaded and the model
# improvises. A case's graders/skill-fired.md (a tool_used grader on Skill)
# names the skill under test the same way. These checks pin placement for every
# case under plugins/*/evals/<group>/<case>, not only the plain-language ones.

total=0
misplaced=""
fired=""
while IFS= read -r d; do
  [[ "$d" == */evals/plain-language/* ]] && total=$((total + 1))
  [[ -f "$d/prompt.md" ]] || misplaced="$misplaced $d(no-prompt)"
  ls "$d"/graders/*.md >/dev/null 2>&1 || misplaced="$misplaced $d(no-grader)"
  owner="$(sed -n 's/.*\(raftkit-[a-z]*\):[a-z-]*.*/\1/p' "$d/prompt.md" 2>/dev/null | head -1)"
  plugin="$(printf '%s' "$d" | sed -E 's|plugins/([^/]+)/evals/.*|\1|')"
  [[ -z "$owner" || "$owner" == "$plugin" ]] || misplaced="$misplaced $d(names-$owner)"
  if [[ -f "$d/graders/skill-fired.md" ]]; then
    g="$d/graders/skill-fired.md"
    skill="$(sed -n "s/^input_match: .*)?\([a-z][a-z-]*\)\"'\$/\1/p" "$g" | head -1)"
    grep -qx 'type: tool_used' "$g" && grep -qx 'tool: Skill' "$g" && [[ -n "$skill" && -d "plugins/$plugin/skills/$skill" ]] \
      && fired="$fired $plugin/$skill" || misplaced="$misplaced $d(skill-fired-${skill:-unparsed})"
  fi
done < <(find plugins -mindepth 4 -maxdepth 4 -type d -path 'plugins/*/evals/*' -not -path '*/evals/results/*' -not -path '*/evals/mocks/*' | sort)

[[ "$total" -ge 6 ]]
check "PL11 >=6 plain-language eval cases across the plugins" ok $?
[[ -z "$misplaced" ]]
check "PL12 every eval case has a prompt and grader and sits with the plugin it names" ok $?
[[ -n "$misplaced" ]] && echo "  misplaced:$misplaced"

# A prompt without frontmatter gets zero tools, so the skill never loads and the
# case scores 0 for a harness reason, not a skill reason.
nofm=""
for p in plugins/*/evals/*/*/prompt.md; do
  fmp="$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' "$p")"
  grep -qE '^max_turns: [1-9][0-9]*$' <<<"$fmp" && grep -qE '^allowed_tools: \[.*\bSkill\b.*\]$' <<<"$fmp" || nofm="$nofm $p"
done
[[ -z "$nofm" ]]
check "PL13 every eval prompt declares max_turns and allowed_tools including Skill" ok $?
[[ -n "$nofm" ]] && echo "  missing:$nofm"

# Every grader and prompt parses under the harness schema (claude 2.1.280:
# `claude plugin eval` validates the same keys strictly and compiles regex
# patterns with JS RegExp), so a typo fails here, not in a paid run.
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
  // a shell echo that expands \b writes a backspace, which still compiles as a regex
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
const root = "plugins";
for (const plugin of fs.readdirSync(root)) {
  const evals = path.join(root, plugin, "evals");
  if (!fs.existsSync(evals)) continue;
  for (const group of fs.readdirSync(evals)) {
    if (group === "results" || group === "mocks") continue;
    for (const c of fs.readdirSync(path.join(evals, group))) {
      const dir = path.join(evals, group, c);
      try {
        const p = parse(path.join(dir, "prompt.md"));
        if (!p) throw new Error("prompt.md has no frontmatter");
        for (const k of Object.keys(p.fm)) if (!PROMPT.has(k)) throw new Error(`prompt.md: unknown key ${k}`);
        if (!Number.isInteger(p.fm.max_turns) || p.fm.max_turns < 1 || p.fm.max_turns > 200) throw new Error("prompt.md: max_turns out of range");
        if (!p.body) throw new Error("prompt.md: empty prompt");
        for (const g of fs.readdirSync(path.join(dir, "graders"))) {
          const gf = path.join(dir, "graders", g), where = `${g}`;
          const r = parse(gf);
          if (!r) throw new Error(`${where}: no frontmatter, so the harness skips it`);
          const { fm, body } = r, keys = KEYS[fm.type];
          if (!keys) throw new Error(`${where}: type must be one of ${Object.keys(KEYS).join(" | ")}`);
          for (const k of Object.keys(fm)) if (!["type","name","weight","arm",...keys].includes(k)) throw new Error(`${where}: unknown key ${k} for type ${fm.type}`);
          if (fm.weight !== undefined && !(fm.weight > 0)) throw new Error(`${where}: weight must be positive`);
          if (fm.arm !== undefined && !["with-only","both"].includes(fm.arm)) throw new Error(`${where}: bad arm`);
          if (fm.type === "regex") {
            const pattern = fm.pattern ?? body, flags = fm.flags ?? "", match = fm.match ?? "contains";
            if (!pattern) throw new Error(`${where}: no pattern`);
            if (!/^[dgimsuvy]*$/.test(flags)) throw new Error(`${where}: bad flags ${flags}`);
            new RegExp(pattern, flags);
            if (!/^(contains|not_contains|count:\d+)$/.test(match)) throw new Error(`${where}: bad match ${match}`);
            if (fm.target !== undefined && !TARGETS.has(fm.target)) throw new Error(`${where}: bad target ${fm.target}`);
          }
          if (fm.type === "tool_used") {
            if (typeof fm.tool !== "string" || !fm.tool) throw new Error(`${where}: no tool`);
            if (fm.input_match !== undefined) new RegExp(fm.input_match);
            for (const k of ["min","max"]) if (fm[k] !== undefined && !(Number.isInteger(fm[k]) && fm[k] >= 0)) throw new Error(`${where}: bad ${k}`);
          }
          if ((fm.type === "llm" || fm.type === "baseline") && !(fm.criteria ?? body)) throw new Error(`${where}: no criteria`);
          if (/TODO: describe/.test(fm.criteria ?? fm.pattern ?? body)) throw new Error(`${where}: still the blank init template`);
        }
      } catch (e) { bad.push(`${dir}: ${e.message}`); }
    }
  }
}
if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
NODE
check "PL14 every eval prompt and grader parses under the harness schema, and every regex compiles" ok $?

# Countable criteria are graded by the harness's native regex graders, free and
# exact; an LLM judge is kept for what needs judgment. An llm grader that still
# asks about the watermark, the STOP line, the output fence, the banned-phrase
# list, the internal label or the sentence cap is a countable criterion on a paid judge.
counted=""
for g in plugins/*/evals/*/*/graders/*.md; do
  grep -qx 'type: llm' "$g" || continue
  grep -qE 'Requires founder review|\*\*STOP\*\*|[Oo]utput fence|```output|utilize|WEESLD|25 words' "$g" && counted="$counted $g"
done
[[ -z "$counted" ]]
check "PL15 no llm grader carries a countable criterion" ok $?
[[ -n "$counted" ]] && echo "  countable:$counted"

# v2 cut the plain-language glossary; a grader citing it grades a rule that no
# longer exists.
! grep -lis 'glossary' plugins/*/evals/*/*/graders/*.md | grep -q .
check "PL16 no grader cites the plain-language glossary v2 removed" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
