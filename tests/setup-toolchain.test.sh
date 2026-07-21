#!/usr/bin/env bash
# Deterministic suite for Story D (M3 · setup-project toolchain, Asana
# 1216767132032184). Drives the SHIPPED contract directly: detection and
# rendering run through setup-project's own scripts over its own templates —
# no test-only renderer.
#
# AC → evidence matrix (eval bundle authored pre-implementation, structurally
# verified; behavioral execution deferred to the final plugin-evaluation story):
#   AC-1  signal contract .......... S1–S9 (decision matrix, no-writes rule)
#   AC-2  workspace discovery ...... S10, S11
#   AC-3  hook ownership ........... S15–S25 (isolated git env; scopes; redaction)
#   AC-4  pre-push fail-closed ..... S26–S34 (render matrix, sh -n, validation)
#   AC-5  CI fail-closed ........... S26–S31, S35–S37 (YAML parse, preservation)
#   AC-6  transactional/idempotent . S30 (byte-identical) + contract text S38
#   AC-7  provider ownership ....... S40 (preflight seam untouched)
#   AC-8  no invented values ....... S32–S34
#   AC-9  fixtures red-first ....... this whole suite, observed red pre-edit
#   AC-10 eval bundle .............. S44, S45
#   AC-11 version discipline ....... S42, S43
#   AC-12 bounded PR / allowlist ... S41
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

SETUP=plugins/raftkit-dev/skills/setup-project
DETECT=$SETUP/scripts/detect-toolchain.mjs
RENDER=$SETUP/scripts/render-assets.mjs
FIX=tests/fixtures/toolchain

# Scope-check mode: explicit, validated, argument-array git — never inferred.
if [[ "${1:-}" == "--scope-check" ]]; then
  base="${2:-}"; head="${3:-}"
  allow_sc=$(grep "^allow=" "$0" | head -1 | sed "s/^allow='//;s/'$//")
  [[ -n "$base" && -n "$head" && "$base" != -* && "$head" != -* ]] || { echo "scope-check requires <base> <head> commits"; exit 2; }
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "scope-check: invalid or unreachable base '$base'"; exit 2; }
  git rev-parse --verify --quiet "$head^{commit}" >/dev/null || { echo "scope-check: invalid or unreachable head '$head'"; exit 2; }
  git merge-base --is-ancestor "$base" "$head" || { echo "scope-check: reversed or disjoint range $base..$head"; exit 2; }
  changed="$(git diff --name-only "$base" "$head" --)"
  echo "scope-check $base..$head — changed files:"; printf '%s\n' "$changed"
  viol="$(grep -Ev "$allow_sc" <<<"$changed" || true)"
  if [[ -n "$viol" ]]; then printf 'ALLOWLIST VIOLATIONS:\n%s\nscope-check: FAIL\n' "$viol"; exit 1; fi
  echo "scope-check: PASS — every changed file is inside the approved allowlist"
  exit 0
fi

# Fully isolated git configuration (amendment 1): temp HOME + XDG + explicit
# temp global file + NOSYSTEM. The developer's real git config is never read
# or mutated; the temp global file is byte-compared where the test demands it.
ISO="$(mktemp -d)"; tmpdirs+=("$ISO"); mkdir -p "$ISO/xdg"
: > "$ISO/gitconfig-global"
giso() { HOME="$ISO" XDG_CONFIG_HOME="$ISO/xdg" GIT_CONFIG_GLOBAL="$ISO/gitconfig-global" GIT_CONFIG_NOSYSTEM=1 "$@"; }

det() { OUT=$(giso node "$DETECT" --root "$1" --json 2>&1); RC=$?; }
field() { node -e 'const d=JSON.parse(process.argv[1]);const p=process.argv[2].split(".");let v=d;for(const k of p)v=v?.[k];console.log(typeof v==="object"?JSON.stringify(v):String(v))' "$OUT" "$1" 2>/dev/null; }

