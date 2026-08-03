#!/usr/bin/env node
// Fail-closed renderer for pr-auto-review's workflow asset. Sibling to
// setup-project's render-assets.mjs — same validation discipline, kept
// separate so this component's rendering never destabilizes that script's
// existing guarantees for its own two components.
//
// Usage: node render-pr-auto-review.mjs --templates <dir> --out-dir <dir>
//   --bot-name <name> --bot-email <email>
//   --timeout-minutes <int> --max-turns <int>
//   --plugin-ref <name@marketplace>
// Exit codes: 0 rendered · 2 bad invocation · 3 validation failed, nothing written.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const flag = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const die = (code, msg) => { console.error(msg); process.exit(code); };

const templates = flag("--templates"), outDir = flag("--out-dir");
const botName = flag("--bot-name"), botEmail = flag("--bot-email");
const timeoutMinutes = flag("--timeout-minutes"), maxTurns = flag("--max-turns");
const pluginRef = flag("--plugin-ref");

if (!templates || !outDir || !botName || !botEmail || !timeoutMinutes || !maxTurns || !pluginRef) {
  die(2, "usage: --templates <dir> --out-dir <dir> --bot-name <name> --bot-email <email> --timeout-minutes <int> --max-turns <int> --plugin-ref <name@marketplace>");
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
// block-scalar content line — gets the full multi-line prompt.
//
// On that content line, the indentation is template text BEFORE the token
// (not part of the token itself). Plain line replacement keeps that
// existing indentation on the prompt's first line for free — we must NOT
// re-add it there, only on every SUBSEQUENT line of the multi-line prompt,
// or the first line ends up double-indented while the rest render as
// garbage top-level YAML. The template already supplies the "prompt: |"
// marker, so the substitution value must never prepend its own "|\n" —
// that would nest a literal "|" as the first content line, breaking YAML.
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

mkdirSync(outDir, { recursive: true });
writeFileSync(path.join(outDir, "pr-auto-review.yml"), workflow);
console.log(`rendered: pr-auto-review.yml (bot=${botName} <${botEmail}>, timeout=${timeoutMinutes}m, max-turns=${maxTurns}, plugin=${pluginRef})`);
