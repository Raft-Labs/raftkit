#!/usr/bin/env bash
# Deterministic suite for pr-auto-review's renderer. Mirrors
# tests/setup-toolchain.test.sh's pattern: drive the shipped script directly
# over its shipped template, no test-only renderer.
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

SKILL=plugins/raftkit-dev/skills/pr-auto-review
RENDER=$SKILL/scripts/render-pr-auto-review.mjs
TEMPLATE_DIR=$SKILL/references/assets

ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; failures=$((failures + 1)); }
want() { # <name> <condition already evaluated as exit code>
  if [[ "$2" -eq 0 ]]; then ok "$1"; else bad "$1"; fi
}

# Extract the fix-loop prompt back OUT of the rendered YAML's block scalar,
# dedented. Every prompt-content assertion below runs against THIS, never
# against the whole file: the workflow's own comment block discusses the same
# subjects in prose, and a whole-file grep would be satisfied by a comment
# long after the prompt itself lost the behaviour.
extract_prompt() { # <rendered yml>
  awk '
    /^[[:space:]]*prompt: \|[[:space:]]*$/ && !seen { seen = 1; inblock = 1; next }
    inblock {
      if ($0 ~ /^[[:space:]]*$/) { print ""; next }
      match($0, /^[[:space:]]*/); ind = RLENGTH
      if (!based) { base = ind; based = 1 }
      if (ind < base) { exit }
      print substr($0, base + 1)
    }
  ' "$1"
}

# Extract every line that lives inside a `run:` block, so shell-level
# assertions cannot be satisfied by YAML comments or by `with:` inputs.
extract_run_blocks() { # <rendered yml>
  awk '
    /^[[:space:]]*run: \|[[:space:]]*$/ {
      match($0, /^[[:space:]]*/); keyind = RLENGTH; inblock = 1; next
    }
    inblock {
      if ($0 ~ /^[[:space:]]*$/) { next }
      match($0, /^[[:space:]]*/); ind = RLENGTH
      if (ind <= keyind) { inblock = 0; next }
      print
    }
  ' "$1"
}

# Extract the identity of every job step, in order, as `name: …` / `uses: …`.
# Anchored on the exact list-item indentation derived from the `steps:` key, so
# neither a `#` comment nor a line inside a `run:` block or the prompt block
# scalar (both indented deeper) can forge a step. See S35.
extract_step_names() { # <rendered yml>
  awk '
    !instep && /^[[:space:]]*steps:[[:space:]]*$/ {
      match($0, /^[[:space:]]*/); itemind = RLENGTH + 2; instep = 1; next
    }
    instep {
      match($0, /^[[:space:]]*/); ind = RLENGTH
      line = substr($0, ind + 1)
      if (ind == itemind && line ~ /^- (name|uses): /) { sub(/^- /, "", line); print line }
    }
  ' "$1"
}

# S1 — happy path renders successfully with all valid inputs.
tmp1=$(mktemp -d); tmpdirs+=("$tmp1")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp1" \
  --bot-name "RaftKit PR Auto-Review" --bot-email "pr-auto-review@raftlabs.com" \
  --timeout-minutes 30 --max-turns 60 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S1 happy-path renders" ok $?
YML="$tmp1/pr-auto-review.yml"
[[ -f "$tmp1/pr-auto-review.yml" ]] || { echo "FAIL: S1 output file missing"; failures=$((failures+1)); }

# S2 — no unresolved __TOKEN__ placeholders remain in rendered output.
if [[ -f "$tmp1/pr-auto-review.yml" ]]; then
  if grep -qE '__[A-Z_]+__' "$tmp1/pr-auto-review.yml"; then
    echo "FAIL: S2 unresolved placeholder remains"; failures=$((failures+1))
  else
    echo "PASS: S2 no unresolved placeholders"
  fi
fi

# S3 — deterministic: identical inputs render byte-identical output.
tmp2=$(mktemp -d); tmpdirs+=("$tmp2")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp2" \
  --bot-name "RaftKit PR Auto-Review" --bot-email "pr-auto-review@raftlabs.com" \
  --timeout-minutes 30 --max-turns 60 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
if diff -q "$tmp1/pr-auto-review.yml" "$tmp2/pr-auto-review.yml" >/dev/null 2>&1; then
  echo "PASS: S3 byte-identical re-render"
