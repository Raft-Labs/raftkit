// The decision half of the bulk-read shunt, kept apart from the hook entry
// point so it can be exercised directly by the test suite without a subprocess
// and without stdin. Pure: it reads no files, touches no env, and returns a
// verdict object. shunt.mjs supplies the facts (line count, resolved path) and
// owns every side effect.
//
// The rule it encodes: a read large enough to be bulk data is answered by a
// cheap subagent instead of being paged into the session. A read that is
// instruction, or that is already narrowed to a range, is never touched.

import { basename, sep } from "node:path";

export const DEFAULT_MIN_LINES = 500;

/**
 * Resolve the line threshold, in order: explicit env override, then default.
 *
 * A non-numeric or non-positive override is ignored rather than honoured as
 * zero, which would shunt every read in the repo — a misconfigured value must
 * degrade to the default, never to the most aggressive possible setting.
 */
export function threshold(env = process.env) {
  const raw = Number.parseInt(env.RAFTKIT_SHUNT_MIN_LINES ?? "", 10);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_MIN_LINES;
}

/** The shunt is on by default and off when the developer says so. */
export function shuntDisabled(env = process.env) {
  return /^(off|0|false|no)$/i.test((env.RAFTKIT_SHUNT || "").trim());
}

// Paths whose contents are instructions to act on, not data to summarise.
// A Haiku paraphrase of a scope contract is precisely the failure the
// never-invent rule exists to prevent, so these are read verbatim at any size.
const CONTRACT_BASENAMES = new Set(["CLAUDE.md", "AGENTS.md", "SKILL.md", "budgets.json", "working-agreement.md"]);
const CONTRACT_DIRS = ["skills", "docs/specs", ".claude"];

/**
 * True when the path carries instructions rather than bulk content.
 *
 * Directory membership is matched on path segments, never on a substring: a
 * file called `my-skills-notes.md` is not inside `skills/`, and matching it as
 * though it were would silently exempt arbitrary files from the shunt.
 */
export function isContractPath(relPath) {
  if (typeof relPath !== "string" || relPath === "") return false;
  if (CONTRACT_BASENAMES.has(basename(relPath))) return true;
  const segments = relPath.split(sep).filter(Boolean);
  return CONTRACT_DIRS.some((dir) => {
    const want = dir.split("/");
    return segments.some((_, i) => want.every((w, j) => segments[i + j] === w));
  });
}

// The hook runs inside a subagent's tool calls as well as the main thread, so
// the bulk-reader would be denied the very file it exists to read.
//
// Two defences, because only one of them is guaranteed. This is the soft one:
// the payload field naming the calling agent is checked across every spelling
// Claude Code might use, and a hit bypasses the shunt outright. If none is
// present the read simply falls through to the hard defence — the agent pages
// with offset/limit, which is exempt by construction. Nothing here depends on
// a field being there; it only takes advantage of one when it is.
const AGENT_FIELDS = ["agent_type", "subagent_type", "agent_name", "agentType", "agent_id"];
export const EXEMPT_AGENTS = new Set(["bulk-reader"]);

/** True when this tool call comes from an agent the shunt must not police. */
export function isExemptAgent(hook) {
  if (!hook || typeof hook !== "object") return false;
  return AGENT_FIELDS.some((f) => EXEMPT_AGENTS.has(String(hook[f] ?? "").trim()));
}

// Read shapes that pull a whole file into the session. Deliberately narrow:
// anything with a redirect, a command substitution, a chained command or more
// than one path is left alone, because a wrong guess here blocks real work.
const BULK_BASH = [
  /^cat\s+(?<path>[^\s|<>;&]+)\s*(\|.*)?$/,
  /^head\s+-n\s*(?<n>\d+)\s+(?<path>[^\s|<>;&]+)\s*(\|.*)?$/,
  /^tail\s+-n\s*(?<n>\d+)\s+(?<path>[^\s|<>;&]+)\s*(\|.*)?$/,
  /^sed\s+-n\s+'?1,(?<n>\d+)p'?\s+(?<path>[^\s|<>;&]+)\s*(\|.*)?$/,
];

/**
 * Extract the single file a bash command would page into context, or "".
 *
 * Returns "" for anything it does not recognise with certainty. The count-
 * bearing forms (head/tail/sed) only qualify above the threshold: `head -n 20`
 * is already the narrowed read the shunt is trying to encourage.
 */
export function bulkBashTarget(command, minLines) {
  if (typeof command !== "string") return "";
  const cmd = command.trim();
  if (cmd.includes("$(") || cmd.includes("`") || /[;&]|\|\|/.test(cmd)) return "";
  for (const re of BULK_BASH) {
    const m = re.exec(cmd);
    if (!m) continue;
    const n = m.groups.n === undefined ? Infinity : Number.parseInt(m.groups.n, 10);
    if (n < minLines) return "";
    return m.groups.path.replace(/^['"]|['"]$/g, "");
  }
  return "";
}

/**
 * The deny text Claude receives in place of the file.
 *
 * It is the whole instruction: unlike Portal's bash wrappers, the alternative
 * here is a single Agent call, so there is nothing a companion skill would add
 * that this message does not already carry.
 */
export function denyReason(relPath, lines, minLines) {
  return [
    `${relPath} is ${lines.toLocaleString("en-US")} lines — over the ${minLines}-line shunt threshold.`,
    "Dispatch the bulk-reader subagent with your question instead of reading it here:",
    `  Agent(subagent_type: "bulk-reader", prompt: "<your question>\\nFiles: ${relPath}")`,
    "It runs on Haiku and returns cited bullets. To edit, Read with offset/limit on the range it cites.",
    "Already inside a subagent, or need the text yourself? Read with offset and limit —",
    "a narrowed read is never shunted, so page it (offset 1 limit 1500, then on).",
    "Bypass for this session: RAFTKIT_SHUNT=off",
  ].join("\n");
}
