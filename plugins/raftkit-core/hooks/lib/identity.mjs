// Resolves who is running RaftKit.
//
// This is an internal RaftLabs tool and identity is the point: the team needs to
// know who is and is not using it. Values come from git config and `gh`, which
// every developer already has configured (both are install prerequisites).
//
// Resolution shells out, so it is cached — a week is short enough to pick up a
// new machine or a changed email, long enough to stay off the hot path.
//
// Split by cost, not by kind: identity() is local-only and safe to call from the
// synchronous SessionStart hook, while the GitHub login costs a network round
// trip and is resolved by the async flush path alone. Both still reach the
// endpoint on every event.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import {
  LOCAL_EXEC_TIMEOUT,
  dataDir,
  ensureDir,
  safeExec,
  sha,
  stateFile,
  parseJson,
} from "./common.mjs";

const TTL_MS = 7 * 24 * 60 * 60 * 1000;
// A resolve that produced nothing is a transient condition (git not configured
// yet, HOME not mounted), not a fact worth pinning for a week. Cached like a
// success it stays sticky and every later event is attributed to `anon:`.
const MISS_TTL_MS = 10 * 60 * 1000;
const GH_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const GH_MISS_TTL_MS = 60 * 60 * 1000;

const osUser = () => process.env.USER || process.env.USERNAME || "";

/**
 * Read the cached GitHub login without resolving it.
 * Cheap enough for the synchronous path: one small file read, no subprocess.
 */
function cachedGhLogin() {
  try {
    const cached = parseJson(readFileSync(stateFile("gh-login.json"), "utf8"));
    return typeof cached.gh_login === "string" ? cached.gh_login : "";
  } catch {
    return "";
  }
}

function resolveLocal() {
  // Run git from HOME, never from the current repo.
  //
  // Without a cwd this inherits the hook's, so opening one client repo with a
  // repo-local user.email pins that client's address as the developer's identity
  // for the whole TTL — across every other repo they touch. HOME resolves the
  // global config, which is the person, not the project.
  const opts = { cwd: process.env.HOME || undefined, timeout: LOCAL_EXEC_TIMEOUT };
  const email = safeExec("git", ["config", "--get", "user.email"], opts);
  const name = safeExec("git", ["config", "--get", "user.name"], opts);
  const ghLogin = cachedGhLogin();
  const machine = sha(hostname() || "unknown", 8);

  return {
    // Email is stable, human-readable, and joins directly against the admin
    // dashboard's roster table. With no git identity at all the developer still
    // counts toward "how many people", just without a name attached.
    distinct_id: email || (ghLogin ? `gh:${ghLogin}` : `anon:${machine}`),
    name,
    email,
    gh_login: ghLogin,
    os_user: osUser(),
    machine,
    resolved_at: Date.now(),
  };
}

export function identity() {
  const cachePath = stateFile("identity.json");
  try {
    if (existsSync(cachePath)) {
      const cached = parseJson(readFileSync(cachePath, "utf8"));
      const age = Date.now() - (cached.resolved_at || 0);
      const ttl = cached.email ? TTL_MS : MISS_TTL_MS;
      // A shared HOME means a shared cache. Without this check every developer
      // on the box reports as whoever resolved first.
      const mine = (cached.os_user || "") === osUser();
      if (cached.distinct_id && mine && age < ttl) return cached;
    }
  } catch {
    /* fall through and re-resolve */
  }

  const fresh = resolveLocal();
  try {
    ensureDir(dataDir());
    writeFileSync(cachePath, JSON.stringify(fresh, null, 2) + "\n");
  } catch {
    /* an uncacheable identity still works, just slower */
  }
  return fresh;
}

/**
 * GitHub login — resolved here and ONLY from the async flush path.
 *
 * `gh api user` is a network round trip. On the synchronous SessionStart hook it
 * cost up to 4s of dead air before the prompt rendered whenever `gh` was
 * unreachable (VPN down, offline), and it was the call that pushed that hook's
 * worst case past its own declared timeout — at which point the harness killed
 * the run and the one-time disclosure was discarded with it.
 *
 * Nothing is lost from the data by moving it: flush merges the login into every
 * event's person properties exactly as before, and back-fills the identity cache
 * so the next session's distinct_id can use it too.
 */
export function githubLogin() {
  const cachePath = stateFile("gh-login.json");
  try {
    if (existsSync(cachePath)) {
      const cached = parseJson(readFileSync(cachePath, "utf8"));
      const age = Date.now() - (cached.resolved_at || 0);
      const ttl = cached.gh_login ? GH_TTL_MS : GH_MISS_TTL_MS;
      if ((cached.os_user || "") === osUser() && age < ttl) return cached.gh_login || "";
    }
  } catch {
    /* fall through and re-resolve */
  }

  const login = safeExec("gh", ["api", "user", "--jq", ".login"], { timeout: 4000 });
  try {
    ensureDir(dataDir());
    writeFileSync(
      cachePath,
      JSON.stringify({ gh_login: login, os_user: osUser(), resolved_at: Date.now() }) + "\n",
    );
  } catch {
    /* uncached is slower, never wrong */
  }
  return login;
}
