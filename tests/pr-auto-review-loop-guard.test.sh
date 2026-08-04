#!/usr/bin/env bash
# Proves the pr-auto-review self-trigger loop guard in isolation. The guard
# skips on EITHER of two signals the workflow itself controls: the rendered
# bot author email, or the pr-auto-review-commit trailer on HEAD. A human
# commit carrying neither must proceed.
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
tmpdirs=()
cleanup() { for d in "${tmpdirs[@]:-}"; do [[ -n "$d" ]] && rm -rf "$d"; done; }
trap cleanup EXIT

# The canonical bot identity. Pinned here, defaulted by the renderer, and
# documented in the skill's references/install.md — the three must agree or a
# re-install silently stops recognising the previous install's commits.
BOT_EMAIL="pr-auto-review@raftlabs.com"

# Mirrors the guard step in references/assets/pr-auto-review.yml.
guard_skip() { # <repo dir> -> prints "true" or "false"
  (cd "$1" && \
   AUTHOR_EMAIL="$(git log -1 --pretty=format:'%ae')" && \
   TRAILER_HITS="$(git log -1 --pretty=format:'%B' | grep -c '^pr-auto-review-commit: true[[:space:]]*$' || true)" && \
   if [ "$AUTHOR_EMAIL" = "$BOT_EMAIL" ] || [ "$TRAILER_HITS" -gt 0 ]; then echo "true"; else echo "false"; fi)
}

new_repo() { # <email> <name> <commit message> -> prints repo dir
  local d; d=$(mktemp -d); tmpdirs+=("$d")
  git -C "$d" init -q
  git -C "$d" config user.email "$1"
  git -C "$d" config user.name "$2"
  echo hello > "$d/file.txt"
  git -C "$d" add file.txt
  git -C "$d" commit -q -m "$3"
  echo "$d"
}

expect() { # <name> <expected> <actual>
  if [[ "$3" == "$2" ]]; then echo "PASS: $1"; else echo "FAIL: $1 (expected $2, got $3)"; failures=$((failures+1)); fi
}

# G1 — a normal human commit: neither signal present, must proceed.
r1=$(new_repo "dev@example.com" "A Developer" "feat: add file")
expect "G1 human commit does not skip" "false" "$(guard_skip "$r1")"

# G2 — the bot's own fix commit: both signals present, must skip.
r2=$(new_repo "$BOT_EMAIL" "RaftKit PR Auto-Review" "$(printf 'fix: something\n\npr-auto-review-commit: true')")
expect "G2 bot commit (both signals) skips" "true" "$(guard_skip "$r2")"

# G3 — author email alone (message body lost to a squash or an amend that
# dropped the trailer). The email signal must still catch it.
r3=$(new_repo "$BOT_EMAIL" "RaftKit PR Auto-Review" "fix: something")
expect "G3 bot author email alone skips" "true" "$(guard_skip "$r3")"

# G4 — trailer alone. `git rebase` and `git cherry-pick -x` preserve the
# message while a rewrite can reattribute the author, so the trailer is the
# second, independent signal. Checking only the author email misses this and
# the workflow would re-review — and re-fix — its own commit.
r4=$(new_repo "dev@example.com" "A Developer" "$(printf 'fix: something\n\npr-auto-review-commit: true')")
expect "G4 trailer alone skips" "true" "$(guard_skip "$r4")"

# G5 — a human commit that merely MENTIONS the trailer in prose must not trip
# the guard: the match is anchored to its own line, not a loose substring.
r5=$(new_repo "dev@example.com" "A Developer" "$(printf 'docs: explain the pr-auto-review-commit: true trailer\n\nSee references/fix-loop.md.')")
expect "G5 prose mention of the trailer does not skip" "false" "$(guard_skip "$r5")"

echo "----"
if [[ "$failures" -eq 0 ]]; then
  echo "OK: loop-guard logic verified in isolation"
else
  echo "FAIL: $failures check(s) failed"
  exit 1
fi
