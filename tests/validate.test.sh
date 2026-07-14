#!/usr/bin/env bash
# Proves scripts/validate.sh is a real gate, not a no-op:
#   1. the repo as-is validates (exit 0)
#   2. a malformed marketplace.json fails (exit != 0)
#   3. a plugin change without a version bump fails; with a bump it passes
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

copy_repo() { # fresh copy of the working tree (minus .git) into a new temp dir
  local dst
  dst="$(mktemp -d)"
  tmpdirs+=("$dst")
  tar -cf - --exclude .git --exclude .remember . | tar -xf - -C "$dst"
  echo "$dst"
}

# 1. Green path: the repo itself validates
bash scripts/validate.sh >/dev/null 2>&1
check "valid repo passes" ok $?

# 2. Malformed manifest is rejected
broken="$(copy_repo)"
echo '{ this is not json' > "$broken/.claude-plugin/marketplace.json"
bash "$broken/scripts/validate.sh" >/dev/null 2>&1
check "malformed marketplace.json fails" fail $?

# 3. Version-bump gate: plugin content change vs BASE_REF requires a bump
base="$(copy_repo)"
git -C "$base" init --quiet -b main
git -C "$base" add -A
git -C "$base" -c user.email=test@test -c user.name=test commit --quiet -m base
clone="$(mktemp -d)"
tmpdirs+=("$clone")
git clone --quiet "$base" "$clone/repo"
repo="$clone/repo"

echo "placeholder" > "$repo/plugins/raftkit-core/PLACEHOLDER.md"
git -C "$repo" add -A
git -C "$repo" -c user.email=test@test -c user.name=test commit --quiet -m "change without bump"
(cd "$repo" && BASE_REF=main bash scripts/validate.sh) >/dev/null 2>&1
check "plugin change without version bump fails" fail $?

node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const m = JSON.parse(fs.readFileSync(p, "utf8"));
  const [maj, min, pat] = m.version.split(".").map(Number);
  m.version = [maj, min, pat + 1].join(".");
  fs.writeFileSync(p, JSON.stringify(m, null, 2) + "\n");
' "$repo/plugins/raftkit-core/.claude-plugin/plugin.json"
git -C "$repo" add -A
git -C "$repo" -c user.email=test@test -c user.name=test commit --quiet -m "bump"
(cd "$repo" && BASE_REF=main bash scripts/validate.sh) >/dev/null 2>&1
check "plugin change with version bump passes" ok $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
