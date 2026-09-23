#!/usr/bin/env bash
# Deterministic contract suite for the generalized Hasura capability (R4):
# complete bundle port, deterministic detection/non-detection, every TiAiMe
# assumption parameterized, all safety rules preserved, integrations wired.
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

H=plugins/raftkit-dev/skills/hasura
S=$H/SKILL.md
DETECT=$H/scripts/detect-hasura.mjs

# HR1 · complete bundle: SKILL + 3 refs + 3 top scripts + 5 libs + tests + 18 templates
[[ -f "$S" ]] \
  && [[ -f "$H/references/enum-tables.md" && -f "$H/references/permissions-patterns.md" && -f "$H/references/relationship-naming.md" ]] \
  && [[ -f "$H/scripts/new-migration.sh" && -f "$H/scripts/hasura-query.sh" && -f "$H/scripts/check-schema.sh" ]] \
  && [[ -f "$H/scripts/lib/common.sh" && -f "$H/scripts/lib/dbml_grep.sh" && -f "$H/scripts/lib/fk_parse.sh" && -f "$H/scripts/lib/perms.sh" && -f "$H/scripts/lib/render.sh" ]]
check "HR1 core bundle present (SKILL, 3 references, 3 scripts, 5 libs)" ok $?

# The source bundle has 19 .tmpl files (machine-verified from disk; the Phase-0
# audit's "18" undercounted permission-only, which ships up.sql only).
tmpl_count=$(find "$H/templates" -name '*.tmpl' 2>/dev/null | wc -l | tr -d ' ')
[[ "$tmpl_count" -eq 19 ]]
check "HR2 all 19 migration templates ported" ok $?