else
  echo "FAIL: S3 re-render differs on unchanged input"; failures=$((failures+1))
fi

# S4 — bad bot email (injection-shaped) is rejected, renders nothing.
tmp4=$(mktemp -d); tmpdirs+=("$tmp4")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp4" \
  --bot-name "x" --bot-email 'x$(rm -rf /)' \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S4 injection-shaped email rejected" fail $?
[[ -f "$tmp4/pr-auto-review.yml" ]] && { echo "FAIL: S4 wrote a file despite validation failure"; failures=$((failures+1)); } || echo "PASS: S4 wrote nothing"

# S5 — non-numeric timeout-minutes is rejected.
tmp5=$(mktemp -d); tmpdirs+=("$tmp5")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp5" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes "not-a-number" --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S5 non-numeric timeout-minutes rejected" fail $?

# S6 — a genuinely missing required flag exits with a usage error (exit 2),
# not a crash. Only --templates and --out-dir are required now (see S22): the
# identity/limit flags all default, so omitting THEM is a valid invocation and
# this case has to omit --out-dir to still be testing what it claims to test.
node "$RENDER" --templates "$TEMPLATE_DIR" >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 2 ]]; then echo "PASS: S6 missing required flag exits 2"; else echo "FAIL: S6 expected exit 2, got $actual"; failures=$((failures+1)); fi

# S7 — control/newline characters in bot-name are rejected.
tmp7=$(mktemp -d); tmpdirs+=("$tmp7")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp7" \
  --bot-name "$(printf 'a\nb')" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
check "S7 newline in bot-name rejected" fail $?

# S8 — rendered YAML is valid YAML (parse check, mirrors validate.yml's jq-for-JSON idea).
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  if [[ -f "$tmp1/pr-auto-review.yml" ]] && python3 -c "import yaml; yaml.safe_load(open('$tmp1/pr-auto-review.yml'))" 2>/dev/null; then
    echo "PASS: S8 rendered output is valid YAML"
  else
    echo "FAIL: S8 rendered output is not valid YAML"; failures=$((failures+1))
  fi
else
  echo "  (note: python3+PyYAML not available — S8 skipped, not failed)" >&2
fi

# S9 — a missing required template file fails closed (exit 3, clean
# message), never an unhandled crash (e.g. exit 1 with a raw stack trace).
tmp9templates=$(mktemp -d); tmpdirs+=("$tmp9templates")
cp "$TEMPLATE_DIR/pr-auto-review.yml" "$tmp9templates/"
# fix-loop-prompt.md deliberately absent from $tmp9templates.
tmp9out=$(mktemp -d); tmpdirs+=("$tmp9out")
node "$RENDER" \
  --templates "$tmp9templates" --out-dir "$tmp9out" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 3 ]]; then echo "PASS: S9 missing template file exits 3"; else echo "FAIL: S9 expected exit 3, got $actual"; failures=$((failures+1)); fi
[[ -f "$tmp9out/pr-auto-review.yml" ]] && { echo "FAIL: S9 wrote a file despite missing template"; failures=$((failures+1)); } || echo "PASS: S9 wrote nothing"

# S10 — a stray __TOKEN__-shaped string inside fix-loop-prompt.md's own
# content is caught and rejected, never silently shipped into the rendered
# workflow (the substituted prompt content is the one place the generic
# unresolved-placeholder scan can't see into on its own).
tmp10templates=$(mktemp -d); tmpdirs+=("$tmp10templates")
cp "$TEMPLATE_DIR/pr-auto-review.yml" "$tmp10templates/"
printf 'Some prompt text.\n__NOT_A_REAL_TOKEN__\nMore prompt text.\n' > "$tmp10templates/fix-loop-prompt.md"
tmp10out=$(mktemp -d); tmpdirs+=("$tmp10out")
node "$RENDER" \
  --templates "$tmp10templates" --out-dir "$tmp10out" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 3 ]]; then echo "PASS: S10 stray placeholder in prompt content rejected"; else echo "FAIL: S10 expected exit 3, got $actual"; failures=$((failures+1)); fi
[[ -f "$tmp10out/pr-auto-review.yml" ]] && { echo "FAIL: S10 wrote a file despite stray placeholder"; failures=$((failures+1)); } || echo "PASS: S10 wrote nothing"

