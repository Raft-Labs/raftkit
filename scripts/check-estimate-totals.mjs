#!/usr/bin/env node
// Checks the arithmetic of every estimate example the repo ships: in each
// ```output block that carries a `Total:` line, the four totals must be the
// sum of the feature bullets above them — lows added to lows, highs to highs.
//
// The example is the specification a run copies, so a total that does not add
// up teaches the sum wrong. The first version of estimation's canonical
// example printed 45–74 h over components summing to 52–84 h, and every
// string-matching check in the suite passed it.
//
// Sums, never averages and never midpoints: the rule is breakdown-method.md's
// "Sum the lows together and the highs together".
//
// A missing discipline, a `Total:` line with no feature bullets above it, and
// a run that matched no block at all are all failures — a silent zero-match
// pass is how an arithmetic checker stops checking.
//
// Usage: node scripts/check-estimate-totals.mjs <file> [...]
// Exit 0 and a summary on stdout when every block adds up; exit 1 and one
// problem per line on stderr when one does not; exit 2 on a misconfigured
// invocation (no target given, or a target that cannot be read) — never
// conflated with "clean" or "problems found".

import { readFileSync } from "node:fs";

// En-dash range, high optional: a stated `0` is a range whose ends are equal.
const RANGE = "(\\d+)(?:–(\\d+))?";
const DISCIPLINES = ["FE", "BE", "QA"];
const disciplinePattern = (d) => new RegExp(`\\b${d}\\s+${RANGE}\\s*h`);
const TOTAL_PATTERN = new RegExp(`^Total:\\s*${RANGE}\\s*h`);

const targets = process.argv.slice(2);
if (targets.length === 0) {
  console.error("usage: check-estimate-totals.mjs <file> [...]");
  process.exit(2);
}

const problems = [];
let checked = 0;

for (const file of targets) {
  let src;
  try {
    src = readFileSync(file, "utf8");
  } catch (err) {
    console.error(`cannot read target "${file}": ${err.code || err.message}`);
    process.exit(2);
  }

  const blocks = [...src.matchAll(/^```output\n([\s\S]*?)^```$/gm)].map((m) => m[1]);
  for (const block of blocks) {
    const lines = block.split("\n");
    const totalLine = lines.find((l) => /^Total:/.test(l));
    if (!totalLine) continue;
    checked++;

    const features = lines.filter((l) => /^- .*\bFE\s+\d/.test(l));
    if (features.length === 0) {
      problems.push(`${file}: a "Total:" line with no feature bullets above it`);
      continue;
    }

    const sum = { FE: [0, 0], BE: [0, 0], QA: [0, 0] };
    let complete = true;
    for (const feature of features) {
      for (const d of DISCIPLINES) {
        const m = feature.match(disciplinePattern(d));
        if (!m) {
          problems.push(`${file}: feature bullet states no ${d} range: ${feature.trim()}`);
          complete = false;
          continue;
        }
        sum[d][0] += Number(m[1]);
        sum[d][1] += Number(m[2] ?? m[1]);
      }
    }
    if (!complete) continue;

    const want = {
      Total: [
        sum.FE[0] + sum.BE[0] + sum.QA[0],
        sum.FE[1] + sum.BE[1] + sum.QA[1],
      ],
      ...sum,
    };
    for (const [label, expected] of Object.entries(want)) {
      const m = totalLine.match(label === "Total" ? TOTAL_PATTERN : disciplinePattern(label));
      if (!m) {
        problems.push(`${file}: the totals line states no ${label} range`);
        continue;
      }
      const got = [Number(m[1]), Number(m[2] ?? m[1])];
      if (got[0] !== expected[0] || got[1] !== expected[1]) {
        problems.push(
          `${file}: ${label} totals ${got.join("–")} h, but the feature bullets sum to ${expected.join("–")} h`,
        );
      }
    }
  }
}

if (checked === 0) problems.push("no output block with a \"Total:\" line was found");

if (problems.length > 0) {
  console.error(problems.join("\n"));
  process.exit(1);
}

console.log(`checked ${checked} estimate total(s) across ${targets.length} file(s), all add up`);
