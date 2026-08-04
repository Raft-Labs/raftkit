#!/usr/bin/env node
// Fail-closed renderer for pr-auto-review's workflow asset. Sibling to
// setup-project's render-assets.mjs — same validation discipline, kept
// separate so this component's rendering never destabilizes that script's
// existing guarantees for its own two components.
//
// Usage: node render-pr-auto-review.mjs --templates <dir> --out-dir <dir>
//   [--bot-name <name>] [--bot-email <email>]
//   [--timeout-minutes <int>] [--max-turns <int>]
//   [--plugin-ref <name@marketplace>]
//
// Only --templates and --out-dir are required. Every other flag DEFAULTS to
// the canonical value below, because an installer that has to invent a bot
// identity will invent a different one on the next run and silently break the
// loop guard against commits the previous install created. Override a default
// only with a deliberate, documented reason (see references/install.md).
// Exit codes: 0 rendered · 2 bad invocation · 3 validation failed, nothing written.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";

// Canonical defaults — the single source of these values for every install.
// references/install.md documents them; keep the two in step.
const DEFAULTS = {
  botName: "RaftKit PR Auto-Review",
  botEmail: "pr-auto-review@raftlabs.com",
  timeoutMinutes: "30",
  maxTurns: "60",
  pluginRef: "pr-review-toolkit@claude-plugins-official",
};
// GitHub cancels any job exceeding 360 minutes, so a larger timeout-minutes is
// a value the runner will never honour — accepting it would be exactly the
// silent, non-fail-closed behaviour the rest of this script exists to prevent.
const MAX_TIMEOUT_MINUTES = 360;

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const die = (code, msg) => { console.error(msg); process.exit(code); };

const templates = flag("--templates"), outDir = flag("--out-dir");
const botName = flag("--bot-name") ?? DEFAULTS.botName;
const botEmail = flag("--bot-email") ?? DEFAULTS.botEmail;
const timeoutMinutes = flag("--timeout-minutes") ?? DEFAULTS.timeoutMinutes;
const maxTurns = flag("--max-turns") ?? DEFAULTS.maxTurns;
const pluginRef = flag("--plugin-ref") ?? DEFAULTS.pluginRef;

if (!templates || !outDir) {
  die(2, "usage: --templates <dir> --out-dir <dir> [--bot-name <name>] [--bot-email <email>] [--timeout-minutes <int>] [--max-turns <int>] [--plugin-ref <name@marketplace>]");
}

// --- validation (reject; never sanitize-and-continue) -----------------------
const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9:_.@\- ]*$/;
const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const INT_RE = /^[1-9][0-9]*$/;
const PLUGIN_REF_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*@[A-Za-z0-9][A-Za-z0-9._-]*$/;
const fail = (msg) => die(3, `validation failed — rendering nothing: ${msg}`);

