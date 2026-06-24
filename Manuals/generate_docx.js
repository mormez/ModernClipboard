// Markdown -> .docx converter for the Modern Clipboard manuals.
// Usage: node generate_docx.js input.md output.docx "Title" "Subtitle"
// Requires the `docx` package (npm install -g docx).

const fs = require("fs");
const path = require("path");

function resolveDocx() {
  try { return require("docx"); } catch {}
  const globalPath = "/opt/homebrew/lib/node_modules/docx";
  return require(globalPath);
}

const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow,
  TableCell, WidthType, BorderStyle, AlignmentType, ExternalHyperlink,
  ShadingType, convertInchesToTwip,
} = resolveDocx();

const [, , inputPath, outputPath, title, subtitle] = process.argv;

const md = fs.readFileSync(inputPath, "utf8");
const lines = md.split("\n");

// Modern Clipboard brand purple (from app icon, #6C63FF), as a light tint for
// table headers, with a darker shade of the same hue for header text contrast.
const BRAND_HEADER_BG = "D9D8FF";
const BRAND_HEADER_TEXT = "4640A6";

const cellBorder = {
  top: { style: BorderStyle.SINGLE, size: 2, color: "CCCCCC" },
  bottom: { style: BorderStyle.SINGLE, size: 2, color: "CCCCCC" },
  left: { style: BorderStyle.SINGLE, size: 2, color: "CCCCCC" },
  right: { style: BorderStyle.SINGLE, size: 2, color: "CCCCCC" },
};

// Parse inline markdown (**bold**, `code`, [text](url)) into TextRun/Hyperlink children
function parseInline(text, opts = {}) {
  const runs = [];
  let rest = text;
  const re = /(\*\*(.+?)\*\*|`(.+?)`|\[([^\]]+)\]\(([^)]+)\))/;
  while (rest.length > 0) {
    const m = rest.match(re);
    if (!m) {
      runs.push(new TextRun({ text: rest, bold: opts.bold, color: opts.color }));
      break;
    }
    if (m.index > 0) {
      runs.push(new TextRun({ text: rest.slice(0, m.index), bold: opts.bold, color: opts.color }));
    }
    if (m[2] !== undefined) {
      runs.push(new TextRun({ text: m[2], bold: true, color: opts.color }));
    } else if (m[3] !== undefined) {
      runs.push(new TextRun({ text: m[3], font: "Menlo", color: opts.color || "AD1457" }));
    } else if (m[4] !== undefined) {
      runs.push(new ExternalHyperlink({
        link: m[5],
        children: [new TextRun({ text: m[4], style: "Hyperlink" })],
      }));
    }
    rest = rest.slice(m.index + m[0].length);
  }
  return runs;
}

function heading(text, level) {
  return new Paragraph({
    text: text.replace(/^#+\s*/, ""),
    heading: level,
    spacing: { before: 240, after: 120 },
  });
}

function paragraph(text) {
  return new Paragraph({
    children: parseInline(text),
    spacing: { after: 120 },
  });
}

function bullet(text, ordered, num) {
  const children = ordered
    ? [new TextRun(`${num}. `), ...parseInline(text)]
    : parseInline(text);
  return new Paragraph({
    children,
    bullet: ordered ? undefined : { level: 0 },
    indent: { left: convertInchesToTwip(0.35) },
    spacing: { after: 60 },
  });
}

function blockquote(text) {
  return new Paragraph({
    children: parseInline(text),
    indent: { left: convertInchesToTwip(0.4) },
    border: {
      left: { style: BorderStyle.SINGLE, size: 12, color: "999999", space: 8 },
    },
    spacing: { after: 120 },
    italics: true,
  });
}

function tableCell(text, header) {
  return new TableCell({
    children: [new Paragraph({
      children: parseInline(text, header ? { bold: true, color: BRAND_HEADER_TEXT } : {}),
      spacing: { after: 0 },
    })],
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    borders: cellBorder,
    shading: header ? { type: ShadingType.SOLID, color: BRAND_HEADER_BG, fill: BRAND_HEADER_BG } : undefined,
  });
}

function buildTable(rows) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: rows.map((cells, i) =>
      new TableRow({
        children: cells.map((c) => tableCell(c, i === 0)),
        tableHeader: i === 0,
      })
    ),
  });
}