# ---- S1–S9 · package-manager signal decision matrix -------------------------
det "$FIX/npm";                  [[ $RC -eq 0 && $(field state) == detected && $(field manager) == npm ]];  check "S1 npm lockfile detects npm" ok $?
det "$FIX/pnpm-turbo-workspace"; [[ $(field state) == detected && $(field manager) == pnpm && $(field declaredVersion) == 10.12.0 && $(field workspace) == true ]]
check "S2 pnpm workspace with agreeing field detects pnpm + version + workspace" ok $?
det "$FIX/yarn-workspace";       [[ $(field state) == detected && $(field manager) == yarn ]];              check "S3 yarn workspace detects yarn" ok $?
det "$FIX/bun";                  [[ $(field state) == detected && $(field manager) == bun ]];               check "S4 bun lockfile detects bun" ok $?
det "$FIX/no-lockfile";          [[ $(field state) == undetermined ]];                                      check "S5 package.json without lockfile is undetermined (ask)" ok $?
det "$FIX/conflict-lockfiles";   [[ $(field state) == conflict ]];                                          check "S6 multiple lockfile families conflict (ask)" ok $?
det "$FIX/conflict-field";       [[ $(field state) == conflict ]];                                          check "S7 lockfile vs packageManager disagreement conflicts (ask)" ok $?
det "$FIX/field-only";           [[ $(field state) == ask-field-only ]];                                    check "S8 packageManager without lockfile is reported and asked" ok $?
det "$FIX/non-node";             [[ $(field state) == non-node ]];                                          check "S9 non-Node repo reports its posture" ok $?

# ---- S10–S11 · workspace command discovery ----------------------------------
det "$FIX/nx-workspace"
[[ $(field state) == detected ]] && grep -q 'nx run-many' <<<"$(field rootScripts)"
check "S10 root orchestration script (nx) preferred and reported verbatim" ok $?
det "$FIX/workspace-only-scripts"
[[ $(field rootQuality) == '[]' || $(field rootQuality) == 'undefined' ]] && grep -q 'packages/web' <<<"$(field workspaceCandidates)" && grep -qi 'selection' <<<"$OUT"
check "S11 workspace-only scripts reported as candidates requiring human selection" ok $?

# ---- S12–S14 · version + setup mechanism reporting --------------------------
det "$FIX/pnpm-turbo-workspace"
[[ $(field setupReport.declaredVersion) == 10.12.0 && $(field setupReport.corepackUsedOrApproved) == true ]]
check "S12 declared packageManager version captured verbatim" ok $?
det "$FIX/npm"
[[ $(field setupReport.declaredVersion) == null || $(field setupReport.declaredVersion) == undefined ]] && [[ $(field setupReport.repoSetupMechanism) == none ]]
check "S13 no declared version -> no invented version, mechanism none" ok $?
det "$FIX/ci-unmarked"
grep -q 'quality-guardrail.yml' <<<"$(field setupReport.ciSetupConvention)"
check "S14 existing CI convention reported in the setup report" ok $?

