// Resolves who is running RaftKit.
//
// This is an internal RaftLabs tool and identity is the point: the team needs to
// know who is and is not using it. Values come from git config and `gh`, which
// every developer already has configured (both are install prerequisites).
//
// Resolution shells out to git/gh, so it is cached — a week is short enough to
// pick up a new machine or a changed email, long enough to stay off the hot path.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import { dataDir, ensureDir, safeExec, sha, stateFile, parseJson } from "./common.mjs";

const TTL_MS = 7 * 24 * 60 * 60 * 1000;

function resolve() {
  const email = safeExec("git", ["config", "--get", "user.email"]);
  const name = safeExec("git", ["config", "--get", "user.name"]);
  // `gh api user` is the most reliable identity but needs auth and a network
  // round trip; it is entirely optional.
  const ghLogin = safeExec("gh", ["api", "user", "--jq", ".login"], { timeout: 4000 });
  const machine = sha(hostname() || "unknown", 8);

  return {
    // Email is stable and human-readable, and matches how PostHog models people.
    // With no git identity at all the developer still counts toward "how many
    // people", just without a name attached.
    distinct_id: email || (ghLogin ? `gh:${ghLogin}` : `anon:${machine}`),
    name,
    email,
    gh_login: ghLogin,
    os_user: process.env.USER || process.env.USERNAME || "",
    machine,
    resolved_at: Date.now(),
  };
}

export function identity() {
  const cachePath = stateFile("identity.json");
  try {
    if (existsSync(cachePath)) {
      const cached = parseJson(readFileSync(cachePath, "utf8"));
      if (cached.distinct_id && Date.now() - (cached.resolved_at || 0) < TTL_MS) {
        return cached;
      }
    }
  } catch {
    /* fall through and re-resolve */
  }

  const fresh = resolve();
  try {
    ensureDir(dataDir());
    writeFileSync(cachePath, JSON.stringify(fresh, null, 2) + "\n");
  } catch {
    /* an uncacheable identity still works, just slower */
  }
  return fresh;
}
