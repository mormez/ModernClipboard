// Markdown -> .pdf converter for the Modern Clipboard manuals.
// Usage: node generate_pdf.js input.md output.pdf "Title" "Subtitle"
// Renders an HTML page and prints it to PDF via headless Chrome (no extra deps).

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const [, , inputPath, outputPath, title, subtitle] = process.argv;

const md = fs.readFileSync(inputPath, "utf8");
const lines = md.split("\n");

// Modern Clipboard brand purple (from the app icon, #6C63FF), as a light tint
// for table headers, with a darker shade of the same hue for header text.
const BRAND_HEADER_BG = "#D9D8FF";
const BRAND_HEADER_TEXT = "#4640A6";

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(text) {
  let html = escapeHtml(text);
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/`(.+?)`/g, '<code>$1</code>');
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  return html;
}

const out = [];
let i = 0;

while (i < lines.length) {
  const line = lines[i];
  const trimmed = line.trim();

  if (trimmed === "" || trimmed === "---") { i++; continue; }

  if (trimmed === "<!-- page-break -->") {
    out.push('<div class="page-break"></div>');
    i++;
    continue;
  }

  if (/^#\s/.test(trimmed) && i < 3) { i++; continue; }
  if (i < 6 && /^\*\*Version/.test(trimmed)) { i++; continue; }

  if (/^##\s+Table of Contents/i.test(trimmed)) {
    i++;
    while (i < lines.length && lines[i].trim() !== "---") i++;
    i++;
    continue;
  }

  if (trimmed.startsWith("```")) {
    const block = [];
    i++;
    while (i < lines.length && !lines[i].trim().startsWith("```")) { block.push(lines[i]); i++; }
    i++;
    out.push(`<pre>${escapeHtml(block.join("\n"))}</pre>`);
    continue;
  }

  let m = trimmed.match(/^(#{1,4})\s+(.*)$/);
  if (m) {
    const level = m[1].length;
    out.push(`<h${level}>${inline(m[2])}</h${level}>`);
    i++;
    continue;
  }

  if (trimmed.startsWith("|")) {
    const tableLines = [];
    while (i < lines.length && lines[i].trim().startsWith("|")) { tableLines.push(lines[i].trim()); i++; }
    const rows = tableLines.filter((l) => !/^\|[\s:|-]+\|$/.test(l));
    const parsed = rows.map((r) => r.replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim()));
    out.push("<table>");
    parsed.forEach((cells, ri) => {
      const tag = ri === 0 ? "th" : "td";
      out.push("<tr>" + cells.map((c) => `<${tag}>${inline(c)}</${tag}>`).join("") + "</tr>");
    });
    out.push("</table>");
    continue;
  }

  if (trimmed.startsWith(">")) {
    out.push(`<blockquote>${inline(trimmed.replace(/^>\s*/, ""))}</blockquote>`);
    i++;
    continue;
  }

  if (/^[-*]\s+/.test(trimmed)) {
    const items = [];
    while (i < lines.length && /^[-*]\s+/.test(lines[i].trim())) {
      items.push(`<li>${inline(lines[i].trim().replace(/^[-*]\s+/, ""))}</li>`);
      i++;
    }
    out.push(`<ul>${items.join("")}</ul>`);
    continue;
  }

  m = trimmed.match(/^(\d+)\.\s+(.*)$/);
  if (m) {
    const items = [];
    while (i < lines.length) {
      const mm = lines[i].trim().match(/^(\d+)\.\s+(.*)$/);
      if (!mm) break;
      items.push(`<li>${inline(mm[2])}</li>`);
      i++;
    }
    out.push(`<ol>${items.join("")}</ol>`);
    continue;
  }

  out.push(`<p>${inline(trimmed)}</p>`);
  i++;
}

const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
<style>
  @page { size: Letter; margin: 0.7in 0.8in; }
  body { font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif; color: #1a1a1a; font-size: 13px; line-height: 1.48; }
  h1.doc-title { text-align: center; font-size: 23px; margin-top: 0; margin-bottom: 3px; }
  p.doc-subtitle { text-align: center; font-style: italic; color: #666; margin-top: 0; margin-bottom: 18px; }
  h1 { font-size: 18.5px; margin-top: 18px; margin-bottom: 9px; border-bottom: 2px solid ${BRAND_HEADER_BG}; padding-bottom: 4px; }
  h2 { font-size: 16px; margin-top: 16px; margin-bottom: 7px; color: ${BRAND_HEADER_TEXT}; }
  h3, h4 { font-size: 14px; margin-top: 13px; margin-bottom: 4px; }
  p { margin: 7px 0; }
  table { width: 100%; border-collapse: collapse; margin: 9px 0; }
  th, td { border: 1px solid #ccc; padding: 5px 8px; text-align: left; font-size: 12.5px; }
  th { background: ${BRAND_HEADER_BG}; color: ${BRAND_HEADER_TEXT}; font-weight: 600; }
  code { font-family: Menlo, monospace; color: #AD1457; background: #f5f5f5; padding: 1px 4px; border-radius: 3px; }
  pre { font-family: Menlo, monospace; font-size: 11.5px; background: #f5f5f5; padding: 10px; border-radius: 4px; white-space: pre; }
  blockquote { border-left: 3px solid #999; margin: 7px 0; padding: 4px 14px; color: #444; font-style: italic; }
  a { color: #4640A6; }
  ul, ol { margin: 5px 0; padding-left: 24px; }
  li { margin: 2px 0; }
  .page-break { page-break-before: always; break-before: page; }
</style>
</head><body>
<h1 class="doc-title">${escapeHtml(title)}</h1>
${subtitle ? `<p class="doc-subtitle">${escapeHtml(subtitle)}</p>` : ""}
${out.join("\n")}
</body></html>`;

const tmpHtml = path.join(os.tmpdir(), `mc-pdf-${Date.now()}.html`);
fs.writeFileSync(tmpHtml, html);

const chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
execFileSync(chromePath, [
  "--headless",
  "--disable-gpu",
  "--no-pdf-header-footer",
  `--print-to-pdf=${outputPath}`,
  "--print-to-pdf-no-header",
  `file://${tmpHtml}`,
], { stdio: "inherit" });

fs.unlinkSync(tmpHtml);
console.log("Wrote", outputPath);