# S11 — the rendered workflow pins `cancel-in-progress: false`. This job
# pushes its fixes to its own trigger branch, so `true` makes the run cancel
# itself after its first pushed fix (see references/workflow-mechanics.md).
# Matched as an anchored YAML key, counted: the asset's own comment block
# discusses `cancel-in-progress: true` in prose, and a bare substring test
# would either false-alarm on that or be satisfied by it.
if [[ -f "$tmp1/pr-auto-review.yml" ]]; then
  keys=$(grep -cE '^[[:space:]]*cancel-in-progress:' "$tmp1/pr-auto-review.yml")
  false_keys=$(grep -cE '^[[:space:]]*cancel-in-progress: false[[:space:]]*$' "$tmp1/pr-auto-review.yml")
  if [[ "$keys" -eq 1 && "$false_keys" -eq 1 ]]; then
    echo "PASS: S11 cancel-in-progress is false"
  else
    echo "FAIL: S11 expected exactly one cancel-in-progress key, set to false (found $keys key(s), $false_keys false)"; failures=$((failures+1))
  fi
fi

# S12 — the concurrency group survives and is still keyed on the PR number:
# runs must still serialize per PR now that they no longer cancel each other.
if [[ -f "$tmp1/pr-auto-review.yml" ]]; then
  if grep -qF 'group: pr-auto-review-${{ github.event.pull_request.number }}' "$tmp1/pr-auto-review.yml"; then
    echo "PASS: S12 concurrency group keyed on PR number"
  else
    echo "FAIL: S12 concurrency group missing or not keyed on PR number"; failures=$((failures+1))
  fi
fi

# S13 — the bot-commit loop guard step still exists AND still gates the
# later steps. With S11's cancel-in-progress: false this guard is the only
# thing preventing an infinite push -> synchronize -> push recursion, so the
# two are pinned together. Anchored on the YAML step, not on the step name
# as a substring: that name also appears in the asset's comment block, which
# would keep a loose check green after the step itself was renamed away.
if [[ -f "$tmp1/pr-auto-review.yml" ]]; then
  if grep -qE '^[[:space:]]*- name: Check last commit is not our own fix[[:space:]]*$' "$tmp1/pr-auto-review.yml" \
     && grep -qE '^[[:space:]]*id: guard[[:space:]]*$' "$tmp1/pr-auto-review.yml" \
     && grep -qF 'skip=true' "$tmp1/pr-auto-review.yml" \
     && grep -qF "steps.guard.outputs.skip != 'true'" "$tmp1/pr-auto-review.yml"; then
    echo "PASS: S13 bot-commit loop guard present and gating"
  else
    echo "FAIL: S13 bot-commit loop guard missing or not gating (recursion guard for S11)"; failures=$((failures+1))
  fi
fi

# =============================================================================
# S14–S31 — one assertion per finding from the CI-semantics audit. Each is
# anchored (YAML key shape, exact key counts, or the dedented prompt block)
# rather than a loose whole-file substring: the workflow's comment block
# discusses most of these subjects in prose, and a loose grep would stay green
# after the behaviour it names was deleted.
# =============================================================================

PROMPT_OUT=""
RUN_LINES=""
if [[ -f "$YML" ]]; then
  PROMPT_OUT=$(mktemp); tmpdirs+=("$PROMPT_OUT")
  extract_prompt "$YML" > "$PROMPT_OUT"
  RUN_LINES=$(mktemp); tmpdirs+=("$RUN_LINES")
  extract_run_blocks "$YML" > "$RUN_LINES"
fi

# S14 (C1) — a toolchain/dependency install exists, and the prompt can tell an
# infrastructure failure apart from a red test. Without both halves, Tier 1
# resolution runs `npm test` against a tree with no node_modules, reads
# module-not-found as "this fix is red", and discards every correct fix.
if [[ -f "$YML" ]]; then
  if [[ $(grep -cE '^[[:space:]]*uses: actions/setup-node@v[0-9]+[[:space:]]*$' "$YML") -eq 1 ]] \
     && [[ $(grep -cE '^[[:space:]]*id: deps[[:space:]]*$' "$YML") -eq 1 ]] \
     && grep -qE '^[[:space:]]*npm ci$' "$RUN_LINES" \
     && grep -qE '^[[:space:]]*npm install$' "$RUN_LINES" \
     && grep -qE '^[[:space:]]*DEPS_STATUS: \$\{\{ steps\.deps\.outputs\.status \}\}[[:space:]]*$' "$YML" \
     && grep -qF 'DEPS_STATUS' "$PROMPT_OUT" \
     && grep -qF 'the verification toolchain could not be prepared in CI' "$PROMPT_OUT"; then
    ok "S14 (C1) dependency install step exists and the prompt separates infra failure from a red fix"
  else
    bad "S14 (C1) no gated dependency install, or the prompt still reads a broken toolchain as a red fix"
  fi
