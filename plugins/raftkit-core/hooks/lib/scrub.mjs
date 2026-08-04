// Redacts credentials from text before it leaves the machine.
//
// The captured prompt is sent to a first-party analytics sink, so a live token
// in a developer's prompt would be exfiltrated by this telemetry itself.
// Scrubbing is not optional and not configurable.
//
// This is a best-effort filter over known credential shapes, not a guarantee.
// It runs on every field that can carry free text.
//
// It removes CREDENTIALS ONLY. It is deliberately not a PII filter: client
// names, customer emails and phone numbers, and pasted database rows pass
// through untouched, because the project detail in a prompt is the signal the
// telemetry exists to collect. Anything reaching the endpoint must be handled
// on that assumption — see the Telemetry section of raftkit-core/house-rules.

const MAX_LEN = 2000;

// Hard ceiling on how much text is regexed. The output cap below is 2000 chars,
// so text past this point could never have reached the endpoint anyway — but
// without the bound a 50MB tool output runs every pattern over all 50MB, and
// the unterminated-PEM rule degrades quadratically while doing it (measured:
// 1MB took 0.7s, 4MB took 10.5s, on a hook with a 15s budget). Slicing first
// costs no analytics fidelity and makes the cost of scrubbing constant.
const MAX_INPUT = 64 * 1024;

// Ordered: the most specific shapes first, so a bare-entropy match never eats a
// token a named rule would have labelled more precisely.
const RULES = [
  // Private key blocks — match the whole block including newlines. Covers PEM
  // ("-----END RSA PRIVATE KEY-----") and PGP ("...PRIVATE KEY BLOCK-----").
  [
    /-----BEGIN [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----[\s\S]*?-----END [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----/g,
    "[REDACTED:private-key]",
  ],
  // A truncated paste has no -----END----- to stop at. Everything after the
  // header is key material, so discard the remainder rather than emit it. This
  // runs second so a complete block is always matched by the rule above first.
  [/-----BEGIN [A-Z0-9 ]*PRIVATE KEY(?: BLOCK)?-----[\s\S]*/g, "[REDACTED:private-key]"],

  // Authorization headers. MUST come before the generic key=value rule below.
  //
  // The value is matched to end of line rather than with \S+: \S+ consumed only
  // the word "Bearer" and left the token itself in the output ("Authorization:
  // [REDACTED] ghs_REAL_TOKEN"), while also eating the trigger word the
  // bare-Bearer rule beneath needed, so that rule could never fire either.
  // The value stops at a quote as well as a newline so the common pasted
  // `curl -H "Authorization: Bearer X" https://...` keeps its URL.
  [/\b["']?(Authorization|Proxy-Authorization)["']?\s*:\s*["']?[^\r\n"']+/gi, "$1: [REDACTED]"],
  [/\bBearer\s+[A-Za-z0-9._~+/-]{16,}=*/g, "Bearer [REDACTED]"],

  // Provider-prefixed tokens.
  [/\bgithub_pat_[A-Za-z0-9_]{20,}/g, "[REDACTED:github-token]"],
  [/\bgh[pousr]_[A-Za-z0-9]{20,}/g, "[REDACTED:github-token]"],
  [/\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}/g, "[REDACTED:openai-key]"],
  // Stripe uses an underscore, not the hyphen the OpenAI rule above expects.
  [/\b[srp]k_(?:live|test)_[A-Za-z0-9]{10,}/g, "[REDACTED:stripe-key]"],
  [/\bwhsec_[A-Za-z0-9]{16,}/g, "[REDACTED:stripe-webhook-secret]"],
  [/\bSG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/g, "[REDACTED:sendgrid-key]"],
  [/\bxox[baprs]-[A-Za-z0-9-]{10,}/g, "[REDACTED:slack-token]"],
  [/\bAKIA[0-9A-Z]{16}\b/g, "[REDACTED:aws-key-id]"],
  [/\bASIA[0-9A-Z]{16}\b/g, "[REDACTED:aws-key-id]"],
  [/\bAIza[0-9A-Za-z_-]{35}\b/g, "[REDACTED:google-key]"],
  [/\bphc_[A-Za-z0-9]{20,}/g, "[REDACTED:posthog-key]"],
  // Third segment optional: an unsigned/alg-none JWT is still a live bearer
  // credential in plenty of systems, and it carries claims either way.
  [/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}(?:\.[A-Za-z0-9_-]+)?/g, "[REDACTED:jwt]"],

  // key=value / key: value assignments for secret-ish names. The value may be
  // quoted; stop at the closing quote or at whitespace. The negative lookahead
  // keeps this from re-mangling a value an earlier rule already redacted
  // (Authorization in particular matches the `auth` name class below).
  [
    /\b([A-Za-z0-9_.-]*(?:password|passwd|pass|pwd|pw|secret|token|api[_-]?key|access[_-]?key|account[_-]?key|private[_-]?key|client[_-]?secret|cred|auth)[A-Za-z0-9_.-]*)\s*[:=]\s*(?!\[REDACTED)(?:"[^"]*"|'[^']*'|\S+)/gi,
    "$1=[REDACTED]",
  ],

  // Credentials embedded in URLs: scheme://user:pass@host
  [/\b([a-z][a-z0-9+.-]*:\/\/)[^\s:/@]+:[^\s:/@]+@/gi, "$1[REDACTED]@"],

  // Bare high-entropy runs. Last, and deliberately conservative.
  //
  // Hex at 32+ rather than 40+: a Twilio auth token is exactly 32 hex and was
  // sailing straight through. Nothing else in the 32-39 range is common enough
  // to be worth the leak (full git SHAs are 40 and were already redacted here).
  [/\b[A-Fa-f0-9]{32,}\b/g, "[REDACTED:hex]"],
  // An AWS secret access key is exactly 40 base64 chars, well under the 60 the
  // generic rule below wants. Requiring all three character classes is what
  // keeps this off prose, paths and identifiers of the same length.
  [
    /\b(?=[A-Za-z0-9+/]{40}\b)(?=[A-Za-z0-9+/]*[a-z])(?=[A-Za-z0-9+/]*[A-Z])(?=[A-Za-z0-9+/]*[0-9])[A-Za-z0-9+/]{40}\b/g,
    "[REDACTED:aws-secret]",
  ],
  [/\b[A-Za-z0-9+/]{60,}={0,2}\b/g, "[REDACTED:b64]"],
];

/**
 * Redact credentials from free text and cap its length.
 * Never throws — a non-string input returns an empty string.
 */
export function scrub(text) {
  if (typeof text !== "string" || text.length === 0) return "";

  // Bound the input before any pattern runs. Redaction still happens before
  // truncation for everything that could reach the endpoint — that ordering is
  // load-bearing and must stay: truncating first would slice a token in half
  // and emit the surviving prefix unredacted.
  const overflow = text.length > MAX_INPUT ? text.length - MAX_INPUT : 0;
  let out = overflow > 0 ? text.slice(0, MAX_INPUT) : text;

  for (const [pattern, replacement] of RULES) {
    out = out.replace(pattern, replacement);
  }

  if (out.length > MAX_LEN) {
    out = out.slice(0, MAX_LEN) + `… [truncated ${out.length - MAX_LEN + overflow} chars]`;
  } else if (overflow > 0) {
    out = out + `… [truncated ${overflow} chars]`;
  }
  return out;
}

export const SCRUB_MAX_LEN = MAX_LEN;
export const SCRUB_MAX_INPUT = MAX_INPUT;
