/**
 * shadowDiffPdf.js -- Shadow Diff PDF report generation for Aletheia Beyond
 *
 * Export: generateShadowDiffPDF(result, mode)
 *   result -- shadow diff result object from /shadow-diff/run
 *   mode   -- 'engineer' or 'executive'
 */

import jsPDF from 'jspdf';

// ── Shared constants (match pdfExport.js) ────────────────────────
const NAVY = [27, 42, 74];
const GRAY = [128, 128, 128];
const LIGHT_GRAY = [200, 200, 200];
const WHITE = [255, 255, 255];
const VERDICT_GREEN = [39, 174, 96];
const VERDICT_RED = [192, 57, 43];

const MARGIN = 20;
const BOTTOM_RESERVE = 25;

// ── Helpers ──────────────────────────────────────────────────────

const createDoc = () => {
  const doc = new jsPDF();
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const contentWidth = pageWidth - MARGIN * 2;
  let yPos = MARGIN;

  const getY = () => yPos;
  const setY = (v) => { yPos = v; };
  const addY = (v) => { yPos += v; };

  const checkPageBreak = (needed) => {
    if (yPos + needed > pageHeight - BOTTOM_RESERVE) {
      doc.addPage();
      yPos = MARGIN;
      return true;
    }
    return false;
  };

  const addHeading = (text, level) => {
    const sizes = { 1: 14, 2: 11, 3: 9 };
    const spacing = { 1: 10, 2: 8, 3: 6 };
    const size = sizes[level] || 9;
    const space = spacing[level] || 6;

    checkPageBreak(space + 10);
    doc.setFontSize(size);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(0);
    doc.text(text, MARGIN, yPos);
    yPos += space;

    if (level === 1) {
      doc.setDrawColor(...LIGHT_GRAY);
      doc.line(MARGIN, yPos - 3, pageWidth - MARGIN, yPos - 3);
      yPos += 2;
    }
  };

  const addParagraph = (text, fontSize = 9) => {
    if (!text) return;
    doc.setFontSize(fontSize);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(60);
    const lines = doc.splitTextToSize(String(text), contentWidth);
    const lineHeight = fontSize * 0.45;

    for (const line of lines) {
      checkPageBreak(lineHeight + 2);
      doc.text(line, MARGIN, yPos);
      yPos += lineHeight;
    }
    yPos += 3;
  };

  const addFooters = (headerText) => {
    const totalPages = doc.getNumberOfPages();
    for (let i = 1; i <= totalPages; i++) {
      doc.setPage(i);

      if (i > 1) {
        doc.setFontSize(7);
        doc.setTextColor(...GRAY);
        doc.setFont('helvetica', 'normal');
        doc.text(headerText, MARGIN, 12);
        doc.text(`Page ${i} of ${totalPages}`, pageWidth - MARGIN, 12, { align: 'right' });
        doc.setDrawColor(...LIGHT_GRAY);
        doc.line(MARGIN, 14, pageWidth - MARGIN, 14);
      }

      doc.setFontSize(7);
      doc.setTextColor(...GRAY);
      doc.text('CONFIDENTIAL -- ALETHEIA BEYOND', pageWidth / 2, pageHeight - 8, { align: 'center' });
    }
  };

  return {
    doc, pageWidth, pageHeight, contentWidth,
    getY, setY, addY, checkPageBreak,
    addHeading, addParagraph, addFooters,
  };
};

// Truncate text to fit a column width
const truncate = (doc, text, maxWidth, fontSize) => {
  doc.setFontSize(fontSize);
  const str = String(text ?? '');
  if (doc.getTextWidth(str) <= maxWidth) return str;
  let t = str;
  while (t.length > 1 && doc.getTextWidth(t + '...') > maxWidth) {
    t = t.slice(0, -1);
  }
  return t + '...';
};

// ── Cover Page ───────────────────────────────────────────────────

