#!/usr/bin/env bash
# CI gate for the raftkit marketplace. Non-zero exit on any failure.
# Set BASE_REF (PR base branch) to also enforce version bumps on changed plugins.
set -euo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob

fail() { echo "FAIL: $1" >&2; exit 1; }

json_version_stdin() {
  node -e 'let s = ""; process.stdin.on("data", d => s += d).on("end", () => { try { process.stdout.write(String(JSON.parse(s).version ?? "")) } catch { process.stdout.write("") } })'
}

command -v claude >/dev/null 2>&1 || fail "claude CLI not found on PATH"

claude plugin validate . || fail "marketplace validation failed"

for dir in plugins/*/; do
  claude plugin validate "$dir" || fail "plugin validation failed: $dir"
done

# Marketplace entry descriptions must not drift from the plugin manifests.
node -e '
  const fs = require("fs");
  const cat = JSON.parse(fs.readFileSync(".claude-plugin/marketplace.json", "utf8"));
  for (const p of cat.plugins) {
    const m = JSON.parse(fs.readFileSync(`${p.source}/.claude-plugin/plugin.json`, "utf8"));
    if (p.description !== m.description) {
      console.error(`description drift for ${p.name}: marketplace entry != plugin.json`);
      process.exit(1);
    }
  }
' || fail "description drift between marketplace.json and a plugin manifest"

# A content change only reaches installed machines via a version bump (versions are
# pinned in plugin.json), so a changed plugin dir must also change its version.
# Both the diff and the base version are anchored at the merge base — a bump that
# landed on the base branch after this branch diverged must not mask a missing bump
# here. Needs real history: CI checks out with fetch-depth: 0.
if [[ -n "${BASE_REF:-}" ]]; then
  git fetch --quiet origin "$BASE_REF"
  mb="$(git merge-base FETCH_HEAD HEAD)" || fail "cannot determine merge base with origin/$BASE_REF"
  for dir in plugins/*/; do
    git diff --quiet "$mb" HEAD -- "$dir" && continue
    manifest="${dir}.claude-plugin/plugin.json"
    base_ver="$(git show "$mb:$manifest" 2>/dev/null | json_version_stdin || true)"
    head_ver="$(git show "HEAD:$manifest" 2>/dev/null | json_version_stdin || true)"
    [[ -n "$head_ver" && "$head_ver" != "$base_ver" ]] || fail "$(basename "$dir") changed without a version bump (still ${head_ver:-missing})"
  done
fi

echo "OK: marketplace and all plugin manifests valid"
