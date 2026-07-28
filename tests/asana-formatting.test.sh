#!/usr/bin/env bash
# Deterministic contract suite for the core asana-formatting capability (R2)
# and the docs->Asana story/bug lifecycle with live templates.
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
check() {
  local name="$1" expected="$2" actual="$3"
  if { [[ "$expected" == ok && "$actual" -eq 0 ]] || [[ "$expected" == fail && "$actual" -ne 0 ]]; }; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected $expected, exit was $actual)"
    failures=$((failures + 1))
  fi
}
joined() { cat "$@" 2>/dev/null | tr '\n' ' ' | tr -s ' '; }

AF=plugins/raftkit-core/skills/asana-formatting
WP=plugins/raftkit-core/skills/write-protocol/SKILL.md
DOCS=plugins/raftkit-dev/skills/docs

[[ -f "$AF/SKILL.md" ]] \
  && head -6 "$AF/SKILL.md" | grep -q '^user-invocable: false$' \
  && [[ -f "$AF/references/tag-matrix.md" && -f "$AF/references/conversion.md" && -f "$AF/references/mentions.md" && -f "$AF/references/verification.md" ]]
check "AF1 core asana-formatting skill exists, non-invocable, with the four references" ok $?

tm=$(joined "$AF/references/tag-matrix.md")
grep -qi 'description' <<<"$tm" && grep -qi 'comment' <<<"$tm" && grep -qi 'brief' <<<"$tm" \
  && grep -qiE 'h1|h2|heading' <<<"$tm" \
  && grep -qi 'table' <<<"$tm" \
  && grep -qiE 'br/>.*never|never.*br/' <<<"$tm" \
  && grep -qi 'named html entities render literally' <<<"$tm" \
  && grep -qi 'body' <<<"$tm"
check "AF2 per-surface tag matrix (surfaces, heading limits, tables brief-only, br never accepted, named-entity gap, body wrap)" ok $?

cv=$(joined "$AF/references/conversion.md")
grep -qiE 'strong|bold' <<<"$cv" && grep -qiE '<ul>|<ol>|list' <<<"$cv" \
  && grep -qiE '<code>|code' <<<"$cv" && grep -qiE 'blockquote|quote' <<<"$cv" \
  && grep -qiE '<a href|link' <<<"$cv" \
  && grep -qiE 'h3.*strong|strong.*list|third level' <<<"$cv"
check "AF3 markdown-intent to Asana HTML conversion rules incl. h3-becomes-strong+list" ok $?

mn=$(joined "$AF/references/mentions.md")
grep -q 'data-asana-gid' <<<"$mn" && grep -q 'data-asana-dynamic' <<<"$mn" \
  && grep -qiE 'no.*access|lack.*access|fall back|fallback' <<<"$mn"
check "AF4 object references/mentions with no-access fallback" ok $?

sk=$(joined "$AF/SKILL.md")
grep -qiE 'read.*before.*write|read-before-write|read first' <<<"$sk" \
  && grep -qiE 'comment.*default|default.*comment|comments, never' <<<"$sk" \
  && grep -qiE 'explicit.*consent|explicitly.*update the description|only when.*update the description' <<<"$sk"
check "AF5 read-before-write, comments-by-default, explicit-consent description overwrite" ok $?

wp=$(joined "$WP")
grep -qi 'asana-formatting' <<<"$wp" \
  && grep -qi 'single body root\|<body>' <<<"$wp" \
  && grep -qiE 'no .?<p>.? tag' <<<"$wp" \
  && grep -qi 'attributes only on\|only element allowed to carry attributes' <<<"$wp" \
  && grep -qi 'escape' <<<"$wp" \
  && grep -qi 'draft' <<<"$wp" && grep -qi 'approve' <<<"$wp" && grep -qi 'push' <<<"$wp"
check "AF6 write-protocol delegates to asana-formatting; four rules preserved; draft-approve-push intact" ok $?

writers=(
  plugins/raftkit-pm/skills/user-story/SKILL.md
  plugins/raftkit-pm/skills/meeting-decisions/SKILL.md
  plugins/raftkit-pm/skills/status-update/SKILL.md
  plugins/raftkit-qa/skills/file-bug/SKILL.md
  plugins/raftkit-qa/skills/retest/SKILL.md
  plugins/raftkit-dev/skills/pr/SKILL.md
  plugins/raftkit-dev/skills/implement/references/close-out.md
)
seam_ok=1
for w in "${writers[@]}"; do
  grep -q 'asana-formatting' "$w" 2>/dev/null || { echo "  missing asana-formatting seam: $w"; seam_ok=0; }
done
[[ "$seam_ok" -eq 1 ]]
check "AF7 every Asana-writing skill routes through asana-formatting (seam per writer)" ok $?

