#!/usr/bin/env node
// Reads the json-summary coverage report written by `sf project deploy validate`
// and fails the build when overall line coverage is below the threshold.
const fs = require("fs");
const path = require("path");

const [, , resultsDir = "deploy-results", thresholdArg = "85"] = process.argv;
const threshold = Number(thresholdArg);

function findSummary(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const found = findSummary(full);
      if (found) return found;
    } else if (entry.name === "coverage-summary.json") {
      return full;
    }
  }
  return null;
}

if (!fs.existsSync(resultsDir)) {
  console.error(`Results folder "${resultsDir}" not found`);
  process.exit(1);
}
const summaryFile = findSummary(resultsDir);
if (!summaryFile) {
  console.error(`coverage-summary.json not found under ${resultsDir}`);
  process.exit(1);
}

const summary = JSON.parse(fs.readFileSync(summaryFile, "utf8"));
const pct = summary.total.lines.pct;
console.log(`Apex line coverage: ${pct}% (threshold ${threshold}%)`);

const low = Object.entries(summary)
  .filter(([name, data]) => name !== "total" && data.lines.pct < threshold)
  .map(([name, data]) => `  - ${path.basename(name)}: ${data.lines.pct}%`);
if (low.length) console.log(`Classes below threshold:\n${low.join("\n")}`);

if (pct < threshold) {
  console.error("Coverage below threshold: failing the build.");
  process.exit(1);
}