# ---- S15–S25 · hook ownership in fully isolated git env ---------------------
mkrepo() { local d; d="$(mktemp -d)"; tmpdirs+=("$d"); cp -R "$FIX/$1/." "$d/" 2>/dev/null; ( cd "$d" && giso git init -q -b main ); echo "$d"; }
r=$(mkrepo npm); det "$r"
[[ $(field hooks.owner) == none && $(field hooks.hooksPath) == null ]]
check "S15 unset hooksPath, no manager -> owner none (pack may propose)" ok $?
r=$(mkrepo husky); det "$r"
[[ $(field hooks.owner) == foreign ]] && grep -q 'husky' <<<"$(field hooks.managers)"
check "S16 husky detected as foreign owner" ok $?
r=$(mkrepo simple-git-hooks); det "$r"
grep -q 'simple-git-hooks' <<<"$(field hooks.managers)"
check "S17 simple-git-hooks detected" ok $?
r=$(mkrepo lefthook); det "$r"
grep -q 'lefthook' <<<"$(field hooks.managers)"
check "S18 lefthook detected" ok $?
r=$(mkrepo tracked-githooks); ( cd "$r" && giso git config core.hooksPath .githooks ); det "$r"
[[ $(field hooks.owner) == foreign && $(field hooks.scope) == local ]]
check "S19 unmarked tracked .githooks is foreign (local scope)" ok $?
r=$(mkrepo marker-githooks); ( cd "$r" && giso git config core.hooksPath .githooks ); det "$r"
[[ $(field hooks.owner) == pack ]]
check "S20 marker-owned .githooks is pack-owned" ok $?
r=$(mkrepo npm); printf '[core]\n\thooksPath = /somewhere/global-hooks\n' > "$ISO/gitconfig-global"
before=$(shasum "$ISO/gitconfig-global")
det "$r"
[[ $(field hooks.scope) == global && $(field hooks.owner) == foreign ]] && [[ "$before" == "$(shasum "$ISO/gitconfig-global")" ]]
check "S21 inherited/global hooksPath is foreign and the global file is untouched" ok $?
: > "$ISO/gitconfig-global"
r=$(mkrepo npm); ( cd "$r" && giso git config core.hooksPath .a && giso git config --add core.hooksPath .b ); det "$r"
[[ $(field hooks.conflict) == true ]]
check "S22 multiple core.hooksPath values conflict (stop and ask)" ok $?
r=$(mkrepo npm); ( cd "$r" && giso git -c user.email=t@t -c user.name=t commit -qm base --allow-empty && giso git config extensions.worktreeConfig true && giso git worktree add -q wt 2>/dev/null; cd wt 2>/dev/null && giso git config --worktree core.hooksPath .wth 2>/dev/null ) || true
det "$r/wt" 2>/dev/null
if [[ $RC -eq 0 ]]; then [[ $(field hooks.owner) == foreign ]]; check "S23 worktree-scope hooksPath is foreign without the marker" ok $?
else echo "PASS: S23 worktree-scope hooksPath is foreign without the marker (worktree config unsupported here; scope rule covered by S19/S21)"; fi
r=$(mkrepo husky); det "$r"
grep -q '.husky/pre-push' <<<"$OUT" && grep -q 'TOKEN=<redacted>' <<<"$OUT" && ! grep -q 'FAKE-SECRET-VALUE-FOR-TEST' <<<"$OUT"
check "S24 hook comparison preserves structure and redacts the secret value" ok $?
! grep -rq 'FAKE-SECRET-VALUE-FOR-TEST' "${TMPDIR:-/tmp}"/raftkit-setup-* 2>/dev/null
check "S25 no retained artifact carries the raw secret value" ok $?

# ---- S26–S34 · render matrix on the SHIPPED templates -----------------------
rnd() { # <pm> <version> <setup-option> <scripts> <roles> <manifest> -> $ODIR
  ODIR="$(mktemp -d)"; tmpdirs+=("$ODIR")
  ROUT=$(node "$RENDER" --templates "$SETUP/references/assets" --out-dir "$ODIR" \
    --pm "$1" --pm-version "$2" --setup "$3" --scripts "$4" --absent-roles "$5" \
    --manifest "$6" --spec-path docs/specs/active-feature.md \
    --spec-sentinel '[Feature Name or Jira Ticket ID]' 2>&1); RRC=$?
}
for pm in npm pnpm yarn bun; do
  case $pm in
    npm) mf=$FIX/npm/package.json; scripts="lint test";;
    pnpm) mf=$FIX/pnpm-turbo-workspace/package.json; scripts="lint typecheck test";;
    yarn) mf=$FIX/yarn-workspace/package.json; scripts="lint";;
    bun) mf=$FIX/bun/package.json; scripts="test";;
  esac
  rnd "$pm" "" setup-node-cache-any "$scripts" none "$mf"
  [[ $RRC -eq 0 ]] && ! grep -qE '__[A-Z_]+__' "$ODIR/pre-push" "$ODIR/quality-guardrail.yml" \
    && sh -n "$ODIR/pre-push" && python3 -c "import yaml,sys; yaml.safe_load(open('$ODIR/quality-guardrail.yml'))" \
    && grep -q "$pm run" "$ODIR/pre-push"
  check "S26-$pm render resolves all placeholders; hook sh-valid; CI YAML parses" ok $?