const drawCover = (h, result) => {
  const { doc, pageWidth, pageHeight } = h;

  // Subtitle
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(...GRAY);
  doc.text('A L E T H E I A    B E Y O N D', pageWidth / 2, 50, { align: 'center' });

  // Divider
  doc.setDrawColor(...LIGHT_GRAY);
  doc.line(pageWidth / 2 - 40, 55, pageWidth / 2 + 40, 55);

  // Title
  doc.setFontSize(22);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...NAVY);
  doc.text('SHADOW DIFF', pageWidth / 2, 78, { align: 'center' });
  doc.setFontSize(18);
  doc.text('VERIFICATION REPORT', pageWidth / 2, 90, { align: 'center' });

  // Layout name
  doc.setFontSize(13);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(0);
  doc.text(result.layout_name || 'Unknown Layout', pageWidth / 2, 115, { align: 'center' });

  // Metadata block
  const metaY = 140;
  doc.setFontSize(8);
  doc.setFont('courier', 'normal');
  doc.setTextColor(80);
  const metaLines = [
    `Timestamp:      ${result.timestamp || new Date().toISOString()}`,
    `Input Hash:     ${result.input_file_hash || 'N/A'}`,
    `Output Hash:    ${result.output_file_hash || 'N/A'}`,
  ];
  metaLines.forEach((line, i) => {
    doc.text(line, pageWidth / 2, metaY + i * 7, { align: 'center' });
  });

  // Bottom tagline
  doc.setFontSize(8);
  doc.setTextColor(...GRAY);
  doc.text('Zero-Error Behavioral Verification Pipeline', pageWidth / 2, pageHeight - 25, { align: 'center' });
};

// ── Verdict Banner ───────────────────────────────────────────────

const drawVerdict = (h, result) => {
  const { doc, pageWidth, contentWidth } = h;
  const isZero = result.mismatches === 0;

  h.checkPageBreak(30);

  const bannerY = h.getY();
  const bannerH = 22;

  doc.setFillColor(...(isZero ? VERDICT_GREEN : VERDICT_RED));
  doc.rect(MARGIN, bannerY, contentWidth, bannerH, 'F');

  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...WHITE);
  doc.text(
    result.verdict || (isZero ? 'ZERO DRIFT CONFIRMED' : `DRIFT DETECTED -- ${result.mismatches} RECORDS`),
    pageWidth / 2,
    bannerY + 9,
    { align: 'center' }
  );

  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  doc.text(
    `${result.total_records} records processed  |  ${result.match_rate} match rate`,
    pageWidth / 2,
    bannerY + 17,
    { align: 'center' }
  );

  h.setY(bannerY + bannerH + 10);
};

// ── Summary Stats ────────────────────────────────────────────────

const drawStats = (h, result) => {
  const { doc, contentWidth } = h;

  h.addHeading('1. SUMMARY', 1);

  h.checkPageBreak(28);

  const stats = [
    { label: 'Total Records', value: String(result.total_records ?? 0) },
    { label: 'Matches', value: String(result.matches ?? 0) },
    { label: 'Mismatches', value: String(result.mismatches ?? 0) },
    { label: 'S0C7 Abends', value: String(result.s0c7_abends ?? 0) },
    { label: 'Match Rate', value: result.match_rate || 'N/A' },
  ];

  const boxW = contentWidth / stats.length;
  const boxH = 20;
  const boxY = h.getY();

  stats.forEach((s, i) => {
    const x = MARGIN + i * boxW;

    doc.setDrawColor(...LIGHT_GRAY);
    doc.rect(x, boxY, boxW, boxH);

    doc.setFontSize(12);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...NAVY);
    doc.text(s.value, x + boxW / 2, boxY + 9, { align: 'center' });

    doc.setFontSize(6);
    doc.setFont('helvetica', 'normal');
    doc.setTextColor(...GRAY);
    doc.text(s.label.toUpperCase(), x + boxW / 2, boxY + 16, { align: 'center' });
  });

  h.setY(boxY + boxH + 8);
};

// ── Executive Summary Paragraph ──────────────────────────────────

