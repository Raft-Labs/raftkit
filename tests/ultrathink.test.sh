#!/usr/bin/env bash
# Deterministic contract suite for raftkit-dev:ultrathink.
# The source REASONING_PLAYBOOK.md is a read-only input; the skill ships a
# byte-identical bundled reference so installed plugins remain self-contained.
set -uo pipefail
cd "$(dirname "$0")/.."

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

SKILL=plugins/raftkit-dev/skills/ultrathink
S=$SKILL/SKILL.md
REF=$SKILL/references/reasoning-playbook.md
SOURCE_SHA=1e163383124f526c865b478d9c353ae996cc81eb98120b9f1eb7d8c5f62cb1f6

[[ -f "$S" && -f "$REF" ]]
check "P1 skill and bundled playbook reference exist" ok $?

if [[ -f "$REF" ]]; then
  [[ "$(shasum -a 256 "$REF" | awk '{print $1}')" == "$SOURCE_SHA" ]]
else
  false
fi
check "P2 bundled playbook is the approved byte-identical source snapshot" ok $?

# The authoring source is intentionally not required in a packaged checkout,
# but when present it must remain exactly the source snapshot used above.
if [[ -f REASONING_PLAYBOOK.md ]]; then
  [[ "$(shasum -a 256 REASONING_PLAYBOOK.md | awk '{print $1}')" == "$SOURCE_SHA" ]]
else
  true
fi
check "P3 root reasoning playbook remains unchanged when present" ok $?

grep -q '^name: ultrathink$' "$S" 2>/dev/null \
  && grep -q '^user-invocable: true$' "$S" 2>/dev/null \
  && grep -qiE 'think this through|make a plan|compare approaches|plan before' "$S" 2>/dev/null
check "P4 frontmatter exposes a user-invocable thinking and planning skill" ok $?

grep -q 'raftkit-dev:capability-preflight' "$S" 2>/dev/null \
  && grep -q 'superpowers:brainstorming' "$S" 2>/dev/null \
  && grep -q 'superpowers:writing-plans' "$S" 2>/dev/null
check "P5 scoped provider seams are explicit and preflight-owned" ok $?

node - "$S" <<'NODE'
const fs = require("fs");
const p = process.argv[2];
if (!p || !fs.existsSync(p)) process.exit(1);
const s = fs.readFileSync(p, "utf8");
const marks = [
  "raftkit-dev:capability-preflight",
  "Gather and label evidence",
  "superpowers:brainstorming",
  "Compare consequential approaches",
  "superpowers:writing-plans",
  "Plan-approval gate",
];
let last = -1;
for (const mark of marks) {
  const at = s.indexOf(mark);
  if (at < 0 || at <= last) process.exit(1);
  last = at;
}
NODE
check "P6 preflight, evidence, brainstorming, comparison, planning, approval occur in order" ok $?

missing=0
for label in Confirmed 'Strongly supported' Inferred Assumed Unknown Contradicted; do
  grep -q "$label" "$S" 2>/dev/null || { echo "missing epistemic label: $label"; missing=1; }
done
[[ "$missing" -eq 0 ]]
check "P7 all six epistemic labels survive into the skill contract" ok $?

missing=0
for risk in 'blast radius' reversibility 'interacting parts' uncertainty; do
  grep -qi "$risk" "$S" 2>/dev/null || { echo "missing risk factor: $risk"; missing=1; }
done
[[ "$missing" -eq 0 ]]
check "P8 planning depth is calibrated by the playbook risk factors" ok $?

missing=0
for field in Goal 'Current known state' Unknowns Assumptions Steps Dependencies Risks Verification 'Completion criteria' 'Rollback/recovery'; do
  grep -q "$field" "$S" 2>/dev/null || { echo "missing plan field: $field"; missing=1; }
done
[[ "$missing" -eq 0 ]]
check "P9 output contract preserves every universal plan field" ok $?

grep -qi 'small task' "$S" 2>/dev/null \
  && grep -qi 'substantial task' "$S" 2>/dev/null \
  && grep -qi 'proportionate' "$S" 2>/dev/null
check "P10 small and substantial tasks receive proportionate planning" ok $?

grep -qi 'private.*chain-of-thought\|hidden reasoning' "$S" 2>/dev/null \
  && grep -qi 'decision-relevant rationale\|decision record' "$S" 2>/dev/null
check "P11 output exposes evidence and decisions, never hidden reasoning" ok $?