const headingMap = {
  1: HeadingLevel.HEADING_1,
  2: HeadingLevel.HEADING_2,
  3: HeadingLevel.HEADING_3,
  4: HeadingLevel.HEADING_4,
};

const children = [];

// Title block
children.push(new Paragraph({
  text: title,
  heading: HeadingLevel.TITLE,
  alignment: AlignmentType.CENTER,
  spacing: { after: 80 },
}));
if (subtitle) {
  children.push(new Paragraph({
    children: [new TextRun({ text: subtitle, italics: true, color: "666666" })],
    alignment: AlignmentType.CENTER,
    spacing: { after: 320 },
  }));
}

let i = 0;

while (i < lines.length) {
  const line = lines[i];
  const trimmed = line.trim();

  if (trimmed === "" || trimmed === "---") {
    i++;
    continue;
  }

  // Skip the title line (already emitted) and the bold version line right after it
  if (/^#\s/.test(trimmed) && i < 3) {
    i++;
    continue;
  }
  if (i < 6 && /^\*\*Version/.test(trimmed)) {
    i++;
    continue;
  }
  // Skip Table of Contents block entirely
  if (/^##\s+Table of Contents/i.test(trimmed)) {
    i++;
    while (i < lines.length && lines[i].trim() !== "---") i++;
    i++;
    continue;
  }

  // Code fences (e.g. the ascii-art menu block) - keep as a monospace block
  if (trimmed.startsWith("```")) {
    const block = [];
    i++;
    while (i < lines.length && !lines[i].trim().startsWith("```")) {
      block.push(lines[i]);
      i++;
    }
    i++; // closing fence
    block.forEach((l) => {
      children.push(new Paragraph({
        children: [new TextRun({ text: l || " ", font: "Menlo", size: 18 })],
        spacing: { after: 0 },
      }));
    });
    children.push(new Paragraph({ text: "", spacing: { after: 120 } }));
    continue;
  }

  // Headings
  let m = trimmed.match(/^(#{1,4})\s+(.*)$/);
  if (m) {
    const level = m[1].length;
    children.push(heading(m[2], headingMap[level] || HeadingLevel.HEADING_4));
    i++;
    continue;
  }

  // Tables (markdown pipe tables)
  if (trimmed.startsWith("|")) {
    const tableLines = [];
    while (i < lines.length && lines[i].trim().startsWith("|")) {
      tableLines.push(lines[i].trim());
      i++;
    }
    // remove the separator row (---|---)
    const rows = tableLines.filter((l) => !/^\|[\s:|-]+\|$/.test(l));
    const parsed = rows.map((r) =>
      r.replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim())
    );
    children.push(buildTable(parsed));
    children.push(new Paragraph({ text: "", spacing: { after: 120 } }));
    continue;
  }

  // Blockquote
  if (trimmed.startsWith(">")) {
    children.push(blockquote(trimmed.replace(/^>\s*/, "")));
    i++;
    continue;
  }

  // Unordered list
  if (/^[-*]\s+/.test(trimmed)) {
    children.push(bullet(trimmed.replace(/^[-*]\s+/, ""), false));
    i++;
    continue;
  }

  // Ordered list
  m = trimmed.match(/^(\d+)\.\s+(.*)$/);
  if (m) {
    children.push(bullet(m[2], true, m[1]));
    i++;
    continue;
  }

  // Plain paragraph
  children.push(paragraph(trimmed));
  i++;
}

const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: "Helvetica Neue", size: 22 },
      },
    },
  },
  sections: [{ properties: {}, children }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outputPath, buf);
  console.log("Wrote", outputPath);
});
