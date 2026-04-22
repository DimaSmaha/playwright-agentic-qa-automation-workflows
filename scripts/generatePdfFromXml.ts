import fs from "fs";
import path from "path";
import { XMLParser } from "fast-xml-parser";
import { chromium } from "@playwright/test";
import { KNOWN_ISSUES } from "./knownIssues";

const JUNIT_PATH = "./junitreports/test-results.xml";
const OUTPUT_DIR = "./pdf-reports";
const ISSUE_URL = (id: string) => `https://tracker.local/${id}`;

type TestCase = {
  name: string;
  duration: number;
  status: "passed" | "failed" | "skipped";
  failure?: string;
  retries: number;
  location?: string;
  tags: string[];
  cleanName: string;
};

function parseXML(): any {
  const xml = fs.readFileSync(JUNIT_PATH, "utf-8");
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: "@_",
  });
  return parser.parse(xml);
}

function extractTags(name: string) {
  return name.match(/@\w+/g) || [];
}

function cleanName(name: string) {
  return name.replace(/@\w+/g, "").trim();
}

// 🔥 smarter matching instead of exact key lookup
function findKnownIssue(testName: string) {
  const normalizedTest = testName.toLowerCase().trim();

  for (const issueName in KNOWN_ISSUES) {
    const normalizedIssue = issueName.toLowerCase().trim();

    if (normalizedTest.includes(normalizedIssue)) {
      return KNOWN_ISSUES[issueName];
    }
  }

  return null;
}

function extractMinimalError(failureText: string) {
  if (!failureText) return "";

  const lines = failureText.split("\n");

  const errorLine = lines.find((l) => l.startsWith("Error:")) || "";
  const timeoutLine = lines.find((l) => l.includes("Test timeout"));
  const waitingLine = lines.find((l) => l.includes("waiting for"));

  return [errorLine, timeoutLine, waitingLine].filter(Boolean).join("\n");
}

function parseFailure(failureText: string) {
  if (!failureText) return {};

  const retries = (failureText.match(/Retry #/g) || []).length;
  const locationMatch = failureText.match(/(\S+\.ts:\d+:\d+)/);

  return {
    minimalError: extractMinimalError(failureText),
    retries,
    location: locationMatch?.[1],
  };
}

function normalizeTestCase(tc: any): TestCase {
  const name = tc["@_name"];
  const tags = extractTags(name);
  const clean = cleanName(name);

  let status: TestCase["status"] = "passed";
  if (tc.failure) status = "failed";
  else if (tc.skipped !== undefined) status = "skipped";

  const failureData = parseFailure(tc.failure?.["#text"] || "");

  return {
    name,
    duration: Number(tc["@_time"] || 0),
    status,
    failure: failureData.minimalError,
    retries: failureData.retries || 0,
    location: failureData.location,
    tags,
    cleanName: clean,
  };
}

function getTimestamp() {
  return new Date().toLocaleString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function buildHTML(suites: any[]) {
  const allTests = suites.flatMap((s) => s.testcase);
  const normalized = allTests.map(normalizeTestCase);

  const total = normalized.length;
  const passed = normalized.filter((t) => t.status === "passed").length;
  const failed = normalized.filter((t) => t.status === "failed").length;
  const skipped = normalized.filter((t) => t.status === "skipped").length;

  const totalTime = normalized.reduce((acc, t) => acc + t.duration, 0);
  const passRate = ((passed / total) * 100).toFixed(1);

  const timestamp = getTimestamp();

  return `
  <html>
  <head>
    <style>
      body {
        font-family: Arial;
        margin: 0;
        background: #f5f7fa;
      }

      .header {
        background: linear-gradient(135deg, #667eea, #764ba2);
        color: white;
        padding: 20px;
      }

      .timestamp {
        margin-top: 6px;
        font-size: 12px;
        opacity: 0.9;
      }

      .stats {
        display: flex;
        gap: 20px;
        margin-top: 10px;
        flex-wrap: wrap;
      }

      .container {
        padding: 16px;
      }

      .card {
        background: white;
        border-radius: 10px;
        padding: 12px;
        margin-bottom: 12px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.1);
      }

      .passed { border-left: 6px solid #2ecc71; }
      .failed { border-left: 6px solid #e74c3c; }
      .skipped { border-left: 6px solid #f1c40f; }
      .known-issue { border-left: 6px solid #ff9800 !important; }

      .title {
        font-weight: bold;
        margin-bottom: 6px;
      }

      .tags span {
        background: #eee;
        padding: 2px 6px;
        margin-right: 4px;
        border-radius: 4px;
        font-size: 12px;
      }

      pre {
        background: #f8f8f8;
        padding: 6px;
        border-radius: 6px;
        font-size: 12px;
        white-space: pre-wrap;
      }

      .issue-btn {
        display: inline-block;
        margin-top: 6px;
        padding: 6px 10px;
        background: #ff9800;
        color: white;
        text-decoration: none;
        border-radius: 6px;
        font-size: 12px;
      }
    </style>
  </head>

  <body>
    <div class="header">
      <h1>Test Report</h1>
      <div class="timestamp">Generated: ${timestamp}</div>

      <div class="stats">
        <div>Total: ${total}</div>
        <div>Passed: ${passed}</div>
        <div>Failed: ${failed}</div>
        <div>Skipped: ${skipped}</div>
        <div>Pass rate: ${passRate}%</div>
        <div>Total time: ${totalTime.toFixed(2)}s</div>
      </div>
    </div>

    <div class="container">
      ${normalized
        .map((tc) => {
          const issue = findKnownIssue(tc.cleanName);
          const issueClass = issue ? "known-issue" : "";

          return `
          <div class="card ${tc.status} ${issueClass}">
            <div class="title">${tc.name}</div>
            <div>Status: ${tc.status.toUpperCase()}</div>
            <div>Time: ${tc.duration}s</div>

            <div class="tags">
              ${tc.tags.map((t) => `<span>${t}</span>`).join("")}
            </div>

            ${
              issue
                ? `<a class="issue-btn" href="${ISSUE_URL(issue)}" target="_blank">
                     BUG: ${issue}
                   </a>`
                : ""
            }

            ${
              tc.status === "failed" && tc.failure
                ? `<pre>${tc.failure}</pre>`
                : ""
            }
          </div>
          `;
        })
        .join("")}
    </div>
  </body>
  </html>
  `;
}

async function generatePDF(html: string) {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR);

  const fileName = `report-${Date.now()}.pdf`;
  const pdfPath = path.join(OUTPUT_DIR, fileName);

  const browser = await chromium.launch();
  const page = await browser.newPage();

  await page.setContent(html, { waitUntil: "load" });

  await page.pdf({
    path: pdfPath,
    format: "A4",
    printBackground: true,
    margin: { top: "10px", bottom: "10px", left: "10px", right: "10px" },
  });

  await browser.close();

  console.log("PDF generated:", pdfPath);
}

async function main() {
  const parsed = parseXML();
  const suites = parsed.testsuites?.testsuite || [parsed.testsuite];

  const html = buildHTML(Array.isArray(suites) ? suites : [suites]);
  await generatePDF(html);
}

main();