fi

# S15 (C2) — the verify command runs ONCE as a baseline before the first fix,
# and a red baseline has its own disclosure instead of being blamed on a fix.
if [[ -f "$YML" ]]; then
  if grep -qF 'Run the verify command ONCE as a baseline' "$PROMPT_OUT" \
     && grep -qF 'failing on the unmodified branch before any auto-fix ran' "$PROMPT_OUT"; then
    ok "S15 (C2) baseline verify run precedes the first fix, with its own red-baseline disclosure"
  else
    bad "S15 (C2) no baseline verify run — an already-red PR would have every fix discarded and blamed"
  fi
fi

# S16 (C3) — the tool allowlist can actually invoke pr-review-toolkit:review-pr
# (a slash command whose own frontmatter declares Bash/Glob/Grep/Read/Task and
# whose whole method is Task dispatch), and the prompt hard-aborts rather than
# improvising a review. Counted as an anchored key so the explanatory comment
# above it cannot satisfy the check.
if [[ -f "$YML" ]]; then
  allow_total=$(grep -cE '^[[:space:]]*--allowedTools ' "$YML")
  allow_exact=$(grep -cE '^[[:space:]]*--allowedTools "Bash,Read,Edit,Glob,Grep,Task,SlashCommand"[[:space:]]*$' "$YML")
  if [[ "$allow_total" -eq 1 && "$allow_exact" -eq 1 ]] \
     && grep -qF 'Hard abort — improvised reviews are forbidden' "$PROMPT_OUT"; then
    ok "S16 (C3) allowedTools covers review-pr's own tools and the prompt aborts on an unstructured review"
  else
    bad "S16 (C3) allowedTools cannot invoke review-pr (found $allow_total line(s), $allow_exact exact), or no improvised-review abort"
  fi
fi

# S17 (H1) — GITHUB_TOKEN pushes do not trigger the repo's own workflows, so
# the PR comment must say the bot's commits are not CI-exercised, and the
# limitation must be documented where an installer will meet it.
if [[ -f "$YML" ]]; then
  if grep -qF 'pushes made with GITHUB_TOKEN' "$PROMPT_OUT" \
     && grep -qF 'GITHUB_TOKEN' "$SKILL/SKILL.md" \
     && grep -qF 'GITHUB_TOKEN' "$SKILL/references/workflow-mechanics.md" \
     && grep -qF 'GitHub App' "$SKILL/references/install.md"; then
    ok "S17 (H1) the not-exercised-by-CI limitation is disclosed in the comment and documented"
  else
    bad "S17 (H1) the GITHUB_TOKEN push limitation is undisclosed or undocumented"
  fi
fi

# S18 (H2) — disclosure cannot be the thing a dying run skips: the comment is
# posted before the first fix, and an always() step backstops a run that dies
# after a push but before the summary.
if [[ -f "$YML" ]]; then
  if grep -qE "^[[:space:]]*if: always\(\) && steps\.guard\.outputs\.skip != 'true' && steps\.complete\.outputs\.done != 'true'[[:space:]]*$" "$YML" \
     && [[ $(grep -cE '^[[:space:]]*id: complete[[:space:]]*$' "$YML") -eq 1 ]] \
     && grep -qF 'Run terminated early' "$RUN_LINES" \
     && grep -qF 'Post the summary comment BEFORE the first fix' "$PROMPT_OUT"; then
    ok "S18 (H2) comment posted before the first fix, with an always() early-termination backstop"
  else
    bad "S18 (H2) a run that dies after a push can still leave commits with no disclosure"
  fi
fi