for (const [label, value, re] of [
  ["bot-name", botName, NAME_RE],
  ["plugin-ref", pluginRef, PLUGIN_REF_RE],
]) {
  if (/[\n\r]|[$`]/.test(value) || !re.test(value)) fail(`${label} '${value}' contains injection-shaped or unsupported characters`);
}
if (/[\n\r]|[$`]/.test(botEmail) || !EMAIL_RE.test(botEmail)) fail(`bot-email '${botEmail}' is not a valid, safe email address`);
if (!INT_RE.test(timeoutMinutes)) fail(`timeout-minutes '${timeoutMinutes}' is not a positive integer`);
if (Number(timeoutMinutes) > MAX_TIMEOUT_MINUTES) fail(`timeout-minutes '${timeoutMinutes}' exceeds GitHub's ${MAX_TIMEOUT_MINUTES}-minute job cap — the runner would cancel the job regardless`);
if (!INT_RE.test(maxTurns)) fail(`max-turns '${maxTurns}' is not a positive integer`);

// --- substitution over the shipped templates --------------------------------
const subs = {
  __BOT_COMMIT_NAME__: botName,
  __BOT_COMMIT_EMAIL__: botEmail,
  __TIMEOUT_MINUTES__: timeoutMinutes,
  __MAX_TURNS__: maxTurns,
  __PR_REVIEW_TOOLKIT_PLUGIN_REF__: pluginRef,
};

// The template's `prompt:` key is ALREADY a YAML block scalar:
//   prompt: |
//     __FIX_LOOP_PROMPT__
// __FIX_LOOP_PROMPT__ also appears a second time, a few lines above, inside
// a `#`-prefixed comment explaining this substitution in prose. A blanket
// split/join of the whole file (fine for every other token, which appear
// exactly once) would corrupt THAT comment line into unescaped multi-line
// text with no `#` prefix on its continuation lines, breaking the YAML
// mapping — so this token is substituted line-by-line instead of via the
// generic per-token loop below: the comment line gets a short literal
// label (still documentation, never a leftover placeholder), and the
// line that is EXACTLY the token (plus leading indentation) — the real
// block-scalar content line — is REPLACED WHOLESALE by the multi-line
// prompt.
//
// Because that whole template line (its indentation included) is discarded,
// the indentation is not inherited for free: it is captured first as
// `tokenIndent`, then re-applied to EVERY line of the prompt, the first line
// included. Do not "fix" this into skipping the first line — that would
// dedent the prompt's opening line out of the block scalar. The template
// already supplies the "prompt: |" marker, so the substitution value must
// never prepend its own "|\n" — that would nest a literal "|" as the first
// content line, breaking YAML.
const readRequired = (file) => {
  try { return readFileSync(path.join(templates, file), "utf8"); }
  catch { return fail(`required template file missing: ${file}`); }
};

const templateText = readRequired("pr-auto-review.yml");
const templateLines = templateText.split("\n");
const tokenLineIndex = templateLines.findIndex((l) => /^\s*__FIX_LOOP_PROMPT__\s*$/.test(l));
if (tokenLineIndex === -1) fail("no standalone __FIX_LOOP_PROMPT__ block-scalar line found in pr-auto-review.yml");
const tokenIndent = templateLines[tokenLineIndex].match(/^(\s*)/)[1];

const promptRaw = readRequired("fix-loop-prompt.md");
// Strip a single trailing newline so we don't emit one extra blank
// indented line at the end of the block scalar.
const promptLines = promptRaw.replace(/\n$/, "").split("\n");
// A YAML literal block scalar takes its indentation from its FIRST non-empty
// content line. If the prompt's own first line were indented, every following
// line would sit at a shallower indent, silently ending the block scalar and
// re-parsing the rest of the prompt as workflow keys. Fail closed rather than
// emit that.
const firstContentLine = promptLines.find((line) => line.trim().length > 0);
if (firstContentLine === undefined) fail("fix-loop-prompt.md is empty — nothing to embed as the prompt");
if (/^\s/.test(firstContentLine)) fail(`fix-loop-prompt.md's first non-empty line is indented ('${firstContentLine.slice(0, 40)}…') — it sets the block scalar's indentation and would swallow every following line`);
// The final unresolved-placeholder scan below only covers templateLines,
// not this substituted content — a stray __TOKEN__-shaped string inside
// the prompt file itself would otherwise ship silently. Check it here,
// independently, before it's folded into the render.
const strayToken = promptLines.find((line) => /__[A-Z_]+__/.test(line));
if (strayToken) fail(`fix-loop-prompt.md contains placeholder-shaped text: ${strayToken.trim()}`);
const promptIndented = promptLines
  .map((line) => (line.length ? `${tokenIndent}${line}` : ""))
  .join("\n");

const FIX_LOOP_PROMPT_LABEL = "fix-loop-prompt.md";
const renderedLines = templateLines.map((line, i) => {
  if (i === tokenLineIndex) return promptIndented;
  let out = line.split("__FIX_LOOP_PROMPT__").join(FIX_LOOP_PROMPT_LABEL);
  for (const [token, value] of Object.entries(subs)) out = out.split(token).join(value);
  return out;
});
const workflow = renderedLines.join("\n");

const unresolvedLine = renderedLines.find((line, i) => i !== tokenLineIndex && /__[A-Z_]+__/.test(line));
if (unresolvedLine) fail(`unresolved placeholder in pr-auto-review.yml: ${unresolvedLine.trim()}`);

// --- post-render structural check on the emitted block scalar ---------------
// Nothing here parses YAML: node ships no YAML parser and this repo adds no
// npm dependency for one. So instead of a parse-and-compare, assert the one
// structural property a YAML literal block scalar must hold for the prompt to
// survive — every content line indented at least as deep as the block's own
// indentation — and prove the prompt round-trips by stripping that
// indentation back off and comparing to the source, byte for byte. A block
// scalar that satisfies both cannot have leaked prompt text into the workflow
// mapping, which is the corruption this guards against.
// Every entry of renderedLines except the substituted one is a single line
// (values are charset-validated to carry no newline), so the prompt block
// begins at exactly tokenLineIndex in the emitted file.
const emittedLines = workflow.split("\n");
const blockLines = emittedLines.slice(tokenLineIndex, tokenLineIndex + promptLines.length);
if (blockLines.length !== promptLines.length) fail("rendered block scalar is shorter than the prompt it should contain");
const roundTripped = blockLines.map((line) => {
  if (line.length === 0) return "";
  if (!line.startsWith(tokenIndent)) fail(`rendered block scalar line is under-indented and would terminate the block early: '${line.slice(0, 40)}…'`);
  return line.slice(tokenIndent.length);
});
if (roundTripped.join("\n") !== promptLines.join("\n")) fail("rendered block scalar does not round-trip back to fix-loop-prompt.md");
// The block must END where the prompt ends: the next line has to sit at
// shallower indentation (or the file has to end), or the block's extent is
// ambiguous and following workflow keys would be swallowed into the prompt.
const afterBlock = emittedLines[tokenLineIndex + promptLines.length];
if (afterBlock !== undefined && afterBlock.trim().length > 0 && afterBlock.startsWith(tokenIndent)) {
  fail(`the line after the prompt block scalar is still block-indented, so the block's extent is ambiguous: '${afterBlock.slice(0, 40)}…'`);
}

mkdirSync(outDir, { recursive: true });
writeFileSync(path.join(outDir, "pr-auto-review.yml"), workflow);
console.log(`rendered: pr-auto-review.yml (bot=${botName} <${botEmail}>, timeout=${timeoutMinutes}m, max-turns=${maxTurns}, plugin=${pluginRef})`);