const drawExecutiveSummary = (h, result) => {
  h.addHeading('2. EXECUTIVE SUMMARY', 1);

  let summary;
  const total = result.total_records ?? 0;
  const matches = result.matches ?? 0;
  const mismatches = result.mismatches ?? 0;
  const s0c7 = result.s0c7_abends ?? 0;

  if (mismatches === 0 && s0c7 === 0) {
    summary = `All ${total} records matched with zero drift. The Aletheia verification model produced output identical to the mainframe for every field in every record. No behavioral divergence was detected.`;
  } else if (mismatches === 0 && s0c7 > 0) {
    summary = `All ${total} records that could be compared matched with zero drift. However, ${s0c7} S0C7 Data Exception${s0c7 > 1 ? 's were' : ' was'} detected in the input data, indicating non-numeric content in numeric fields. These records would have caused an abend on the mainframe.`;
  } else {
    const pct = total > 0 ? ((mismatches / total) * 100).toFixed(1) : '0.0';
    summary = `${mismatches} of ${total} records (${pct}%) showed behavioral divergence requiring investigation. ${matches} records matched exactly.`;
    if (s0c7 > 0) {
      summary += ` Additionally, ${s0c7} S0C7 Data Exception${s0c7 > 1 ? 's were' : ' was'} detected in the input data.`;
    }
    summary += ' See the mismatch detail below for root-cause analysis and recommended remediation.';
  }

  h.addParagraph(summary, 9);
};

// ── Generic Table Drawer ─────────────────────────────────────────

const drawTable = (h, columns, rows, options = {}) => {
  const { doc, contentWidth, pageWidth } = h;
  const { maxRows, overflowNote } = options;
  const rowHeight = 8;
  const headerHeight = 8;
  const fontSize = 7;

  // Calculate column widths
  const totalWeight = columns.reduce((sum, c) => sum + (c.weight || 1), 0);
  const cols = columns.map((c) => {
    const w = ((c.weight || 1) / totalWeight) * contentWidth;
    return { ...c, w };
  });
  // Compute x positions
  let xAccum = MARGIN;
  cols.forEach((c) => { c.x = xAccum; xAccum += c.w; });

  const displayRows = maxRows && rows.length > maxRows ? rows.slice(0, maxRows) : rows;
  const truncated = maxRows && rows.length > maxRows;

  // Draw header
  const drawHeader = () => {
    h.checkPageBreak(headerHeight + rowHeight + 4);
    const hy = h.getY();
    doc.setFillColor(...NAVY);
    doc.rect(MARGIN, hy - 5, contentWidth, headerHeight, 'F');
    doc.setFontSize(6.5);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...WHITE);
    cols.forEach((c) => {
      doc.text(c.label.toUpperCase(), c.x + 2, hy);
    });
    h.setY(hy + headerHeight - 1);
  };

  drawHeader();

  // Draw rows
  displayRows.forEach((row, ri) => {
    // Estimate row height: wrap text for each column, find max lines
    doc.setFontSize(fontSize);
    doc.setFont('helvetica', 'normal');
    const cellLines = cols.map((c) => {
      const val = String(row[c.key] ?? '--');
      return doc.splitTextToSize(val, c.w - 4);
    });
    const maxLines = Math.max(...cellLines.map((l) => l.length), 1);
    const thisRowH = Math.max(maxLines * (fontSize * 0.42) + 4, rowHeight);

    // Page break -- redraw header on new page
    if (h.getY() + thisRowH > h.pageHeight - BOTTOM_RESERVE) {
      doc.addPage();
      h.setY(MARGIN);
      drawHeader();
    }

    const ry = h.getY();

    // Alternating background
    if (ri % 2 === 0) {
      doc.setFillColor(248, 249, 252);
      doc.rect(MARGIN, ry - 4, contentWidth, thisRowH, 'F');
    }

    // Cell text
    doc.setFontSize(fontSize);
    doc.setFont(row._font || 'helvetica', 'normal');
    doc.setTextColor(50);

    cols.forEach((c, ci) => {
      const lines = cellLines[ci];
      lines.forEach((line, li) => {
        doc.text(line, c.x + 2, ry + li * (fontSize * 0.42));
      });
    });

    // Bottom border
    doc.setDrawColor(230);
    doc.line(MARGIN, ry + thisRowH - 4, pageWidth - MARGIN, ry + thisRowH - 4);

    h.setY(ry + thisRowH);
  });

  // Overflow note
  if (truncated && overflowNote) {
    h.checkPageBreak(10);
    doc.setFontSize(7);
    doc.setFont('helvetica', 'italic');
    doc.setTextColor(...GRAY);
    doc.text(overflowNote, MARGIN, h.getY() + 2);
    h.addY(8);
  }

  h.addY(4);
};

