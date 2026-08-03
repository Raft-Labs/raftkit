#!/usr/bin/env bash
# Proves the pr-auto-review self-trigger loop guard in isolation: a normal
# human commit should proceed, a commit authored as the bot should skip.
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
tmpdirs=()
cleanup() { for d in "${tmpdirs[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done; }
trap cleanup EXIT

BOT_EMAIL="pr-auto-review@raftlabs.com"

guard_skip() { # <repo dir> -> prints "true" or "false"
  (cd "$1" && \
   AUTHOR_EMAIL="$(git log -1 --pretty=format:'%ae')" && \
   if [ "$AUTHOR_EMAIL" = "$BOT_EMAIL" ]; then echo "true"; else echo "false"; fi)
}

# Fixture 1 — a normal human commit.
r1=$(mktemp -d); tmpdirs+=("$r1")
git -C "$r1" init -q
git -C "$r1" config user.email "dev@example.com"
git -C "$r1" config user.name "A Developer"
echo hello > "$r1/file.txt"
git -C "$r1" add file.txt
git -C "$r1" commit -q -m "feat: add file"
result1=$(guard_skip "$r1")
if [[ "$result1" == "false" ]]; then echo "PASS: human commit does not skip"; else echo "FAIL: human commit incorrectly skipped ($result1)"; failures=$((failures+1)); fi

# Fixture 2 — a commit authored as the bot (simulating pr-auto-review's own fix commit).
r2=$(mktemp -d); tmpdirs+=("$r2")
git -C "$r2" init -q
git -C "$r2" config user.email "$BOT_EMAIL"
git -C "$r2" config user.name "RaftKit PR Auto-Review"
echo hello > "$r2/file.txt"
git -C "$r2" add file.txt
git -C "$r2" commit -q -m "$(printf 'fix: something\n\npr-auto-review-commit: true')"
result2=$(guard_skip "$r2")
if [[ "$result2" == "true" ]]; then echo "PASS: bot commit correctly skips"; else echo "FAIL: bot commit did not skip ($result2)"; failures=$((failures+1)); fi

echo "----"
if [[ "$failures" -eq 0 ]]; then
  echo "OK: loop-guard logic verified in isolation"
else
  echo "FAIL: $failures check(s) failed"
  exit 1
fi
