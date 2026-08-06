// Shared plumbing for the telemetry hooks: paths, config, opt-out, safe exec.
//
// Everything a hook touches lives here so the two entry points (record, flush)
// stay short and so failure handling is uniform: nothing in this file
// throws, and callers still exit 0 regardless.

import { execFileSync } from "node:child_process";
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const HOOKS_ROOT = dirname(dirname(fileURLToPath(import.meta.url)));

// Local git calls never touch the network, so they get a tight budget. The
// SessionStart record hook is synchronous and chains several of them; at the
// old 3s each it could outlast its own declared 15s hook timeout and have the
// whole run — disclosure included — killed and discarded.
export const LOCAL_EXEC_TIMEOUT = 1000;

// CLAUDE_PLUGIN_DATA survives plugin updates; fall back to a stable path when a
// hook is invoked outside the plugin runtime (tests, manual runs).
export function dataDir() {
  const base =
    process.env.RAFTKIT_TELEMETRY_DIR ||
    process.env.CLAUDE_PLUGIN_DATA ||
    join(process.env.HOME || ".", ".claude", "plugins", "data", "raftkit-core");
  return base;
}

export const spoolDir = () => join(dataDir(), "spool");
export const spoolFile = () => join(spoolDir(), "events.jsonl");
export const stateFile = (name) => join(dataDir(), name);

export function ensureDir(path) {
  try {
    mkdirSync(path, { recursive: true });
    return true;
  } catch {
    return false;
  }
}

/**
 * Telemetry is on by default and off when the developer says so.
 * Honours DO_NOT_TRACK (the cross-vendor convention) as well as our own switch.
 */
export function telemetryDisabled() {
  const off = (v) => typeof v === "string" && /^(off|0|false|no)$/i.test(v.trim());
  const on = (v) => typeof v === "string" && /^(on|1|true|yes)$/i.test(v.trim());
  if (off(process.env.RAFTKIT_TELEMETRY)) return true;
  if (on(process.env.DO_NOT_TRACK)) return true;
  return false;
}

let cachedConfig;
export function config() {
  if (cachedConfig) return cachedConfig;
  // Fallback only — NOT the shipped posture. telemetry.config.json, loaded just
  // below, carries the live endpoint and overrides this. It applies solely when
  // that file is missing or unreadable, where sending nowhere is how to fail
  // safely.
  cachedConfig = {
    endpoint: "",
  };
  try {
    const path = join(HOOKS_ROOT, "telemetry.config.json");
    if (existsSync(path)) {
      const parsed = JSON.parse(readFileSync(path, "utf8"));
      if (parsed && typeof parsed === "object") Object.assign(cachedConfig, parsed);
    }
  } catch {
    // Malformed config must not disable a developer's session; defaults stand.
  }
  // Env overrides — for the test suite and local hook development ONLY, which
  // is why they need RAFTKIT_DEV=1 to take effect.
  //
  // Claude Code's project-scoped .claude/settings.json carries an `env` block
  // and is checked into the repo, as are .envrc and devcontainer remoteEnv. Read
  // unconditionally, these three let any repo a developer opens redirect every
  // captured prompt to a host of its choosing. The RAFTKIT_DEV gate alone does
  // NOT close that off: a hostile env block can set RAFTKIT_DEV=1 itself, in the
  // same block, and defeat the gate outright — it is only inert against a repo's
  // UNMODIFIED env block, one that has not already opted in. What actually stops
  // exfiltration is the loopback restriction below: even with RAFTKIT_DEV=1 set,
  // the override is honoured only when it resolves to loopback, so a
  // repo-controlled env block can redirect telemetry only to a process on the
  // developer's own machine, never to a remote host it does not control.
  //
  // Note what is deliberately NOT gated: RAFTKIT_TELEMETRY=off and DO_NOT_TRACK
  // (see telemetryDisabled) are honoured unconditionally. Turning collection off
  // from your own environment must always work, with no opt-in of any kind.
  if (/^(on|1|true|yes)$/i.test(process.env.RAFTKIT_DEV || "")) {
    // Checked against undefined, not truthiness: setting the variable to an empty
    // string must mean "send nowhere". Without that there is no way to override a
    // configured endpoint back off, and tests would silently post to production.
    const override = process.env.RAFTKIT_TELEMETRY_ENDPOINT;
    if (override !== undefined) {
      // The empty string never contacts any host, so it is exempt from the
      // loopback check below on its own merits — there is nothing for it to
      // redirect to. Anything else must resolve to loopback (127.0.0.1, ::1,
      // localhost) or it is refused — see below for what "refused" sends to.
      // This is what stops a repo-controlled env block that sets
      // RAFTKIT_DEV=1 itself from redirecting captured prompts to an
      // attacker-controlled host.
      let loopbackOrEmpty = override === "";
      if (!loopbackOrEmpty) {
        try {
          loopbackOrEmpty = isLoopbackHost(new URL(override).hostname);
        } catch {
          loopbackOrEmpty = false;
        }
      }
      // A refused override must not silently fall back to whatever
      // telemetry.config.json shipped — that would defeat the override
      // entirely: a caller that deliberately set RAFTKIT_DEV=1 to redirect
      // (or silence) telemetry would instead have real events sent to
      // production the moment its override fails the loopback check. Refuse
      // outright: send nowhere, exactly as an explicit empty override would.
      cachedConfig.endpoint = loopbackOrEmpty ? override : "";
    }
  }

  return cachedConfig;
}

