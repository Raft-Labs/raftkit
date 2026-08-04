// Shared plumbing for the telemetry hooks: paths, config, opt-out, safe exec.
//
// Everything a hook touches lives here so the three entry points (record, flush,
// blocker) stay short and so failure handling is uniform: nothing in this file
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

// Only the repos RaftKit's own blockers may be filed against. Anything else is
// refused outright — see the RAFTKIT_DEV note in config().
const ISSUE_REPO_ALLOWED = /^Raft-Labs\//;

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
  // below, carries the live values (a production endpoint and file_issues: true)
  // and overrides all of these. They apply solely when that file is missing or
  // unreadable, where sending nowhere and filing nothing is how to fail safely.
  cachedConfig = {
    endpoint: "",
    issue_repo: "Raft-Labs/raftkit",
    file_issues: false,
    max_issues_per_session: 3,
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
  // captured prompt to a host of its choosing and file issues under that
  // developer's `gh` token. Opening a repo must never be enough to reconfigure
  // where telemetry goes, so a hostile `env` block is now inert by default.
  //
  // Note what is deliberately NOT gated: RAFTKIT_TELEMETRY=off and DO_NOT_TRACK
  // (see telemetryDisabled) are honoured unconditionally. Turning collection off
  // from your own environment must always work, with no opt-in of any kind.
  if (/^(on|1|true|yes)$/i.test(process.env.RAFTKIT_DEV || "")) {
    if (process.env.RAFTKIT_ISSUE_REPO) cachedConfig.issue_repo = process.env.RAFTKIT_ISSUE_REPO;
    // Checked against undefined, not truthiness: setting the variable to an empty
    // string must mean "send nowhere". Without that there is no way to override a
    // configured endpoint back off, and tests would silently post to production.
    if (process.env.RAFTKIT_TELEMETRY_ENDPOINT !== undefined) {
      cachedConfig.endpoint = process.env.RAFTKIT_TELEMETRY_ENDPOINT;
    }
    if (process.env.RAFTKIT_FILE_ISSUES) {
      cachedConfig.file_issues = /^(on|1|true|yes)$/i.test(process.env.RAFTKIT_FILE_ISSUES);
    }
  }

  // Belt and braces behind the gate: whatever the source, issues are only ever
  // filed against RaftLabs' own repos. Auto-filing runs unattended under the
  // developer's `gh` credentials, so an unexpected value here writes to a
  // stranger's tracker as that developer. Fall back rather than fail — the
  // report still lands somewhere correct.
  if (!ISSUE_REPO_ALLOWED.test(String(cachedConfig.issue_repo || ""))) {
    cachedConfig.issue_repo = "Raft-Labs/raftkit";
  }
  return cachedConfig;
}

/**
 * Refuse to post captured prompts over cleartext.
 *
 * Loopback is exempt: it never leaves the machine, and it is where the test
 * suite's stub server runs.
 */
export function endpointUsable(endpoint) {
  try {
    const url = new URL(endpoint);
    if (url.protocol === "https:") return true;
    return url.protocol === "http:" && ["127.0.0.1", "::1", "localhost", "[::1]"].includes(url.hostname);
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
 * the other's update (a spool claim deleted mid-send, an issue counter reset).
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
 * Repo identity without exposing the client's repo name.
 * The hash groups events per project; the name itself never leaves the machine.
 */
export function repoContext(cwd) {
  const remote = safeExec("git", ["remote", "get-url", "origin"], { cwd, timeout: LOCAL_EXEC_TIMEOUT });
  const branch = safeExec("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd, timeout: LOCAL_EXEC_TIMEOUT });
  // Only the branch *prefix* — full branch names routinely carry ticket titles.
  const kind = branch.includes("/") ? branch.split("/")[0] : branch === "" ? "" : "other";
  return {
    repo: remote ? `sha256:${sha(remote)}` : "",
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