# S19 (H3/M5) — gh needs a token, and the repo/PR identifiers come from the
# event, never from `gh pr view` (which resolves ambiguously when one branch
# has two open PRs, e.g. one into main and one into development).
if [[ -f "$YML" ]]; then
  if grep -qE '^[[:space:]]*GH_TOKEN: \$\{\{ github\.token \}\}[[:space:]]*$' "$YML" \
     && grep -qE '^[[:space:]]*OWNER_REPO: \$\{\{ github\.repository \}\}[[:space:]]*$' "$YML" \
     && grep -qE '^[[:space:]]*PR_NUMBER: \$\{\{ github\.event\.pull_request\.number \}\}[[:space:]]*$' "$YML" \
     && ! grep -qF 'OWNER_REPO="$(gh repo view' "$PROMPT_OUT" \
     && ! grep -qF 'PR_NUMBER="$(gh pr view' "$PROMPT_OUT"; then
    ok "S19 (H3/M5) GH_TOKEN is set and identifiers come from the event, not from gh auto-detection"
  else
    bad "S19 (H3/M5) GH_TOKEN missing, or the prompt still auto-detects the repo/PR"
  fi
fi

# S20 (H4) — drafts are excluded and ready_for_review/reopened are handled,
# with the draft condition on the JOB alongside the fork guard so no step can
# ever precede it.
if [[ -f "$YML" ]]; then
  steps_line=$(grep -nE '^[[:space:]]{4}steps:[[:space:]]*$' "$YML" | head -n1 | cut -d: -f1)
  fork_line=$(grep -nF 'head.repo.full_name == github.repository' "$YML" | grep -v '^\([0-9]*\):[[:space:]]*#' | head -n1 | cut -d: -f1)
  draft_line=$(grep -nF 'github.event.pull_request.draft == false' "$YML" | grep -v '^\([0-9]*\):[[:space:]]*#' | head -n1 | cut -d: -f1)
  if grep -qE '^[[:space:]]*types: \[opened, synchronize, reopened, ready_for_review\][[:space:]]*$' "$YML" \
     && [[ -n "$steps_line" && -n "$fork_line" && -n "$draft_line" ]] \
     && [[ "$fork_line" -lt "$steps_line" && "$draft_line" -lt "$steps_line" ]]; then
    ok "S20 (H4) draft PRs excluded and ready_for_review/reopened handled, guarded at job level"
  else
    bad "S20 (H4) draft/reopened handling missing, or the guard sits below steps: where a step can precede it"
  fi
fi

# S21 (H5) — an exact push command, a checked exit status, and an
# abort-not-improvise path on rejection. The improvisations a model reaches
# for here (pull --rebase, push --force) both destroy a human's commit.
if [[ -f "$YML" ]]; then
  if grep -qF 'git push origin HEAD:"$HEAD_REF"' "$PROMPT_OUT" \
     && grep -qF 'Only AFTER the push has exited 0' "$PROMPT_OUT" \
     && grep -qF -- 'never force-push' "$PROMPT_OUT" \
     && grep -qF -- 'git push --force-with-lease' "$PROMPT_OUT"; then
    ok "S21 (H5) exact push command, SHA captured only after a confirmed push, rejection aborts"
  else
    bad "S21 (H5) no literal push command or no non-fast-forward abort path"
  fi
fi

# S22 (H6) — every renderer argument defaults, and the defaults ARE the
# canonical values. Proven by byte-equality against a fully explicit render:
# an installer that has to invent a bot identity invents a different one next
# time and silently breaks the loop guard against earlier commits.
tmp22=$(mktemp -d); tmpdirs+=("$tmp22")
node "$RENDER" --templates "$TEMPLATE_DIR" --out-dir "$tmp22" >/dev/null 2>&1
tmp22b=$(mktemp -d); tmpdirs+=("$tmp22b")
node "$RENDER" \
  --templates "$TEMPLATE_DIR" --out-dir "$tmp22b" \
  --bot-name "RaftKit PR Auto-Review" --bot-email "pr-auto-review@raftlabs.com" \
  --timeout-minutes 30 --max-turns 60 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" \
  >/dev/null 2>&1
if [[ -f "$tmp22/pr-auto-review.yml" ]] \
   && diff -q "$tmp22/pr-auto-review.yml" "$tmp22b/pr-auto-review.yml" >/dev/null 2>&1 \
   && grep -qF 'pr-auto-review@raftlabs.com' "$tmp22/pr-auto-review.yml" \
   && grep -qF 'pr-auto-review@raftlabs.com' "$SKILL/references/install.md"; then
  ok "S22 (H6) all renderer args default to the canonical, documented values"
