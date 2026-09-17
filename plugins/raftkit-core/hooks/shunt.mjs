#!/usr/bin/env node
// Hook entry point: keeps bulk file content out of the session by answering an
// oversized read with an instruction to dispatch the bulk-reader subagent.
//
// Usage: shunt.mjs          (PreToolUse, matchers Read and Bash)
//
// Contract, in priority order:
//   1. NEVER break the developer's session. Every path exits 0, including the
//      deny: a PreToolUse veto is structured JSON on stdout, never a non-zero
//      status, so this hook keeps the same promise every other RaftKit hook
//      makes. No throw escapes.
//   2. Fail OPEN. Every uncertainty — unreadable payload, missing file, binary
//      content, a path outside the repo, a bash line this cannot parse with
//      certainty — allows the read. The one deny is the one confirmed case.
//   3. Be fast on the allow path. It runs before every Read in the session, so
//      it does no git, no identity resolution and no telemetry unless it denies.

import { appendFileSync, readFileSync, realpathSync, statSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { isAbsolute, relative, resolve, sep } from "node:path";
import { ensureDir, parseJson, readStdin, repoContext, spoolDir, spoolFile, telemetryDisabled } from "./lib/common.mjs";
import { identity } from "./lib/identity.mjs";
import {
  bulkBashTarget,
  denyReason,
  isContractPath,
  isExemptAgent,
  shuntDisabled,
  threshold,
} from "./lib/shunt-rules.mjs";

// Above this a file is bulk by size alone and is never read into memory to be
// counted. Counting it would be the very cost the hook exists to avoid.
const HUGE_BYTES = 4 * 1024 * 1024;

// A NUL in the leading bytes means binary — an image, a PDF, a compiled asset.
// Claude Code renders those specially and a line count of one is meaningless,
// so they are never shunted.
const SNIFF_BYTES = 8192;

/**
 * Count lines, or return -1 for "do not shunt this".
 *
 * -1 rather than 0 because 0 is a real answer (an empty file) and must not be
 * confused with "could not tell" — conflating them is how a fail-open becomes
 * a fail-closed the first time a stat goes wrong.
 */
function countLines(path) {
  try {
    const size = statSync(path).size;
    if (size > HUGE_BYTES) return Infinity;
    const buf = readFileSync(path);
    if (buf.subarray(0, SNIFF_BYTES).includes(0)) return -1;
    let lines = 0;
    for (let i = 0; i < buf.length; i++) if (buf[i] === 0x0a) lines++;
    // A trailing byte with no newline after it is still a line.
    return buf.length > 0 && buf[buf.length - 1] !== 0x0a ? lines + 1 : lines;
  } catch {
    return -1;
  }
}

/**
 * Resolve a tool's path argument to a repo-relative path, or "" to allow.
 *
 * realpath is what makes the containment check mean anything: without it a
 * symlink inside the repo pointing at /etc passes a prefix test on its own
 * name. Anything outside the repo root is somebody else's file and is left
 * alone — this hook governs how the session reads the project, nothing wider.
 */
function repoRelative(rawPath, root) {
  if (typeof rawPath !== "string" || rawPath.trim() === "") return "";
  try {
    const abs = realpathSync(isAbsolute(rawPath) ? rawPath : resolve(root, rawPath));
    const rootReal = realpathSync(root);
    const rel = relative(rootReal, abs);
    if (rel === "" || rel.startsWith("..") || isAbsolute(rel)) return "";
    if (!statSync(abs).isFile()) return "";
    return rel;
  } catch {
    return "";
  }
}

/**
 * The file this tool call would page into the session, or "" for none.
 *
 * A Read already narrowed by offset or limit is exempt by design: it is the
 * targeted read that follows a summary, and it is how the developer edits.
 * Portal excludes editing from its shunt for the same reason.
 */
function targetPath(hook, minLines) {
  const input = hook.tool_input || {};
  if (hook.tool_name === "Read") {
    if (input.offset !== undefined || input.limit !== undefined) return "";
    return typeof input.file_path === "string" ? input.file_path : "";
  }
  if (hook.tool_name === "Bash") return bulkBashTarget(input.command, minLines);
  return "";
}

/** Record a deny so the saving is a number in the dashboard, not a claim. */
function recordDeny(hook, root, props) {
  if (telemetryDisabled()) return;
  try {
    if (!ensureDir(spoolDir())) return;
    const event = {
      event_id: randomUUID(),
      ts: new Date().toISOString(),
      distinct_id: identity().distinct_id,
      event: "raftkit_shunt",
      props: {
        mode: "shunt",
        session_id: hook.session_id || "",
        hook_event: hook.hook_event_name || "",
        os: process.platform,
        node: process.version,
        ...repoContext(root),
        ...props,
      },
    };
    appendFileSync(spoolFile(), JSON.stringify(event) + "\n");
  } catch {
    /* an unrecorded shunt is still a correct shunt */
  }
}

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    }),
  );
}

async function main() {
  if (shuntDisabled()) return;

  const hook = parseJson(await readStdin());
  // The bulk-reader reads what the shunt declined. Policing it would deny the
  // one agent whose entire job is the oversized read.
  if (isExemptAgent(hook)) return;
  const root = hook.cwd || process.cwd();
  const minLines = threshold();

  const rel = repoRelative(targetPath(hook, minLines), root);
  if (rel === "" || isContractPath(rel)) return;

  const lines = countLines(resolve(root, rel));
  if (lines < minLines) return;

  // Separators in the path would let a crafted filename forge extra lines in
  // the reason text the model reads back as instruction.
  if (rel.includes("\n") || rel.includes("\r")) return;

  const shown = Number.isFinite(lines) ? lines : minLines;
  deny(denyReason(rel.split(sep).join("/"), shown, minLines));
  recordDeny(hook, root, {
    tool: hook.tool_name || "",
    path_ext: rel.includes(".") ? rel.slice(rel.lastIndexOf(".")) : "",
    lines: Number.isFinite(lines) ? lines : -1,
    threshold: minLines,
    lines_avoided: Number.isFinite(lines) ? lines : 0,
  });
}

// One catch for the whole hook. Rule 1 says no throw escapes and rule 2 says
// every uncertainty allows, and an empty stdout is exactly "allow".
try {
  await main();
} catch {
  /* fail open */
}
process.exit(0);
