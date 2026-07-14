#!/usr/bin/env bash
# CI gate for the raftkit marketplace. Non-zero exit on any failure.
# Set BASE_REF (PR base branch) to also enforce version bumps on changed plugins.
set -euo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob

fail() { echo "FAIL: $1" >&2; exit 1; }

json_version_file() {
  node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version ?? "")' "$1"
}

json_version_stdin() {
  node -e 'let s = ""; process.stdin.on("data", d => s += d).on("end", () => { try { process.stdout.write(String(JSON.parse(s).version ?? "")) } catch { process.stdout.write("") } })'
}

command -v claude >/dev/null 2>&1 || fail "claude CLI not found on PATH"

claude plugin validate . || fail "marketplace validation failed"

for dir in plugins/*/; do
  claude plugin validate "$dir" || fail "plugin validation failed: $dir"
done

# A content change only reaches installed machines via a version bump (versions are
# pinned in plugin.json), so a changed plugin dir must also change its version.
if [[ -n "${BASE_REF:-}" ]]; then
  git fetch --quiet origin "$BASE_REF"
  for dir in plugins/*/; do
    git diff --quiet FETCH_HEAD HEAD -- "$dir" && continue
    manifest="${dir}.claude-plugin/plugin.json"
    base_ver="$(git show "FETCH_HEAD:$manifest" 2>/dev/null | json_version_stdin || true)"
    head_ver="$(json_version_file "$manifest")"
    [[ "$head_ver" != "$base_ver" ]] || fail "$(basename "$dir") changed without a version bump (still $head_ver)"
  done
fi

echo "OK: marketplace and all plugin manifests valid"