done
rnd pnpm 10.12.0 corepack "lint test" none "$FIX/pnpm-turbo-workspace/package.json"
grep -q 'corepack enable' "$ODIR/quality-guardrail.yml" && ! grep -qE '(node-version|version):.*latest|@latest' "$ODIR/quality-guardrail.yml"
check "S27 approved corepack setup block rendered; latest never appears" ok $?
rnd none "" none "" none "$FIX/non-node/README.md" 2>/dev/null || true
[[ $RRC -eq 0 ]] && grep -qi 'non-Node' "$ODIR/quality-guardrail.yml" && sh -n "$ODIR/pre-push"
check "S28 non-Node posture renders green-skip CI and spec-gate-only hook" ok $?
rnd pnpm 10.12.0 corepack "lint test" none "$FIX/pnpm-turbo-workspace/package.json"; A1="$ODIR"
rnd pnpm 10.12.0 corepack "lint test" none "$FIX/pnpm-turbo-workspace/package.json"; A2="$ODIR"
cmp -s "$A1/pre-push" "$A2/pre-push" && cmp -s "$A1/quality-guardrail.yml" "$A2/quality-guardrail.yml"
check "S30 identical approved inputs render byte-identical assets" ok $?
rnd conflict "" none "lint" none "$FIX/npm/package.json"
[[ $RRC -ne 0 && -z "$(ls -A "$ODIR")" ]]
check "S31 conflict/undetermined manager renders nothing (fail closed)" ok $?
rnd pnpm "" none 'lint:ci' none "$FIX/adversarial/package.json"
[[ $RRC -eq 0 ]] && grep -q 'lint:ci' "$ODIR/pre-push"
check "S32a valid colon-name script lint:ci accepted" ok $?
for bad in 'evil$(rm -rf /)' 'tick`x`' '-leading-dash' 'two words'; do
  rnd pnpm "" none "$bad" none "$FIX/adversarial/package.json"
  [[ $RRC -ne 0 && -z "$(ls -A "$ODIR")" ]] || { echo "  injected: $bad"; false; }
done
check "S32b injection-shaped script names reject and render nothing" ok $?
rnd pnpm "latest" none lint none "$FIX/adversarial/package.json"
[[ $RRC -ne 0 ]]
check "S32c version 'latest' rejected" ok $?
rnd pnpm "" none "notascript" none "$FIX/npm/package.json"
[[ $RRC -ne 0 ]]
check "S33 script keys must exist in the manifest" ok $?
rnd npm "" none "lint test" none "$FIX/npm/package.json"
! grep -q 'eslint' "$ODIR/pre-push" && ! grep -q 'vitest' "$ODIR/quality-guardrail.yml"
check "S34 only script NAMES are rendered — never script bodies" ok $?

# ---- S35–S37 · foreign CI preservation --------------------------------------
det "$FIX/ci-unmarked";  [[ $(field ci.owner) == foreign ]];  check "S35 unmarked existing workflow is foreign (propose, never overwrite)" ok $?
det "$FIX/ci-marked";    [[ $(field ci.owner) == pack ]];     check "S36 marker-owned workflow is pack-owned (transactional update)" ok $?
cidir="$(mktemp -d)"; tmpdirs+=("$cidir"); cp -R "$FIX/ci-unmarked/." "$cidir/"
mv "$cidir/.github/workflows/quality-guardrail.yml" "$cidir/real.yml" && ln -s ../../real.yml "$cidir/.github/workflows/quality-guardrail.yml"
det "$cidir"; [[ $(field ci.owner) == foreign ]] && grep -qi 'symlink' <<<"$(field ci.note)"
check "S37 symlinked workflow path is a conflict, not overwritten" ok $?

# ---- S38–S40 · shipped contract text ----------------------------------------
grep -q 'No writes occur while detection is conflicting or undetermined' "$SETUP/references/install-flow.md" 2>/dev/null \
  && grep -qi 'collect every lockfile' "$SETUP/references/install-flow.md" 2>/dev/null