// Never leaves the machine — the one host class exempt from restrictions
// elsewhere in this file (cleartext below, the RAFTKIT_DEV override in config()).
const LOOPBACK_HOSTS = ["127.0.0.1", "::1", "localhost", "[::1]"];
function isLoopbackHost(hostname) {
  return LOOPBACK_HOSTS.includes(hostname);
}

/**
 * Refuse to post captured prompts over cleartext.
 *
 * Loopback is exempt: it never leaves the machine, and it is where the test
 * suite's stub server runs. Note this is broader than the RAFTKIT_DEV override
 * check in config(): here an https: host is usable regardless of hostname —
 * that check additionally requires loopback even for https, since it is
 * deciding whether to honour an override at all, not just whether transport is
 * encrypted.
 */
export function endpointUsable(endpoint) {
  try {
    const url = new URL(endpoint);
    if (url.protocol === "https:") return true;
    return url.protocol === "http:" && isLoopbackHost(url.hostname);
  } catch {
    return false;
  }
}

/**
 * Take an exclusive on-disk lock, or return null if someone else holds it.
 *
 * O_EXCL create is the atomic primitive; the returned function releases. Hooks
 * run as detached, concurrent processes across sessions, so any read-modify-write
 * on shared state needs this — otherwise two sessions interleave and one clobbers
 * the other's update (a spool claim deleted mid-send, the notice-shown marker
 * written twice at once).
 *
 * A lock left behind by a killed process is broken once it is older than
 * staleMs, so a crash can never wedge the feature permanently.
 */
export function acquireLock(path, { staleMs = 60000 } = {}) {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const fd = openSync(path, "wx");
      try {
        writeFileSync(fd, String(process.pid));
      } finally {
        closeSync(fd);
      }
      return () => {
        try {
          unlinkSync(path);
        } catch {
          /* already gone — nothing to release */
        }
      };
    } catch {
      try {
        if (Date.now() - statSync(path).mtimeMs > staleMs) unlinkSync(path);
        else return null;
      } catch {
        return null;
      }
    }
  }
  return null;
}

/** Run a command, returning trimmed stdout or "" — never throws, never inherits stdio. */
export function safeExec(cmd, args, opts = {}) {
  try {
    return execFileSync(cmd, args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: opts.timeout ?? 3000,
      cwd: opts.cwd,
      maxBuffer: 1024 * 1024,
    }).trim();
  } catch {
    return "";
  }
}

/**
 * Run a command and return BOTH its success and its output.
 *
 * Needed wherever a retry decision depends on whether the command worked: a
 * command can succeed and print nothing, so testing the string for emptiness
 * silently turns success into a retry (and a duplicate side effect).
 */
export function safeExecResult(cmd, args, opts = {}) {
  try {
    const stdout = execFileSync(cmd, args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: opts.timeout ?? 3000,
      cwd: opts.cwd,
      maxBuffer: 1024 * 1024,
    });
    return { ok: true, stdout: stdout.trim() };
  } catch {
    return { ok: false, stdout: "" };
  }
}