// ── Cryptographic Section ────────────────────────────────────────

const drawCrypto = (h, result, sectionNum) => {
  const { doc } = h;

  h.addHeading(`${sectionNum}. CRYPTOGRAPHIC FINGERPRINTS`, 1);

  h.checkPageBreak(30);

  doc.setFontSize(8);
  doc.setFont('courier', 'normal');
  doc.setTextColor(40);

  const lines = [
    `Input File:     ${result.input_file_hash || 'N/A'}`,
    `Output File:    ${result.output_file_hash || 'N/A'}`,
    `Timestamp:      ${result.timestamp || 'N/A'}`,
    `Layout:         ${result.layout_name || 'N/A'}`,
  ];

  lines.forEach((line) => {
    h.checkPageBreak(5);
    doc.text(line, MARGIN + 2, h.getY());
    h.addY(5);
  });

  h.addY(6);
};

// ── Executive Mismatch Table (diagnosed, limited columns) ────────

const drawExecutiveMismatches = (h, result, sectionNum) => {
  const diagnosed = result.diagnosed_mismatches || [];
  if (diagnosed.length === 0) return;

  h.addHeading(`${sectionNum}. DRIFT ANALYSIS`, 1);

  const columns = [
    { key: 'record', label: 'Record #', weight: 1 },
    { key: 'field', label: 'Field', weight: 1.5 },
    { key: 'likely_cause', label: 'Likely Cause', weight: 3 },
    { key: 'suggested_fix', label: 'Suggested Fix', weight: 3 },
  ];

  drawTable(h, columns, diagnosed, {
    maxRows: 25,
    overflowNote: 'See engineer report for full details.',
  });
};

// ── Engineer Mismatch Table (full diagnosed) ─────────────────────

const drawEngineerMismatches = (h, result, sectionNum) => {
  const diagnosed = result.diagnosed_mismatches || [];
  if (diagnosed.length === 0) return;

  h.addHeading(`${sectionNum}. DIAGNOSED MISMATCHES`, 1);

  const columns = [
    { key: 'record', label: 'Record #', weight: 0.8 },
    { key: 'field', label: 'Field', weight: 1.2 },
    { key: 'aletheia_value', label: 'Aletheia', weight: 1.3 },
    { key: 'mainframe_value', label: 'Mainframe', weight: 1.3 },
    { key: 'magnitude', label: 'Magnitude', weight: 1 },
    { key: 'likely_cause', label: 'Likely Cause', weight: 2.2 },
    { key: 'suggested_fix', label: 'Suggested Fix', weight: 2.2 },
  ];

  drawTable(h, columns, diagnosed);
};

// ── S0C7 Abend Details Table ─────────────────────────────────────