grep -q 'references/reasoning-playbook.md' "$S" 2>/dev/null \
  && grep -q 'Section 17' "$S" 2>/dev/null \
  && grep -q 'Section 16' "$S" 2>/dev/null \
  && grep -q 'rg -n' "$S" 2>/dev/null
check "P12 progressive-disclosure routing names the bundled playbook and heading search" ok $?

grep -qi 'never execute\|does not execute' "$S" 2>/dev/null \
  && grep -qi 'explicit.*approval' "$S" 2>/dev/null \
  && grep -qi 'owner-shaped\|decision owner' "$S" 2>/dev/null
check "P13 planning stops before execution and preserves decision ownership" ok $?

if [[ -f "$S" ]]; then
  [[ "$(wc -l < "$S" | tr -d ' ')" -lt 500 ]]
else
  false
fi
check "P14 SKILL.md stays below the progressive-disclosure limit" ok $?

! grep -rE '/Users/|file://' "$SKILL" 2>/dev/null | grep -q .
check "P15 shipped skill contains no machine-specific path" ok $?

node - <<'NODE'
const fs = require("fs");
const manifestPath = "plugins/raftkit-dev/.claude-plugin/plugin.json";
const marketPath = ".claude-plugin/marketplace.json";
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const market = JSON.parse(fs.readFileSync(marketPath, "utf8"));
const version = manifest.version.split(".").map(Number);
const minimum = [0, 16, 0];
const cmp = version[0] - minimum[0] || version[1] - minimum[1] || version[2] - minimum[2];
const entry = market.plugins.find((p) => p.name === "raftkit-dev");
if (cmp < 0 || !entry || entry.description !== manifest.description || !/thinking|planning/i.test(manifest.description)) process.exit(1);
NODE
check "P16 manifest version and marketplace description expose the new skill in lockstep" ok $?

eval_count=$(find plugins/raftkit-dev/evals/ultrathink -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/ultrathink -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/ultrathink -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "P17 at least eight eval cases each include a prompt and grader" ok $?

! grep -rE 'Plan-approval gate|superpowers:brainstorming|Strongly supported.*Inferred.*Assumed' \
  plugins/raftkit-dev/evals/ultrathink/*/prompt.md 2>/dev/null | grep -q .
check "P18 eval prompts do not leak the expected contract language" ok $?

grep -qi 'deeper reasoning' "$S" 2>/dev/null \
  && grep -qiE 'token|latency|runtime' "$S" 2>/dev/null \
  && grep -qi 'effort level sent to the API is unchanged' "$S" 2>/dev/null \
  && grep -qiE 'purchase|external spend' "$S" 2>/dev/null
check "P19 documented ultrathink runtime-effort and resource behavior is explicit in the skill" ok $?

grep -q '^user-invocable: true$' "$S" 2>/dev/null \
  && ! grep -q 'disable-model-invocation' "$S" 2>/dev/null \
  && echo "  effective invocation controls: user-invocable=true (explicit), disable-model-invocation=false (documented default; field absent) — user- and model-invocable"
check "P20 invocation-control fields keep the skill user- and model-invocable with documented defaults" ok $?

inv_block=$(sed -n '/raftkit-dev\//,/raftkit-qa\//p' CLAUDE.md)
inv_ok=1
grep -q '/raftkit-dev:ultrathink' plugins/raftkit-dev/commands/help.md 2>/dev/null || { echo "  help.md missing /raftkit-dev:ultrathink"; inv_ok=0; }
for skill in $(ls plugins/raftkit-dev/skills/); do
  grep -qE "\b${skill}\b" <<<"$inv_block" || { echo "  missing from CLAUDE.md inventory: $skill"; inv_ok=0; }
done
[[ "$inv_ok" -eq 1 ]]
check "P21 help.md documents /raftkit-dev:ultrathink and CLAUDE.md carries the mechanically derived skill inventory" ok $?

# Machine-local tool caches (.impeccable hook cache, .DS_Store) are never
# shipped or staged (literal-path staging); prune them so the check tests
# shippable content, not editor/hook residue.
[[ "$(cd "$SKILL" && find . -type f -not -path '*/.impeccable/*' -not -name .DS_Store | LC_ALL=C sort)" == $'./SKILL.md\n./agents/openai.yaml\n./references/reasoning-playbook.md' ]]
check "P22 skill ships only the Claude-form files; cross-runtime artifacts are R3-rendered, never bundled" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