/**
 * Run a command and report whether it SUCCEEDED, ignoring its output.
 * Needed because plenty of useful commands (`gh auth status`) write to stderr
 * and leave stdout empty — testing safeExec's return value for emptiness would
 * wrongly conclude the command failed.
 */
export function safeExecOk(cmd, args, opts = {}) {
  try {
    execFileSync(cmd, args, {
      stdio: ["ignore", "ignore", "ignore"],
      timeout: opts.timeout ?? 3000,
      cwd: opts.cwd,
    });
    return true;
  } catch {
    return false;
  }
}

export function sha(value, len = 12) {
  return createHash("sha256").update(String(value)).digest("hex").slice(0, len);
}

/** Read all of stdin as text. Resolves "" on any error or when nothing is piped. */
export function readStdin() {
  return new Promise((resolve) => {
    let data = "";
    let settled = false;
    const done = () => {
      if (!settled) {
        settled = true;
        resolve(data);
      }
    };
    try {
      if (process.stdin.isTTY) return done();
      process.stdin.setEncoding("utf8");
      process.stdin.on("data", (c) => (data += c));
      process.stdin.on("end", done);
      process.stdin.on("error", done);
      setTimeout(done, 2000).unref?.();
    } catch {
      done();
    }
  });
}

export function parseJson(text, fallback = {}) {
  try {
    const v = JSON.parse(text);
    return v && typeof v === "object" ? v : fallback;
  } catch {
    return fallback;
  }
}

/**
 * Reduce a git remote to `owner/repo`.
 *
 * Normalizing rather than sending the raw URL is a safety measure, not tidiness:
 * an HTTPS remote can embed credentials (https://user:ghp_xxx@github.com/o/r),
 * and `git remote get-url` returns them verbatim. Rebuilding the value from just
 * the last two path segments drops any credential by construction rather than
 * relying on a scrub pattern to catch it.
 */
export function repoSlug(remote) {
  if (!remote) return "";
  const stripped = String(remote)
    .trim()
    .replace(/\.git$/, "")
    .replace(/^[a-z0-9+.-]+:\/\/[^/]*@?/i, "") // scheme + any user:pass@host
    .replace(/^[^@]+@[^:]+:/, "");             // scp-style git@host:
  const parts = stripped.split("/").filter(Boolean);
  if (parts.length < 2) return "";
  const slug = parts.slice(-2).join("/");
  // Bound it and keep it to characters a repo path can actually contain.
  return /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/.test(slug) ? slug.slice(0, 140) : "";
}

/**
 * Which project an event came from.
 *
 * `repo` stays a hash so events recorded before the name was collected still
 * group; `repo_name` and `branch` carry the readable detail the dashboard needs
 * to tell one project's blockers from another's. Sending the name is a
 * deliberate reversal of the original design — see the Telemetry section of
 * house-rules for what that means and how to opt out.
 */
export function repoContext(cwd) {
  const remote = safeExec("git", ["remote", "get-url", "origin"], { cwd, timeout: LOCAL_EXEC_TIMEOUT });
  const branch = safeExec("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd, timeout: LOCAL_EXEC_TIMEOUT });
  const kind = branch.includes("/") ? branch.split("/")[0] : branch === "" ? "" : "other";
  return {
    repo: remote ? `sha256:${sha(remote)}` : "",
    repo_name: repoSlug(remote),
    branch,
    branch_kind: kind,
  };
}

/** Versions of the installed raftkit plugins, read from their manifests. */
export function pluginVersions() {
  const out = {};
  try {
    // HOOKS_ROOT is <plugin>/hooks; the marketplace layout puts sibling plugins
    // one level up from the plugin dir when running from a checkout.
    const pluginDir = dirname(HOOKS_ROOT);
    const manifest = join(pluginDir, ".claude-plugin", "plugin.json");
    if (existsSync(manifest)) {
      const m = parseJson(readFileSync(manifest, "utf8"));
      if (m.name && m.version) out[m.name] = m.version;
    }
  } catch {
    /* versions are nice-to-have, never load-bearing */
  }
  return out;
}
