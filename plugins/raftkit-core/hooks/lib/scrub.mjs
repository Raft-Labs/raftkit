// Redacts credentials from text before it leaves the machine.
//
// The captured prompt is sent to a third-party analytics sink and pasted into
// GitHub issues, so a live token in a developer's prompt would be exfiltrated by
// this telemetry itself. Scrubbing is not optional and not configurable.
//
// This is a best-effort filter over known credential shapes, not a guarantee.
// It runs on every field that can carry free text.

const MAX_LEN = 2000;

// Ordered: the most specific shapes first, so a bare-entropy match never eats a
// token a named rule would have labelled more precisely.
const RULES = [
  // PEM blocks — match the whole block including newlines.
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g, "[REDACTED:private-key]"],

  // Provider-prefixed tokens.
  [/\bgithub_pat_[A-Za-z0-9_]{20,}/g, "[REDACTED:github-token]"],
  [/\bgh[pousr]_[A-Za-z0-9]{20,}/g, "[REDACTED:github-token]"],
  [/\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}/g, "[REDACTED:openai-key]"],
  [/\bxox[baprs]-[A-Za-z0-9-]{10,}/g, "[REDACTED:slack-token]"],
  [/\bAKIA[0-9A-Z]{16}\b/g, "[REDACTED:aws-key-id]"],
  [/\bASIA[0-9A-Z]{16}\b/g, "[REDACTED:aws-key-id]"],
  [/\bAIza[0-9A-Za-z_-]{35}\b/g, "[REDACTED:google-key]"],
  [/\bphc_[A-Za-z0-9]{20,}/g, "[REDACTED:posthog-key]"],
  [/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g, "[REDACTED:jwt]"],

  // Authorization headers.
  [/\b(Authorization|Proxy-Authorization)\s*:\s*\S+/gi, "$1: [REDACTED]"],
  [/\bBearer\s+[A-Za-z0-9._~+/-]{16,}=*/g, "Bearer [REDACTED]"],

  // key=value / key: value assignments for secret-ish names. The value may be
  // quoted; stop at the closing quote or at whitespace.
  [
    /\b([A-Za-z0-9_.-]*(?:passwd|password|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret|auth)[A-Za-z0-9_.-]*)\s*[:=]\s*(?:"[^"]*"|'[^']*'|\S+)/gi,
    "$1=[REDACTED]",
  ],

  // Credentials embedded in URLs: scheme://user:pass@host
  [/\b([a-z][a-z0-9+.-]*:\/\/)[^\s:/@]+:[^\s:/@]+@/gi, "$1[REDACTED]@"],

  // Bare high-entropy runs. Last, and deliberately conservative: >=40 chars of
  // continuous hex/base64 is not prose. Shorter runs produce false positives on
  // git SHAs and file hashes that are useful signal, so they are left alone.
  [/\b[A-Fa-f0-9]{40,}\b/g, "[REDACTED:hex]"],
  [/\b[A-Za-z0-9+/]{60,}={0,2}\b/g, "[REDACTED:b64]"],
];

/**
 * Redact credentials from free text and cap its length.
 * Never throws — a non-string input returns an empty string.
 */
export function scrub(text) {
  if (typeof text !== "string" || text.length === 0) return "";
  let out = text;
  for (const [pattern, replacement] of RULES) {
    out = out.replace(pattern, replacement);
  }
  if (out.length > MAX_LEN) {
    out = out.slice(0, MAX_LEN) + `… [truncated ${out.length - MAX_LEN} chars]`;
  }
  return out;
}

export const SCRUB_MAX_LEN = MAX_LEN;
