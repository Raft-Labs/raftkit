#!/usr/bin/env bash
# Proves scripts/validate.sh is a real gate, not a no-op:
#   1. the repo as-is validates (exit 0)
#   2. a malformed marketplace.json fails (exit != 0)
#   3. a plugin change without a version bump fails; with a bump it passes
#   4. a bump that landed on the base branch does not mask a missing bump here
set -uo pipefail
cd "$(dirname "$0")/.."
unset BASE_REF # checks 1-2 must not exercise the bump gate; later checks set it explicitly

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

copy_repo_into() { # populate an existing dir with the working tree (minus .git)
  tar -cf - --exclude .git --exclude .remember . | tar -xf - -C "$1"
}

commit_all() { # <repo> <message>
  git -C "$1" add -A
  git -C "$1" -c user.email=test@test -c user.name=test commit --quiet -m "$2"
}

bump_patch() { # <plugin.json path>
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const m = JSON.parse(fs.readFileSync(p, "utf8"));
    const [maj, min, pat] = m.version.split(".").map(Number);
    m.version = [maj, min, pat + 1].join(".");
    fs.writeFileSync(p, JSON.stringify(m, null, 2) + "\n");
  ' "$1"
}

# 1. Green path: the repo itself validates
bash scripts/validate.sh >/dev/null 2>&1
check "valid repo passes" ok $?

# 2. Malformed manifest is rejected
broken="$(mktemp -d)"
tmpdirs+=("$broken")
copy_repo_into "$broken" || { echo "FATAL: repo copy failed"; exit 1; }
echo '{ this is not json' > "$broken/.claude-plugin/marketplace.json"
bash "$broken/scripts/validate.sh" >/dev/null 2>&1
check "malformed marketplace.json fails" fail $?

# 3. Version-bump gate: plugin content change vs BASE_REF requires a bump
base="$(mktemp -d)"
tmpdirs+=("$base")
copy_repo_into "$base" || { echo "FATAL: repo copy failed"; exit 1; }
git -C "$base" init --quiet -b main
commit_all "$base" base

clone="$(mktemp -d)"
tmpdirs+=("$clone")
git clone --quiet "$base" "$clone/repo"
repo="$clone/repo"

echo "placeholder" > "$repo/plugins/raftkit-core/PLACEHOLDER.md"
commit_all "$repo" "change without bump"
(cd "$repo" && BASE_REF=main bash scripts/validate.sh) >/dev/null 2>&1
check "plugin change without version bump fails" fail $?

bump_patch "$repo/plugins/raftkit-core/.claude-plugin/plugin.json"
commit_all "$repo" bump
(cd "$repo" && BASE_REF=main bash scripts/validate.sh) >/dev/null 2>&1
check "plugin change with version bump passes" ok $?

# 4. Merge-base anchoring: a bump on the base after this branch diverged
#    must not mask this branch's missing bump
mask="$(mktemp -d)"
tmpdirs+=("$mask")
git clone --quiet "$base" "$mask/repo"
repo2="$mask/repo"

bump_patch "$base/plugins/raftkit-core/.claude-plugin/plugin.json"
commit_all "$base" "base bumps core after divergence"

echo "unshipped" > "$repo2/plugins/raftkit-core/PLACEHOLDER2.md"
commit_all "$repo2" "change without bump, base bumped meanwhile"
(cd "$repo2" && BASE_REF=main bash scripts/validate.sh) >/dev/null 2>&1
check "base-branch bump does not mask a missing bump" fail $?

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