vf=$(joined "$AF/references/verification.md")
grep -qiE 'read.back|re-fetch|read-back' <<<"$vf" \
  && grep -qiE 'mismatch|differ|does not match' <<<"$vf" \
  && grep -qiE 'never.*silently|not.*rewrite|approved content' <<<"$vf"
check "AF8 read-back rendered-content verification with mismatch reporting, no silent rewrite" ok $?

# A stripped <h1>/<hr>/<ul> is invisible in Asana's plain-text field — the
# read-back must compare against html_text, or the defect it exists to catch
# can never be observed.
grep -qi 'html_text' <<<"$vf" && grep -qiE 'never.*text.*field|never.*plain.text' <<<"$vf"
check "AF8b read-back compares html_text, not the plain-text field" ok $?

[[ -f "$DOCS/references/story-adapter.md" ]] \
  && st=$(joined "$DOCS/references/story-adapter.md") \
  && grep -qi 'live template\|fetched.*run\|live GID\|fetch.*template' <<<"$st" \
  && grep -qi 'Gherkin' <<<"$st" && grep -qiE 'WEESLD|edge case' <<<"$st" \
  && grep -qiE '5.*12|5–12|five.*twelve' <<<"$st" \
  && grep -qi '9.*11\|9 → 11\|numbering' <<<"$st" \
  && grep -qi 'TBD' <<<"$st"
check "AF9 docs story adapter: live template, Gherkin, WEESLD, 5-12 ACs, 9-to-11 numbering, TBD-flag gaps" ok $?

[[ -f "$DOCS/references/bug-adapter.md" ]] \
  && bg=$(joined "$DOCS/references/bug-adapter.md") \
  && grep -qi 'live template\|fetched.*run\|live GID' <<<"$bg" \
  && grep -qi 'spec.*expected\|expected.*spec\|spec IS the expected' <<<"$bg" \
  && grep -qi 'actual' <<<"$bg" \
  && grep -qiE 'retest|re-tag|never duplicate' <<<"$bg"
check "AF10 docs bug adapter: live template, spec-quoted expected, human actual, retest re-tags" ok $?

reg=$(joined "$DOCS/references/story-adapter.md")
grep -qiE 'registry|asana\.json' <<<"$reg" \
  && grep -qiE 'GID' <<<"$reg" \
  && grep -qiE 'sync.*version|lastSynced|synced version' <<<"$reg" \
  && grep -qiE 'never auto-complete|parent.*never|never delete.*completed|completed.*never delet' <<<"$reg"
check "AF11 link registry stores GIDs + sync versions; parent never auto-completed; completed ACs preserved" ok $?

grep -qiE 'offline|connector.*unavailable|no connector' <<<"$reg" \
  && grep -qiE 'provenance|fetch time|recorded.*GID' <<<"$reg" \
  && grep -qiE 'current run|fetched.*run|this run' <<<"$reg"
check "AF12a offline artifact only from a current-run fetch with recorded provenance" ok $?

# The cached-template signature the source refs violated is an Asana HTML
# skeleton: a real <body>…</body> block containing the template's sections.
# Legitimate uses document the rule inside inline code (`<body>…</body>`) —
# those carry a backtick on the line. Flag only a <body> tag OUTSIDE inline
# code (a genuine skeleton). Live-fetch adapters never embed one.
! grep -rn '<body>' plugins/ 2>/dev/null | grep -v '`' | grep -q .
check "AF12b zero cached Asana HTML skeleton in plugins (live-fetch only)" ok $?

grep -qiE 'AC.*tick|tick.*AC|complete.*subtask|subtask.*complet' <<<"$reg" \
  && grep -qiE 'offer|drafted.*approv|approv.*push' <<<"$reg"
check "AF13 AC-tick offers are drafted and pushed only after approval" ok $?

eval_count=$(find plugins/raftkit-dev/evals/asana-lifecycle -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/asana-lifecycle -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/asana-lifecycle -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "AF14 at least eight asana-lifecycle eval cases each include a prompt and grader" ok $?

node - <<'NODE'
const fs = require("fs");
const dev = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
const core = JSON.parse(fs.readFileSync("plugins/raftkit-core/.claude-plugin/plugin.json", "utf8"));
const market = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
const ge = (v, min) => { const a = v.split(".").map(Number); return (a[0]-min[0] || a[1]-min[1] || a[2]-min[2]) >= 0; };
const devEntry = market.plugins.find((p) => p.name === "raftkit-dev");
const coreEntry = market.plugins.find((p) => p.name === "raftkit-core");
if (!ge(dev.version, [0,18,0])) process.exit(1);
if (!ge(core.version, [0,5,0])) process.exit(1);
if (devEntry.description !== dev.description) process.exit(1);
if (coreEntry.description !== core.description) process.exit(1);
NODE
check "AF15 manifests: dev>=0.18.0, core>=0.5.0, both descriptions lockstep" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
