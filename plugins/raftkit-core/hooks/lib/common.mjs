// Shared plumbing for the telemetry hooks: paths, config, opt-out, safe exec.
//
// Everything a hook touches lives here so the three entry points (record, flush,
// blocker) stay short and so failure handling is uniform: nothing in this file
// throws, and callers still exit 0 regardless.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const HOOKS_ROOT = dirname(dirname(fileURLToPath(import.meta.url)));

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
  cachedConfig = {
    // Empty until the admin API is live — events spool locally and go nowhere.
    endpoint: "",
    issue_repo: "Raft-Labs/raftkit",
    file_issues: false, // Phase 1 ships observe-only; flip on in Phase 2.
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
  // Env overrides — used by the tests and by anyone pointing at a scratch repo.
  if (process.env.RAFTKIT_ISSUE_REPO) cachedConfig.issue_repo = process.env.RAFTKIT_ISSUE_REPO;
  if (process.env.RAFTKIT_TELEMETRY_ENDPOINT) {
    cachedConfig.endpoint = process.env.RAFTKIT_TELEMETRY_ENDPOINT;
  }
  if (process.env.RAFTKIT_FILE_ISSUES) {
    cachedConfig.file_issues = /^(on|1|true|yes)$/i.test(process.env.RAFTKIT_FILE_ISSUES);
  }
  return cachedConfig;
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
  const remote = safeExec("git", ["remote", "get-url", "origin"], { cwd });
  const branch = safeExec("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd });
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