else
  bad "S22 (H6) renderer still demands an invented bot identity, or defaults are not canonical"
fi

# S23 (M1) — no `${{ }}` expression is interpolated into any `run:` block.
# Branch names permit backticks, \$, ; and &, which expand inside double
# quotes in a job holding contents: write and ANTHROPIC_API_KEY.
if [[ -f "$YML" ]]; then
  if ! grep -qF '${{' "$RUN_LINES"; then
    ok "S23 (M1) no GitHub expression is interpolated into a run: block"
  else
    bad "S23 (M1) a \${{ }} expression reaches a run: block — script injection: $(grep -F '${{' "$RUN_LINES" | head -n1 | sed 's/^ *//')"
  fi
fi

# S24 (M2) — the loop guard checks the commit trailer as well as the author
# email (a rebase preserves the author; a squash can drop the body), and a
# skip is announced rather than silent.
if [[ -f "$YML" ]]; then
  if grep -qF "grep -c '^pr-auto-review-commit: true" "$RUN_LINES" \
     && grep -qF '"$AUTHOR_EMAIL" = "pr-auto-review@raftlabs.com"' "$RUN_LINES" \
     && grep -qF '### pr-auto-review skipped' "$RUN_LINES"; then
    ok "S24 (M2) loop guard checks trailer AND author email, and never skips silently"
  else
    bad "S24 (M2) loop guard checks only one signal, or a skip leaves no observable trace"
  fi
fi

# S25 (M3) — the marker lookup paginates. A repo with 30+ comments is routine
# once review bots are installed; page-1-only means a duplicate comment every
# single run, the exact thing comment-contract.md exists to prevent.
if [[ -f "$YML" ]]; then
  if grep -qF 'gh api --paginate "repos/$OWNER_REPO/issues/$PR_NUMBER/comments"' "$PROMPT_OUT"; then
    ok "S25 (M3) the summary-comment lookup paginates"
  else
    bad "S25 (M3) comment lookup reads page 1 only and will duplicate on busy PRs"
  fi
fi

# S26 (M4) — the comment body is capped below GitHub's hard limit, with the
# overflow spilled to the job summary and the truncation stated. A 422 here
# loses the comment entirely, with commits already pushed.
if [[ -f "$YML" ]]; then
  if grep -qF '65536' "$PROMPT_OUT" \
     && grep -qF "Truncated to fit GitHub's comment size limit" "$PROMPT_OUT" \
     && grep -qF 'GITHUB_STEP_SUMMARY' "$PROMPT_OUT"; then
    ok "S26 (M4) comment body is size-capped with an explicit truncation notice"
  else
    bad "S26 (M4) a large finding list can exceed GitHub's comment cap and 422 with no fallback"
  fi
fi

# S27 (M6a) — a prompt whose first non-empty line is indented would set the
# block scalar's indentation and swallow every following line into it. Fail
# closed rather than emit silently-corrupt YAML.
tmp27t=$(mktemp -d); tmpdirs+=("$tmp27t")
cp "$TEMPLATE_DIR/pr-auto-review.yml" "$tmp27t/"
printf '  Indented first line.\nSecond line.\n' > "$tmp27t/fix-loop-prompt.md"
tmp27o=$(mktemp -d); tmpdirs+=("$tmp27o")
# Every optional flag passed explicitly: this check is about the prompt's
# indentation, not about S22's defaults, and must not go red with it.
node "$RENDER" --templates "$tmp27t" --out-dir "$tmp27o" \
  --bot-name "x" --bot-email "x@example.com" \
  --timeout-minutes 15 --max-turns 20 \
  --plugin-ref "pr-review-toolkit@claude-plugins-official" >/dev/null 2>&1
actual=$?
if [[ "$actual" -eq 3 && ! -f "$tmp27o/pr-auto-review.yml" ]]; then
  ok "S27 (M6a) an indented first prompt line fails closed, writing nothing"
else
  bad "S27 (M6a) expected exit 3 and no output for an indented first prompt line, got exit $actual"
fi