const drawS0C7Details = (h, result, sectionNum) => {
  const details = result.s0c7_details || [];
  if (details.length === 0) return;

  h.addHeading(`${sectionNum}. S0C7 DATA EXCEPTIONS`, 1);

  h.addParagraph(
    `${details.length} S0C7 Data Exception${details.length > 1 ? 's' : ''} detected. ` +
    'These records contained non-numeric data in numeric fields and would cause an abend on the mainframe.',
    8
  );

  const columns = [
    { key: 'record', label: 'Record #', weight: 1 },
    { key: 'field', label: 'Field', weight: 1.5 },
    { key: 'invalid_value', label: 'Invalid Value', weight: 2 },
    { key: 'message', label: 'Message', weight: 4 },
  ];

  // Normalize: s0c7_details may use different key names
  const rows = details.map((d) => ({
    record: d.record ?? d.record_number ?? '--',
    field: d.field ?? d.field_name ?? '--',
    invalid_value: d.invalid_value ?? '--',
    message: d.message ?? d.reason ?? '--',
  }));

  drawTable(h, columns, rows);
};

// ── Raw Mismatch Log (courier, engineer only) ────────────────────

const drawRawLog = (h, result, sectionNum) => {
  const { doc } = h;
  const log = result.mismatch_log || [];
  if (log.length === 0) return;

  h.addHeading(`${sectionNum}. RAW MISMATCH LOG`, 1);

  const lineHeight = 3.4;
  const fontSize = 7;

  doc.setFontSize(fontSize);
  doc.setFont('courier', 'normal');
  doc.setTextColor(40);

  log.forEach((entry, i) => {
    const line = `[${String(i + 1).padStart(4, ' ')}]  rec=${entry.record}  field=${entry.field}  aletheia=${entry.aletheia_value}  mainframe=${entry.mainframe_value}  diff=${entry.difference}`;

    if (h.getY() + lineHeight > h.pageHeight - BOTTOM_RESERVE) {
      doc.addPage();
      h.setY(MARGIN);
    }

    // Alternating background
    if (i % 2 === 0) {
      doc.setFillColor(248, 249, 252);
      doc.rect(MARGIN, h.getY() - 3, h.contentWidth, lineHeight + 1, 'F');
    }

    doc.setTextColor(40);
    const truncated = line.length > 120 ? line.substring(0, 117) + '...' : line;
    doc.text(truncated, MARGIN + 1, h.getY());
    h.addY(lineHeight);
  });

  h.addY(6);
};

// ═════════════════════════════════════════════════════════════════
// Main Export
// ═════════════════════════════════════════════════════════════════

export const generateShadowDiffPDF = (result, mode = 'engineer') => {
  if (!result) return;

  const h = createDoc();
  const isExec = mode === 'executive';

  // ── Page 1: Cover ──
  drawCover(h, result);

  // ── Page 2+: Content ──
  h.doc.addPage();
  h.setY(MARGIN + 6);

  // Verdict banner
  drawVerdict(h, result);

  // Summary stats
  drawStats(h, result);

  let section = 2;

  if (isExec) {
    // Executive summary paragraph
    drawExecutiveSummary(h, result);
    section = 3;

    // Executive mismatch table (diagnosed, max 25)
    if (result.mismatches > 0) {
      drawExecutiveMismatches(h, result, section);
      section++;
    }

    // Crypto
    drawCrypto(h, result, section);
  } else {
    // Engineer: full diagnosed mismatch table
    if (result.mismatches > 0 || (result.diagnosed_mismatches || []).length > 0) {
      drawEngineerMismatches(h, result, section);
      section++;
    }

    // S0C7 details
    if ((result.s0c7_details || []).length > 0) {
      drawS0C7Details(h, result, section);
      section++;
    }

    // Raw mismatch log
    if ((result.mismatch_log || []).length > 0) {
      drawRawLog(h, result, section);
      section++;
    }

    // Crypto
    drawCrypto(h, result, section);
  }

  // ── Headers and footers ──
  h.addFooters('ALETHEIA BEYOND -- SHADOW DIFF REPORT');

  // ── Save ──
  const layout = (result.layout_name || 'shadow-diff').replace(/[^a-z0-9]/gi, '_');
  const modeTag = isExec ? 'executive' : 'engineer';
  h.doc.save(`shadow_diff_${modeTag}_${layout}_${Date.now()}.pdf`);
};

export default generateShadowDiffPDF;