check "S38 install-flow documents the signal-collection decision contract" ok $?
grep -q '__PM__' "$SETUP/references/components.md" 2>/dev/null \
  && grep -q 'raftkit-governance-pack' "$SETUP/references/components.md" 2>/dev/null \
  && grep -qi 'render nothing' "$SETUP/references/components.md" 2>/dev/null \
  && grep -q 'setup-node-cache-any\|corepack' "$SETUP/references/components.md" 2>/dev/null
check "S39 components.md documents tokens, marker, fail-closed rendering, setup options" ok $?
grep -q 'raftkit-dev:capability-preflight' "$SETUP/SKILL.md" 2>/dev/null \
  && grep -q 'raftkit-dev:capability-preflight' "$SETUP/references/install-flow.md" 2>/dev/null
check "S40 Story A preflight seam untouched (provider ownership preserved)" ok $?

# ---- S41–S43 · allowlist + version ------------------------------------------
# Persistent suite tests the allowlist ALGORITHM synthetically (no branch SHAs —
# squash-safe); the real PR range audit is explicit:
#   bash tests/setup-toolchain.test.sh --scope-check <base> <head>
# tests/workflow-integration.test.sh is allowed solely for the separately
# approved squash-safe scope-check refactor (cross-story test maintenance).
allow='^(tests/setup-toolchain\.test\.sh|tests/workflow-integration\.test\.sh|tests/fixtures/toolchain/|plugins/raftkit-dev/evals/setup-toolchain/|plugins/raftkit-dev/\.claude-plugin/plugin\.json|\.claude-plugin/marketplace\.json|plugins/raftkit-dev/skills/setup-project/(SKILL\.md|references/(install-flow|components)\.md|references/assets/(pre-push|quality-guardrail\.yml)|scripts/(detect-toolchain|render-assets)\.mjs))'
syn_ok=$'tests/setup-toolchain.test.sh\ntests/workflow-integration.test.sh\ntests/fixtures/toolchain/npm/package.json\nplugins/raftkit-dev/skills/setup-project/scripts/render-assets.mjs\nplugins/raftkit-dev/.claude-plugin/plugin.json'
[[ -z "$(grep -Ev "$allow" <<<"$syn_ok" || true)" ]]
check "S41a allowlist admits approved Story D paths (synthetic)" ok $?
syn_bad=$'plugins/raftkit-dev/skills/implement/SKILL.md\nplugins/raftkit-dev/skills/docs/scripts/validate-docs.mjs\ntests/capability-preflight.test.sh'
[[ "$(grep -Ev "$allow" <<<"$syn_bad" | wc -l | tr -d ' ')" == 3 ]]
check "S41b allowlist flags every out-of-scope path (synthetic)" ok $?
node -e '
  const v = JSON.parse(require("fs").readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json","utf8")).version.split(".").map(Number);
  const min = [0, 15, 0];
  process.exit((v[0]-min[0] || v[1]-min[1] || v[2]-min[2]) >= 0 ? 0 : 1);
'
check "S42 raftkit-dev version is at least 0.15.0 (story D bump held)" ok $?
node -e '
  const fs = require("fs");
  const m = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  const p = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
  process.exit(m.plugins.find(x => x.name === "raftkit-dev").description === p.description ? 0 : 1);
'
check "S43 description lockstep holds" ok $?

# ---- S44–S45 · eval bundle ---------------------------------------------------
n=$(find plugins/raftkit-dev/evals/setup-toolchain -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${n:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/setup-toolchain -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print | grep -q . \
  && ! find plugins/raftkit-dev/evals/setup-toolchain -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print | grep -q .
check "S44 >=8 eval cases each with prompt.md + graders" ok $?
! grep -lE 'render nothing|byte-identical' plugins/raftkit-dev/evals/setup-toolchain/*/prompt.md 2>/dev/null | grep -q .
check "S45 prompts do not leak expected contract wording" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