# S27b (M6b) — structural round-trip of the emitted block scalar. Node ships
# no YAML parser and this repo adds no npm dependency for one, so instead of
# parsing we assert the property a literal block scalar must hold: every line
# indented to the block, and the block dedenting back to the source byte for
# byte. A block that satisfies this cannot have leaked prompt text into the
# workflow mapping. (S8 additionally does a real parse where PyYAML exists.)
# Deliberately NOT guarded on the artifact existing: a missing render is a
# failure of this check, not a reason to skip it silently.
if [[ -n "$PROMPT_OUT" ]] && diff -q "$PROMPT_OUT" "$TEMPLATE_DIR/fix-loop-prompt.md" >/dev/null 2>&1; then
  ok "S27b (M6b) the embedded prompt block round-trips to fix-loop-prompt.md exactly"
else
  bad "S27b (M6b) the embedded prompt block does not round-trip — block scalar is corrupt or absent"
fi

# S28 (L2) — the renderer's comment must describe the code it sits above. The
# old text claimed the first prompt line keeps the template's indentation "for
# free", which is the opposite of what the code does and invites a maintainer
# to "fix" working code into broken code.
if ! grep -qF 'keeps that existing indentation on the prompt' "$RENDER" \
   && grep -qF 're-applied to EVERY line of the prompt' "$RENDER"; then
  ok "S28 (L2) the renderer's block-scalar comment matches its implementation"
else
  bad "S28 (L2) the renderer's comment still contradicts its code"
fi

# S29 (L3) — the SECURITY header documents the residual risk in the same-repo
# case it DOES allow, not only the fork case it forbids.
if [[ -f "$YML" ]]; then
  header=$(sed -n '1,/^name:/p' "$YML")
  if grep -qF 'RESIDUAL RISK' <<<"$header" \
     && grep -qF '.git/config' <<<"$header" \
     && grep -qF 'ANTHROPIC_API_KEY' <<<"$header"; then
    ok "S29 (L3) the SECURITY header documents the same-repo residual risk"
  else
    bad "S29 (L3) the SECURITY header still argues only the fork case"
  fi
fi

# S30 (L4) — timeout-minutes is bounded by GitHub's 360-minute runner cap; a
# larger value is one the runner will never honour, and accepting it is
# exactly the silent behaviour this fail-closed renderer exists to prevent.
render_with_timeout() { # <out-dir> <timeout-minutes>
  node "$RENDER" --templates "$TEMPLATE_DIR" --out-dir "$1" \
    --bot-name "x" --bot-email "x@example.com" \
    --timeout-minutes "$2" --max-turns 20 \
    --plugin-ref "pr-review-toolkit@claude-plugins-official" >/dev/null 2>&1
}
tmp30=$(mktemp -d); tmpdirs+=("$tmp30")
render_with_timeout "$tmp30" 361
over=$?
tmp30b=$(mktemp -d); tmpdirs+=("$tmp30b")
render_with_timeout "$tmp30b" 360
atcap=$?
if [[ "$over" -eq 3 && ! -f "$tmp30/pr-auto-review.yml" && "$atcap" -eq 0 ]]; then
  ok "S30 (L4) timeout-minutes above GitHub's 360-minute cap is rejected; 360 is accepted"
else
  bad "S30 (L4) expected 361 to exit 3 with no output and 360 to succeed (got $over / $atcap)"
fi

# S31 (CR1) — review-pr must be handed the merge-base range explicitly. It and
# its code-reviewer agent default to reviewing UNSTAGED changes (`git diff`
# with no arguments); a CI checkout has none, so the default scope is empty and
# the workflow would run, pass, and review nothing on every PR forever.
if [[ -f "$YML" ]]; then
  if grep -qF 'git diff --name-only "$MERGE_BASE" HEAD' "$PROMPT_OUT" \
     && grep -qF 'You must hand `review-pr` that explicit range' "$PROMPT_OUT" \
     && grep -qF 'Never let it fall back to its default scope' "$PROMPT_OUT"; then
    ok "S31 (CR1) review-pr is scoped to the merge-base range, never its empty default"
  else
    bad "S31 (CR1) review-pr would fall back to unstaged-diff scope and review nothing in CI"
  fi
fi