test_count=$(find "$H/scripts/tests" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
[[ "$test_count" -ge 8 ]]
check "HR3 ported test suite present (8+ files)" ok $?

# HR4 · deterministic hardcode gate: no TiAiMe identity anywhere in the shipped
# skill (doc mentions of Hasura are fine; project identity is not).
! grep -rliE 'tiaime|ti-origin' "$H" 2>/dev/null | grep -q .
check "HR4 zero TiAiMe project-identity strings in the shipped skill" ok $?

# HR5 · fixed project paths and stages parameterized (not hardcoded literals).
sk=$(joined "$S")
grep -qiE 'discover|detect|configured|Project Profile|convention' <<<"$sk" \
  && ! grep -qE 'services/hasura/migrations/default[^`]*is the migrations dir' <<<"$sk"
check "HR5 paths/stages are discovered or configured, not fixed project literals" ok $?

# HR6 · tenancy scope is convention-driven, not hardcoded to family.
pm=$(joined "$H/scripts/lib/perms.sh")
grep -qE 'TENANCY|SCOPE_|\$\{[A-Z_]*(REL|COLUMN|MEMBER|ACTIVE)' <<<"$pm" \
  && grep -qiE 'deny-by-default|00000000-0000' <<<"$pm"
check "HR6 permission scope is parameterized (tenancy discovered) with deny-by-default fallback" ok $?

# HR7 · all safety rules preserved (verbatim intent) in SKILL.md.
grep -qiE 'never edit.*applied migration|do not edit.*applied' <<<"$sk" \
  && grep -qiE 'up\.sql.*down\.sql|reversible|down reverses' <<<"$sk" \
  && grep -qiE 'confirm.*destructive|destructive.*confirm' <<<"$sk" \
  && grep -qiE 'atomic commit|one .*commit per schema' <<<"$sk" \
  && grep -qiE 'never declare.*admin|admin.*never.*declared|forbidden in YAML' <<<"$sk" \
  && grep -qiE 'admin secret never|never echo|redact' <<<"$sk" \
  && grep -qiE 'local[- ]first|stage=local|only.*local' <<<"$sk"
check "HR7 all safety rules preserved (applied-migration immutability, reversibility, destructive confirm, atomic commit, admin-never-declared, secret redaction, local-first)" ok $?

# HR8 · deterministic detection module: activates on Hasura signals; a
# non-Hasura repo yields nothing.
[[ -f "$DETECT" ]]
check "HR8 detect-hasura.mjs exists" ok $?

if [[ -f "$DETECT" ]]; then
  dt=$(mktemp -d)
  mkdir -p "$dt/hasura/metadata" "$dt/hasura/migrations"
  printf 'version: 3\nendpoint: http://localhost:8080\nmetadata_directory: metadata\n' > "$dt/hasura/config.yaml"
  out=$(node "$DETECT" --root "$dt/hasura" 2>/dev/null); dec=$?
  echo "$out" | grep -qiE 'hasura|detected' && [[ "$dec" -eq 0 ]]
  d1=$?
  nd=$(mktemp -d); printf '{"name":"x"}' > "$nd/package.json"
  out2=$(node "$DETECT" --root "$nd" 2>/dev/null); dec2=$?
  # Non-detection is signalled by exit code and the "no Hasura signals" line;
  # the message intentionally says "does not activate", so match the negative
  # signal precisely rather than the word "activate".
  echo "$out2" | grep -qi 'no Hasura signals' && [[ "$dec2" -ne 0 ]]
  d2=$?
  [[ "$d1" -eq 0 && "$d2" -eq 0 ]]
  check "HR9 detection activates on Hasura signals and stays silent on non-Hasura repos" ok $?
  rm -rf "$dt" "$nd"
else
  check "HR9 detection activates on Hasura signals and stays silent on non-Hasura repos" ok 1
fi

# HR10 · the ported test suite runs green in isolation (the source's own
# safety/behaviour oracle).
if [[ -x "$H/scripts/tests/run.sh" || -f "$H/scripts/tests/run.sh" ]]; then
  ( cd "$H/scripts/tests" && bash run.sh ) >/tmp/hr10.out 2>&1
  check "HR10 ported Hasura unit+integration tests pass in isolation" ok $?
else
  check "HR10 ported Hasura unit+integration tests pass in isolation" ok 1
fi

# HR11 · the source's silently-skipped smoke test is fixed (its REAL_DBML path
# no longer resolves one directory short).
grep -q 'REAL_DBML' "$H/scripts/tests/test_dbml_grep.sh" 2>/dev/null \
  && ! grep -qE 'REAL_DBML=.*\.\./\.\./\.\./\.\./docs/schema.dbml' "$H/scripts/tests/test_dbml_grep.sh" 2>/dev/null
check "HR11 the source's off-by-one REAL_DBML smoke-test path is corrected" ok $?


# HR13 · integrations named: envx, docs parity, setup.
grep -qiE 'envx' <<<"$sk" \
  && grep -qiE 'docs.*(sync|schema|architecture)|schema.*doc' <<<"$sk" \
  && grep -qiE 'raftkit-dev:setup' <<<"$sk"
check "HR13 integrations wired (envx, docs schema sync, preflight/setup)" ok $?

grep -qF 'Load `raftkit-core:rules` first unless it is already in this conversation.' "$S"
check "HR16 SKILL.md loads raftkit-core:rules first" ok $?

# HR17-HR20 · the scaffolder never prompts: --dry-run previews, --write writes,
# a destructive subcommand writes only with --confirmed. Run against a throwaway
# repo with stdin closed (or fed a "y"), under a watchdog, so a prompt goes red.
NM="$PWD/$H/scripts/new-migration.sh"
fx=$(mktemp -d)
git -C "$fx" init -q
mkdir -p "$fx/hasura/migrations/default" "$fx/hasura/metadata/databases/default/tables" "$fx/docs"
printf 'version: 3\n' > "$fx/hasura/config.yaml"
printf 'create-dbml:\n\t@true\n' > "$fx/Makefile"
printf 'Table "users" {\n  "id" uuid [pk, not null]\n  "email" text [not null]\n}\n' > "$fx/docs/schema.dbml"
nm() { ( cd "$fx" && perl -e 'alarm 60; exec @ARGV' bash "$NM" "$@" ) 2>&1; }
tree() { ( cd "$fx" && find . -path ./.git -prune -o -type f -print | sort | xargs cksum ); }
migs() { ls "$fx/hasura/migrations/default" | grep -c "$1"; }

before=$(tree)
out=$(nm --dry-run create-table widgets --col title:text:not_null </dev/null); rc=$?
[[ "$rc" -eq 0 && "$(tree)" == "$before" ]] \
  && grep -q 'up.sql' <<<"$out" && grep -q 'down.sql' <<<"$out" && grep -q 'public_widgets.yaml' <<<"$out" \
  && grep -q 'CREATE TABLE public.widgets' <<<"$out" \
  && nm --write --dry-run create-table widgets --col title:text:not_null </dev/null >/dev/null && [[ "$(tree)" == "$before" ]]
check "HR17 --dry-run prints up.sql, down.sql and the YAML, exits 0 with stdin closed, writes no migration or metadata, and wins over --write" ok $?

out=$(printf 'y\n' | nm create-table widgets --col title:text:not_null); rc=$?
[[ "$rc" -eq 0 && "$(tree)" == "$before" ]] && grep -q 'CREATE TABLE public.widgets' <<<"$out"
check "HR18 no mode flag previews like --dry-run and never reads an answer from stdin" ok $?

out=$(nm create-table widgets --col title:text:not_null --write </dev/null); rc=$?
[[ "$rc" -eq 0 && "$(migs create_widgets)" -eq 1 && -f "$fx/hasura/metadata/databases/default/tables/public_widgets.yaml" ]] \
  && ls "$fx"/hasura/migrations/default/*_create_widgets/up.sql "$fx"/hasura/migrations/default/*_create_widgets/down.sql >/dev/null 2>&1 \
  && grep -qF 'git add hasura/migrations/default/<ts>_<slug>/' <<<"$out" \
  && grep -qF ' hasura/metadata/databases/default/tables/public_widgets.yaml' <<<"$out"
check "HR19 --write writes the migration and the YAML with stdin closed, and names their real paths to commit" ok $?

before=$(tree)
o1=$(nm --write drop-column users email </dev/null); r1=$?
o2=$(nm --write rename column email mail --table users </dev/null); r2=$?
[[ "$r1" -ne 0 && "$r2" -ne 0 && "$(tree)" == "$before" ]] && grep -qi 'explicit OK' <<<"$o1$o2" \
  && nm --write drop-column users email --confirmed </dev/null >/dev/null && [[ "$(migs drop_email_from_users)" -eq 1 ]]
check "HR20 a destructive --write is refused without --confirmed and writes with it" ok $?
rm -rf "$fx"

# HR21 · script paths are skill-relative. Claude Code substitutes
# ${CLAUDE_SKILL_DIR} in SKILL.md only, so SKILL.md runs every script through it;
# a reference carries no variable or .claude/skills path; every scripts/ path resolves.
bad_refs=$(grep -lE '\$\{CLAUDE_[A-Z_]+\}|\.claude/skills/' "$H"/references/*.md | tr '\n' ' ')
unprefixed=$(grep -oE '[^ `(]*scripts/[A-Za-z0-9_./-]*[A-Za-z0-9_]' "$S" | grep -v '^\${CLAUDE_SKILL_DIR}/scripts/' | tr '\n' ' ')
named=$(grep -ohE 'scripts/[A-Za-z0-9_./-]*[A-Za-z0-9_]' "$S" "$H"/references/*.md | sort -u)
missing=$(while read -r p; do [[ -e "$H/$p" ]] || echo "$p"; done <<<"$named" | tr '\n' ' ')
# A named script is run bare, so it ships executable (the git mode, not only the
# checkout's); lib/ is sourced, never run.
noexec=$(grep -v '^scripts/lib/' <<<"$named" | while read -r p; do
  [[ -f "$H/$p" ]] || continue
  [[ -x "$H/$p" && "$(git ls-files -s -- "$H/$p" | cut -c1-6)" != 100644 ]] || echo "$p"
done | tr '\n' ' ')
[[ -z "$bad_refs$unprefixed$missing$noexec" ]] && grep -qF '${CLAUDE_SKILL_DIR}/scripts/new-migration.sh' "$S"
check "HR21 script paths are skill-relative, every one resolves and runs bare${bad_refs:+ (refs: $bad_refs)}${unprefixed:+ (unprefixed: $unprefixed)}${missing:+ (missing: $missing)}${noexec:+ (not executable: $noexec)}" ok $?

# HR22 · detect-hasura.mjs finds the same Hasura root as lib/common.sh
# find_hasura_root: the root, then */, then */*/, hidden directories skipped.
# An argument is a Hasura project dir; <dir>+plain holds a non-Hasura
# config.yaml, <dir>+dir is an empty directory.
parity() {
  local fx; fx=$(mktemp -d); local p
  for p in "$@"; do case "$p" in
    *+dir) mkdir -p "$fx/${p%+dir}" ;;
    *+plain) mkdir -p "$fx/${p%+plain}"; printf 'foo: bar\n' > "$fx/${p%+plain}/config.yaml" ;;
    *) mkdir -p "$fx/$p"; printf 'version: 3\n' > "$fx/$p/config.yaml" ;;
  esac; done
  local d f
  d=$(node "$DETECT" --root "$fx" --json 2>/dev/null \
    | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{try{process.stdout.write(JSON.parse(s).conventions.hasuraRoot||"")}catch{}})')
  f=$(bash -c 'source "$0"; find_hasura_root "$1"' "$H/scripts/lib/common.sh" "$fx" 2>/dev/null)
  printf '%s|%s' "${d#"$fx"}" "${f#"$fx"}"
  rm -rf "$fx"
}
pr=""
[[ "$(parity services/hasura)" == "/services/hasura|/services/hasura" ]] || pr+=" depth-2"
[[ "$(parity zeta apps/hasura)" == "/zeta|/zeta" ]] || pr+=" depth-1-first"
[[ "$(parity b/h a/h)" == "/a/h|/a/h" ]] || pr+=" sorted"
[[ "$(parity .hidden infra/hasura)" == "/infra/hasura|/infra/hasura" ]] || pr+=" hidden-skipped"
[[ "$(parity a/b/c)" == "|" ]] || pr+=" depth-3-ignored"
[[ "$(parity .+plain services/hasura)" == "/services/hasura|/services/hasura" ]] || pr+=" non-hasura-root-config"
[[ "$(parity migrations+dir metadata+dir services/hasura)" == "/services/hasura|/services/hasura" ]] || pr+=" root-dirs-still-scan"
[[ -z "$pr" ]]
check "HR22 detect-hasura.mjs scans to find_hasura_root's depth and order${pr:+ (diverged:$pr)}" ok $?

# HR23-HR24 · .raftkit/hasura.json is written by detect-hasura.mjs --write, in
# the documented schema, and nothing else writes it.
cx=$(mktemp -d)
mkdir -p "$cx/services/hasura/metadata/databases/default/tables" "$cx/services/hasura/migrations/default"
printf 'version: 3\nmetadata_directory: metadata\nmigrations_directory: migrations\n' > "$cx/services/hasura/config.yaml"
printf 'table:\n  name: users\nselect_permissions:\n  - role: user\n  - role: anonymous\n  - role: admin\ninsert_permissions:\n  - role: user\n' \
  > "$cx/services/hasura/metadata/databases/default/tables/public_users.yaml"
printf 'X := 1\nbuild:\n\t@true\nhasura-migrate:\n\t@true\ncreate-dbml: build\n\t@true\n' > "$cx/Makefile"
CACHE="$cx/.raftkit/hasura.json"
node "$DETECT" --root "$cx" >/dev/null 2>&1 && [[ ! -e "$CACHE" ]]; r0=$?
node "$DETECT" --root "$cx" --write --env BOGUS=1 >/dev/null 2>&1; rb=$?
[[ ! -e "$CACHE" ]]; r1=$?
node "$DETECT" --root "$cx" --write --env TENANCY_COLUMN=org_id >/dev/null 2>&1; rw=$?
CACHE="$CACHE" node -e '
const got = JSON.parse(require("fs").readFileSync(process.env.CACHE, "utf8"));
const want = { schema: 1, hasuraRoot: "services/hasura", database: "default", roles: ["anonymous", "user"],
  makeTargets: ["create-dbml", "hasura-migrate"],
  env: { HASURA_ROOT: "services/hasura", HASURA_MIGRATIONS_SUBDIR: "migrations/default", HASURA_METADATA_SUBDIR: "metadata/databases/default/tables", TENANCY_COLUMN: "org_id" } };
process.exit(JSON.stringify(got) === JSON.stringify(want) ? 0 : 1);' 2>/dev/null; rj=$?
nx=$(mktemp -d); node "$DETECT" --root "$nx" --write >/dev/null 2>&1; rn=$?
[[ "$r0" -eq 0 && "$rb" -eq 2 && "$r1" -eq 0 && "$rw" -eq 0 && "$rj" -eq 0 && "$rn" -eq 1 && ! -e "$nx/.raftkit" ]]
check "HR23 detect-hasura.mjs --write records the conventions in .raftkit/hasura.json; a plain run, an unknown --env or a non-Hasura repo writes nothing" ok $?

undoc=""
if [[ -f "$CACHE" ]]; then
  for k in $(CACHE="$CACHE" node -e 'const j=JSON.parse(require("fs").readFileSync(process.env.CACHE,"utf8"));console.log([...Object.keys(j),...Object.keys(j.env)].join(" "))') \
      $(node -e 'const m=require("fs").readFileSync(process.argv[1],"utf8").match(/ENV_NAMES = \[([^\]]*)\]/);console.log(m?m[1].match(/[A-Z_]+/g).join(" "):"ENV_NAMES_NOT_FOUND")' "$DETECT"); do
    grep -qF "\`$k\`" "$H/references/conventions.md" || undoc+=" $k"
  done
else undoc=" (no cache written)"; fi
[[ -z "$undoc" ]] && ! grep -rqE 'hasura\.json' "$H/scripts" --include='*.sh'
check "HR24 every key the cache can hold is documented in conventions.md${undoc:+ (undocumented:$undoc)}" ok $?
rm -rf "$cx" "$nx"

# HR25 · several candidate roots are all reported and --write needs the chosen
# one; the cache pins it as env.HASURA_ROOT, and the scaffolder run with that
# env writes under it from any directory (find_hasura_root alone picks apps/).
ax=$(mktemp -d)
git -C "$ax" init -q
for r in apps/hasura services/hasura; do
  mkdir -p "$ax/$r/migrations/default" "$ax/$r/metadata/databases/default/tables"
  printf 'version: 3\n' > "$ax/$r/config.yaml"
done
mkdir -p "$ax/docs"
printf 'create-dbml:\n\t@true\n' > "$ax/Makefile"
printf 'Table "users" {\n  "id" uuid [pk, not null]\n}\n' > "$ax/docs/schema.dbml"
sig=$(node "$DETECT" --root "$ax" --json 2>/dev/null)
grep -q 'apps/hasura' <<<"$sig" && grep -q 'services/hasura' <<<"$sig"; ra=$?
node "$DETECT" --root "$ax" --write >/dev/null 2>&1; rw=$?
[[ ! -e "$ax/.raftkit" ]]; rn=$?
node "$DETECT" --root "$ax" --write --env HASURA_ROOT=services/hasura >/dev/null 2>&1; rc=$?
cenv=$(node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(j.hasuraRoot!=="services/hasura")process.exit(1);for(const[k,v]of Object.entries(j.env))console.log(`${k}=${v}`)' "$ax/.raftkit/hasura.json" 2>/dev/null)
( cd "$ax/apps" && env $cenv perl -e 'alarm 60; exec @ARGV' bash "$NM" create-table widgets --col title:text --write </dev/null ) >/dev/null 2>&1; rs=$?
[[ "$ra" -eq 0 && "$rw" -ne 0 && "$rn" -eq 0 && "$rc" -eq 0 && "$cenv" == *HASURA_ROOT=services/hasura* && "$rs" -eq 0 ]] \
  && ls "$ax"/services/hasura/migrations/default/*_create_widgets/up.sql >/dev/null 2>&1 \
  && [[ -f "$ax/services/hasura/metadata/databases/default/tables/public_widgets.yaml" ]] \
  && ! find "$ax/apps" -name '*widgets*' | grep -q .
check "HR25 several candidate roots are reported, --write needs the chosen one, and the cache's env.HASURA_ROOT steers the scaffolder from any directory" ok $?
rm -rf "$ax"

eval_count=$(find plugins/raftkit-dev/evals/hasura -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[[ "${eval_count:-0}" -ge 8 ]] \
  && ! find plugins/raftkit-dev/evals/hasura -mindepth 1 -maxdepth 1 -type d '!' -exec test -f '{}/prompt.md' ';' -print 2>/dev/null | grep -q . \
  && ! find plugins/raftkit-dev/evals/hasura -mindepth 1 -maxdepth 1 -type d '!' -exec sh -c 'ls "$1"/graders/*.md >/dev/null 2>&1' _ '{}' ';' -print 2>/dev/null | grep -q .
check "HR14 at least eight hasura eval cases each include a prompt and grader" ok $?

node - <<'NODE'
const fs = require("fs");
const dev = JSON.parse(fs.readFileSync("plugins/raftkit-dev/.claude-plugin/plugin.json", "utf8"));
const market = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
const a = dev.version.split(".").map(Number), min = [0,20,0];
if ((a[0]-min[0] || a[1]-min[1] || a[2]-min[2]) < 0) process.exit(1);
if (market.plugins.find((p) => p.name === "raftkit-dev").description !== dev.description) process.exit(1);
NODE
check "HR15 manifest at least 0.20.0 with marketplace description lockstep" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