# S32 (CR2) — the infrastructure-vs-red boundary is drawn precisely. Filing a
# broken import in the PR's own source as "infrastructure" would commit the
# breakage while blaming the toolchain; the boundary is whose code failed to
# load, and ambiguity resolves to red.
if [[ -f "$YML" ]]; then
  if grep -qF 'the test runner itself could not start' "$PROMPT_OUT" \
     && grep -qF "the repo's own code fails to import, parse, compile, or type-check" "$PROMPT_OUT" \
     && grep -qF 'When you genuinely cannot tell, treat it as' "$PROMPT_OUT" \
     && grep -qF 'A missing `node_modules` is infrastructure' "$PROMPT_OUT"; then
    ok "S32 (CR2) infrastructure vs red is bounded by whose code failed to load, ambiguity resolves red"
  else
    bad "S32 (CR2) infrastructure failure is defined loosely enough to excuse a fix's own breakage"
  fi
fi

# S33 (CR3) — every non-zero push exit stops the loop and the disclosure names
# the real remote state. A network failure after the objects transferred can
# leave the commit ON the remote while reporting failure; a reviewer must not
# have to open the Actions log to find out whether a commit landed.
if [[ -f "$YML" ]]; then
  if grep -qF 'Any non-zero exit stops the fix loop' "$PROMPT_OUT" \
     && grep -qF 'git ls-remote origin "refs/heads/$HEAD_REF"' "$PROMPT_OUT" \
     && grep -qF 'Remote state: commit <short SHA>' "$PROMPT_OUT"; then
    ok "S33 (CR3) any push failure stops the loop and discloses the confirmed remote state"
  else
    bad "S33 (CR3) only non-fast-forward is handled; other push failures leave remote state undisclosed"
  fi
fi

# S34 (REG1) — the bot git identity is configured before the fix loop runs.
# A GitHub Actions runner has no default git identity, so without this every
# `git commit` in the fix loop dies with "Please tell me who you are" and the
# workflow can never land a single fix. It is also what makes the loop guard's
# author-email comparison (S24) match anything at all. Asserted against the
# extracted `run:` lines carrying the RENDERED values, so neither the step's
# own explanatory comment nor any prose elsewhere in the YAML can satisfy it.
# Deliberately NOT guarded on the artifact existing (cf. S27b, S35): a missing
# render must fail this check, never silently skip it.
if [[ -n "$RUN_LINES" ]] \
   && grep -qF 'git config user.name "RaftKit PR Auto-Review"' "$RUN_LINES" \
   && grep -qF 'git config user.email "pr-auto-review@raftlabs.com"' "$RUN_LINES"; then
  ok "S34 (REG1) bot git identity is configured with the canonical rendered values"
else
  bad "S34 (REG1) no git identity is configured — every fix commit fails with 'Please tell me who you are'"
fi

# S35 (REG2) — pin the COMPLETE, ordered set of job steps. Every other
# assertion here pins a step someone thought to test, which is exactly why
# b3eb925 could delete the identity step invisibly: nothing asserted what the
# workflow's step list should be, only what pieces of it must contain. This
# fails on any deletion, rename, reorder or addition, so a step can only leave
# this workflow deliberately. Order is part of the contract — the identity step
# must precede the action, the guard must precede everything gated on it.
# Deliberately NOT guarded on the artifact existing (cf. S27b): a missing
# render is a failure of this check, not a reason to skip it.
expected_steps=$(mktemp); tmpdirs+=("$expected_steps")
cat > "$expected_steps" <<'STEPS'
uses: actions/checkout@v4
name: Check last commit is not our own fix
name: Configure bot git identity
name: Set up Node toolchain
name: Install dependencies
uses: anthropics/claude-code-action@v1
name: Record fix-loop completion
name: Disclose an incomplete run
STEPS
actual_steps=$(mktemp); tmpdirs+=("$actual_steps")
extract_step_names "$YML" > "$actual_steps" 2>/dev/null
if diff -q "$expected_steps" "$actual_steps" >/dev/null 2>&1; then
  ok "S35 (REG2) the rendered workflow's step set is exactly the expected list, in order"
else
  bad "S35 (REG2) workflow steps changed — a step was deleted, renamed, reordered or added:"
  diff "$expected_steps" "$actual_steps" | sed 's/^/       /' >&2
fi

echo "----"
if [[ "$failures" -eq 0 ]]; then
  echo "OK: all pr-auto-review render checks passed"
else
  echo "FAIL: $failures check(s) failed"
  exit 1
fi
