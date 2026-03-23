/**
 * pdfExport.js -- PDF report generation for Aletheia Beyond
 *
 * Two exports:
 * 1. generateForensicPDF(data) -- Single analysis forensic report
 * 2. generateVaultExportPDF(records) -- Multi-record vault summary
 */

import jsPDF from 'jspdf';

// ── Shared helpers ──────────────────────────────────────────────────

const NAVY = [27, 42, 74];
const GRAY = [128, 128, 128];
const LIGHT_GRAY = [200, 200, 200];
const WHITE = [255, 255, 255];
const VERDICT_GREEN = [39, 174, 96];
const VERDICT_RED = [192, 57, 43];

const createHelpers = (doc) => {
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const margin = 20;
  const contentWidth = pageWidth - margin * 2;
  let yPos = margin;

  const getY = () => yPos;
  const setY = (v) => { yPos = v; };

  const checkPageBreak = (neededHeight) => {
    if (yPos + neededHeight > pageHeight - 25) {
      doc.addPage();
      yPos = margin;
    }
  };

  const addHeading = (text, level) => {
    const sizes = { 1: 16, 2: 12, 3: 10 };
    const spacing = { 1: 12, 2: 9, 3: 7 };
    const size = sizes[level] || 10;
    const space = spacing[level] || 7;

    checkPageBreak(space + 10);
    doc.setFontSize(size);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(0);
    doc.text(text, margin, yPos);
    yPos += space;

    if (level === 1) {
      doc.setDrawColor(...LIGHT_GRAY);
      doc.line(margin, yPos - 3, pageWidth - margin, yPos - 3);
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
      doc.text(line, margin, yPos);
      yPos += lineHeight;
    }
    yPos += 3;
  };

  const addCodeBlock = (code, maxLines = 1000) => {
    if (!code) return;
    doc.setFontSize(7.5);
    doc.setFont('courier', 'normal');
    doc.setTextColor(40);

    const allLines = String(code).split('\n');
    const lines = allLines.slice(0, maxLines);
    const lineHeight = 3.2;
    const numWidth = 8;

    for (let i = 0; i < lines.length; i++) {
      checkPageBreak(lineHeight + 2);
      // Line number
      doc.setTextColor(180);
      doc.text(String(i + 1).padStart(4), margin, yPos);
      // Code
      doc.setTextColor(40);
      const truncated = lines[i].length > 95 ? lines[i].substring(0, 92) + '...' : lines[i];
      doc.text(truncated, margin + numWidth, yPos);
      yPos += lineHeight;
    }

    if (allLines.length > maxLines) {
      doc.setFont('helvetica', 'italic');
      doc.setTextColor(140);
      doc.text(`... (${allLines.length - maxLines} more lines)`, margin + numWidth, yPos);
      yPos += lineHeight;
    }

    yPos += 4;
  };

  const addPageHeadersAndFooters = (headerText) => {
    const totalPages = doc.getNumberOfPages();
    for (let i = 1; i <= totalPages; i++) {
      doc.setPage(i);

      // Header on pages 2+ (skip cover)
      if (i > 1) {
        doc.setFontSize(7);
        doc.setTextColor(...GRAY);
        doc.setFont('helvetica', 'normal');
        doc.text(headerText, margin, 12);
        doc.text(`Page ${i} of ${totalPages}`, pageWidth - margin, 12, { align: 'right' });
        doc.setDrawColor(...LIGHT_GRAY);
        doc.line(margin, 14, pageWidth - margin, 14);
      }

      // Footer on all pages
      doc.setFontSize(7);
      doc.setTextColor(...GRAY);
      doc.text('CONFIDENTIAL', pageWidth / 2, pageHeight - 8, { align: 'center' });
    }
  };

  return {
    doc, pageWidth, pageHeight, margin, contentWidth,
    getY, setY, checkPageBreak, addHeading, addParagraph, addCodeBlock,
    addPageHeadersAndFooters,
  };
};

// ════════════════════════════════════════════════════════════════════
// 1. FORENSIC REPORT -- Single analysis (engineer / executive modes)
// ════════════════════════════════════════════════════════════════════

// ── Table helper (matches shadowDiffPdf.js drawTable) ────────────
const drawTable = (h, columns, rows) => {
  const { doc, contentWidth, pageWidth } = h;
  const rowHeight = 8;
  const headerHeight = 8;
  const fontSize = 7;

  const totalWeight = columns.reduce((sum, c) => sum + (c.weight || 1), 0);
  const cols = columns.map((c) => {
    const w = ((c.weight || 1) / totalWeight) * contentWidth;
    return { ...c, w };
  });
  let xAccum = h.margin;
  cols.forEach((c) => { c.x = xAccum; xAccum += c.w; });

  const drawHeader = () => {
    h.checkPageBreak(headerHeight + rowHeight + 4);
    const hy = h.getY();
    doc.setFillColor(...NAVY);
    doc.rect(h.margin, hy - 5, contentWidth, headerHeight, 'F');
    doc.setFontSize(6.5);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...WHITE);
    cols.forEach((c) => { doc.text(c.label.toUpperCase(), c.x + 2, hy); });
    h.setY(hy + headerHeight - 1);
  };

  drawHeader();

  rows.forEach((row, ri) => {
    doc.setFontSize(fontSize);
    doc.setFont('helvetica', 'normal');
    const cellLines = cols.map((c) => {
      const val = String(row[c.key] ?? '--');
      return doc.splitTextToSize(val, c.w - 4);
    });
    const maxLines = Math.max(...cellLines.map((l) => l.length), 1);
    const thisRowH = Math.max(maxLines * (fontSize * 0.42) + 4, rowHeight);

    if (h.getY() + thisRowH > h.pageHeight - 25) {
      doc.addPage();
      h.setY(h.margin);
      drawHeader();
    }

    const ry = h.getY();
    if (ri % 2 === 0) {
      doc.setFillColor(248, 249, 252);
      doc.rect(h.margin, ry - 4, contentWidth, thisRowH, 'F');
    }

    doc.setFontSize(fontSize);
    doc.setFont(row._font || 'helvetica', 'normal');
    doc.setTextColor(50);
    if (row._colorFn) row._colorFn(doc, cols, ry, cellLines, fontSize);
    else cols.forEach((c, ci) => {
      cellLines[ci].forEach((line, li) => {
        doc.text(line, c.x + 2, ry + li * (fontSize * 0.42));
      });
    });

    doc.setDrawColor(230);
    doc.line(h.margin, ry + thisRowH - 4, pageWidth - h.margin, ry + thisRowH - 4);
    h.setY(ry + thisRowH);
  });

  h.setY(h.getY() + 4);
};

export const generateForensicPDF = (result, cobolCode, fileName, mode = 'engineer', shadowDiffResult = null) => {
  const doc = new jsPDF();
  const h = createHelpers(doc);
  const isExec = mode === 'executive';

  // Extract data from result
  const v = result.verification || {};
  const p = result.parser_output || {};
  const summary = p.summary || {};
  const risks = result.arithmetic_risks || [];
  const riskSummary = result.arithmetic_summary || {};
  const emitCounts = result.emit_counts || {};
  const checklist = v.checklist || [];
  const humanReview = v.human_review_items || [];
  const verificationStatus = v.verification_status || result.verification_status || 'N/A';
  const isVerified = verificationStatus === 'VERIFIED';

  let section = 1;

  // ── COVER PAGE ──

  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(...GRAY);
  doc.text('A L E T H E I A    B E Y O N D', h.pageWidth / 2, 50, { align: 'center' });

  doc.setDrawColor(...LIGHT_GRAY);
  doc.line(h.pageWidth / 2 - 40, 55, h.pageWidth / 2 + 40, 55);

  doc.setFontSize(22);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...NAVY);
  doc.text('FORENSIC ANALYSIS', h.pageWidth / 2, 78, { align: 'center' });
  doc.setFontSize(18);
  doc.text('REPORT', h.pageWidth / 2, 90, { align: 'center' });

  doc.setTextColor(0);
  doc.setFontSize(13);
  doc.setFont('helvetica', 'normal');
  doc.text(fileName || 'analysis.cbl', h.pageWidth / 2, 115, { align: 'center' });

  // Metadata block
  const metaY = 140;
  doc.setFontSize(8);
  doc.setFont('courier', 'normal');
  doc.setTextColor(80);
  const analyst = typeof localStorage !== 'undefined' ? (localStorage.getItem('corporate_id') || 'Unknown') : 'Unknown';
  const metaLines = [
    `Timestamp:      ${new Date().toISOString()}`,
    `Analyst:        ${analyst}`,
    `Mode:           ${isExec ? 'EXECUTIVE' : 'ENGINEER'}`,
  ];
  metaLines.forEach((line, i) => {
    doc.text(line, h.pageWidth / 2, metaY + i * 7, { align: 'center' });
  });

  doc.setFontSize(8);
  doc.setTextColor(...GRAY);
  doc.text('Zero-Error Behavioral Verification Pipeline', h.pageWidth / 2, h.pageHeight - 25, { align: 'center' });

  // ── VERDICT BANNER (page 2) ──

  doc.addPage();
  h.setY(h.margin + 6);

  h.checkPageBreak(30);
  const bannerY = h.getY();
  const bannerH = 22;
  const fullyVerified = isVerified && shadowDiffResult && (shadowDiffResult.mismatches || 0) === 0;
  doc.setFillColor(...(isVerified ? VERDICT_GREEN : VERDICT_RED));
  doc.rect(h.margin, bannerY, h.contentWidth, bannerH, 'F');

  doc.setFontSize(13);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...WHITE);
  doc.text(
    fullyVerified ? 'FULLY VERIFIED' : (isVerified ? 'VERIFIED' : 'REQUIRES MANUAL REVIEW'),
    h.pageWidth / 2, bannerY + 9, { align: 'center' }
  );

  doc.setFontSize(8);
  doc.setFont('helvetica', 'normal');
  const statsLine = `${summary.paragraphs || 0} paragraphs  |  ${summary.variables || 0} variables  |  ${summary.comp3_variables || 0} COMP-3 fields`;
  doc.text(statsLine, h.pageWidth / 2, bannerY + 17, { align: 'center' });
  h.setY(bannerY + bannerH + 10);

  // ── BEHAVIORAL VERIFICATION — Shadow Diff summary (both modes, if available) ──

  if (shadowDiffResult) {
    const sdTotal = shadowDiffResult.total_records || 0;
    const sdMismatches = shadowDiffResult.mismatches || 0;
    const sdMatches = sdTotal - sdMismatches;
    const sdVerdict = shadowDiffResult.verdict || (sdMismatches === 0 ? 'ZERO DRIFT CONFIRMED' : 'DRIFT DETECTED');
    const sdInputHash = shadowDiffResult.input_file_hash || shadowDiffResult.input_fingerprint || 'N/A';
    const sdOutputHash = shadowDiffResult.output_file_hash || shadowDiffResult.output_fingerprint || 'N/A';

    // Sub-banner for shadow diff
    h.checkPageBreak(20);
    const sdBannerY = h.getY();
    const sdBannerH = 16;
    doc.setFillColor(...(sdMismatches === 0 ? VERDICT_GREEN : VERDICT_RED));
    doc.rect(h.margin, sdBannerY, h.contentWidth, sdBannerH, 'F');
    doc.setFontSize(10);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...WHITE);
    doc.text(sdVerdict, h.pageWidth / 2, sdBannerY + 7, { align: 'center' });
    doc.setFontSize(7);
    doc.setFont('helvetica', 'normal');
    doc.text(
      `${sdTotal} records processed  |  ${sdMatches} matches  |  ${sdMismatches} mismatches`,
      h.pageWidth / 2, sdBannerY + 12, { align: 'center' }
    );
    h.setY(sdBannerY + sdBannerH + 4);

    // Fingerprints
    doc.setFontSize(7);
    doc.setFont('courier', 'normal');
    doc.setTextColor(100);
    doc.text(`Input fingerprint:  ${sdInputHash}`, h.margin, h.getY());
    h.setY(h.getY() + 3.5);
    doc.text(`Output fingerprint: ${sdOutputHash}`, h.margin, h.getY());
    h.setY(h.getY() + 8);
  }

  // ── EXECUTIVE SUMMARY (both modes) ──

  h.addHeading(`${section}. EXECUTIVE SUMMARY`, 1);
  section++;
  h.addParagraph(v.executive_summary || result.formatted_output || 'No summary available.');

  // ── ENGINEER-ONLY: Code sections ──

  if (!isExec) {
    h.addHeading(`${section}. ORIGINAL COBOL SOURCE`, 1);
    section++;
    h.addCodeBlock(cobolCode);

    h.addHeading(`${section}. VERIFICATION MODEL (PYTHON)`, 1);
    section++;
    h.addCodeBlock(result.generated_python);

    // Mathematical Breakdown
    const mathBreakdown = (v.business_logic || []).map(b => `${b.title}: ${b.formula}`).join('\n');
    if (mathBreakdown) {
      h.addHeading(`${section}. MATHEMATICAL BREAKDOWN`, 1);
      section++;
      h.addParagraph(mathBreakdown);
    }

    // Statement Coverage
    h.addHeading(`${section}. STATEMENT COVERAGE`, 1);
    section++;
    const hasEmit = Object.keys(emitCounts).length > 0;
    const stmtRows = [
      { type: 'MOVE', captured: summary.move_statements ?? 0, emitted: hasEmit ? (emitCounts.move ?? 0) : 'N/A' },
      { type: 'COMPUTE', captured: summary.compute_statements ?? 0, emitted: hasEmit ? (emitCounts.compute ?? 0) : 'N/A' },
      { type: 'IF', captured: (p.conditions || []).length, emitted: hasEmit ? (emitCounts.condition ?? 0) : 'N/A' },
      { type: 'PERFORM', captured: summary.perform_calls ?? 0, emitted: hasEmit ? (emitCounts.perform ?? 0) : 'N/A' },
      { type: 'GOTO', captured: summary.goto_statements ?? 0, emitted: hasEmit ? (emitCounts.goto ?? 0) : 'N/A' },
      { type: 'STOP', captured: summary.stop_statements ?? 0, emitted: hasEmit ? (emitCounts.stop ?? 0) : 'N/A' },
    ];
    drawTable(h,
      [
        { key: 'type', label: 'Statement Type', weight: 3 },
        { key: 'captured', label: 'Captured', weight: 2 },
        { key: 'emitted', label: 'Emitted', weight: 2 },
      ],
      stmtRows,
    );

    // Control Flow Graph
    const controlFlow = p.control_flow || [];
    if (controlFlow.length > 0) {
      h.addHeading(`${section}. CONTROL FLOW GRAPH`, 1);
      section++;

      // Group by source paragraph
      const groups = {};
      controlFlow.forEach((cf) => {
        const from = cf.from || 'UNKNOWN';
        if (!groups[from]) groups[from] = [];
        groups[from].push(cf);
      });

      Object.entries(groups).forEach(([para, calls]) => {
        h.checkPageBreak(12);
        doc.setFontSize(8);
        doc.setFont('courier', 'bold');
        doc.setTextColor(...NAVY);
        doc.text(para, h.margin, h.getY());
        h.setY(h.getY() + 5);

        calls.forEach((cf) => {
          h.checkPageBreak(5);
          doc.setFontSize(7);
          doc.setFont('courier', 'normal');
          doc.setTextColor(50);
          doc.text(`  \u2192 ${cf.to}${cf.line ? ` (line ${cf.line})` : ''}`, h.margin + 4, h.getY());
          h.setY(h.getY() + 3.5);
        });
        h.setY(h.getY() + 2);
      });
      h.setY(h.getY() + 4);
    }

    // Arithmetic Risk Matrix
    if (risks.length > 0) {
      h.addHeading(`${section}. ARITHMETIC RISK MATRIX`, 1);
      section++;

      const riskRows = risks.map((r) => ({
        field: r.target?.name || 'N/A',
        operation: r.operation || 'N/A',
        pic: r.target?.pic ? `${r.target.pic} (${r.target.integers ?? '?'}.${r.target.decimals ?? '?'})` : 'N/A',
        status: r.status || 'N/A',
        _colorFn: (d, cols, ry, cellLines, fs) => {
          cols.forEach((c, ci) => {
            if (c.key === 'status') {
              const s = r.status;
              if (s === 'SAFE') d.setTextColor(22, 163, 74);
              else if (s === 'WARN') d.setTextColor(217, 119, 6);
              else if (s === 'CRITICAL') d.setTextColor(220, 38, 38);
              else d.setTextColor(50);
            } else {
              d.setTextColor(50);
            }
            cellLines[ci].forEach((line, li) => {
              d.text(line, c.x + 2, ry + li * (fs * 0.42));
            });
          });
        },
      }));

      drawTable(h,
        [
          { key: 'field', label: 'Field', weight: 3 },
          { key: 'operation', label: 'Operation', weight: 2 },
          { key: 'pic', label: 'PIC Constraints', weight: 3 },
          { key: 'status', label: 'Overflow Risk', weight: 2 },
        ],
        riskRows,
      );

      // Summary row
      h.checkPageBreak(10);
      doc.setFontSize(8);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(60);
      doc.text(
        `Total: ${riskSummary.safe || 0} safe, ${riskSummary.warn || 0} warn, ${riskSummary.critical || 0} critical`,
        h.margin, h.getY()
      );
      h.setY(h.getY() + 8);
    }

    // ── DEAD CODE ANALYSIS (engineer only) ──
    const deadCode = result?.dead_code;
    if (deadCode && deadCode.total_paragraphs > 0) {
      h.addHeading(`${section}. DEAD CODE ANALYSIS`, 1);
      section++;

      const deadCount = deadCode.unreachable_paragraphs?.length || 0;
      h.addParagraph(`Total paragraphs: ${deadCode.total_paragraphs}`);
      h.addParagraph(`Reachable: ${deadCode.reachable_paragraphs}`);
      h.addParagraph(`Unreachable: ${deadCount} (${deadCode.dead_percentage}%)`);
      if (deadCode.has_alter) {
        h.addParagraph('Note: ALTER statement detected \u2014 results are approximate.');
      }
      h.setY(h.getY() + 2);

      if (deadCount > 0) {
        const deadRows = deadCode.unreachable_paragraphs.map((p) => ({
          name: p.name || '',
          line: String(p.line || ''),
        }));

        drawTable(h,
          [
            { key: 'name', label: 'Paragraph', weight: 4 },
            { key: 'line', label: 'Line', weight: 1 },
          ],
          deadRows,
        );
      }
    }

    // ── BEHAVIORAL VERIFICATION DETAIL (engineer only) ──

    if (shadowDiffResult) {
      h.addHeading(`${section}. BEHAVIORAL VERIFICATION (SHADOW DIFF)`, 1);
      section++;

      const sdTotal = shadowDiffResult.total_records || 0;
      const sdMismatches = shadowDiffResult.mismatches || 0;
      const sdMatches = sdTotal - sdMismatches;
      const sdVerdict = shadowDiffResult.verdict || (sdMismatches === 0 ? 'ZERO DRIFT CONFIRMED' : 'DRIFT DETECTED');
      const sdInputHash = shadowDiffResult.input_file_hash || shadowDiffResult.input_fingerprint || 'N/A';
      const sdOutputHash = shadowDiffResult.output_file_hash || shadowDiffResult.output_fingerprint || 'N/A';

      // Summary stats
      h.addParagraph(`Verdict: ${sdVerdict}`);
      h.addParagraph(`Records: ${sdTotal} total, ${sdMatches} matches, ${sdMismatches} mismatches`);
      h.addParagraph(`S0C7 Abends: ${shadowDiffResult.s0c7_abends || 0}`);
      h.setY(h.getY() + 2);

      // Mismatch table
      const mismatchLog = shadowDiffResult.mismatch_log || shadowDiffResult.mismatch_details || [];
      if (mismatchLog.length > 0) {
        h.checkPageBreak(12);
        doc.setFontSize(8);
        doc.setFont('helvetica', 'bold');
        doc.setTextColor(80);
        doc.text('MISMATCH LOG', h.margin, h.getY());
        h.setY(h.getY() + 5);

        const mmRows = mismatchLog.map((m) => ({
          record: String(m.record ?? ''),
          field: m.field || '',
          aletheia: m.aletheia_value || '',
          mainframe: m.mainframe_value || '',
          diff: m.difference || '',
        }));

        drawTable(h,
          [
            { key: 'record', label: 'Record', weight: 1.5 },
            { key: 'field', label: 'Field', weight: 3 },
            { key: 'aletheia', label: 'Aletheia', weight: 2.5 },
            { key: 'mainframe', label: 'Mainframe', weight: 2.5 },
            { key: 'diff', label: 'Difference', weight: 2 },
          ],
          mmRows,
        );
      }

      // Drift diagnoses
      const diagnoses = shadowDiffResult.diagnosed_mismatches || shadowDiffResult.drift_diagnoses || [];
      if (diagnoses.length > 0) {
        h.checkPageBreak(12);
        doc.setFontSize(8);
        doc.setFont('helvetica', 'bold');
        doc.setTextColor(80);
        doc.text('ROOT CAUSE ANALYSIS', h.margin, h.getY());
        h.setY(h.getY() + 5);

        const diagRows = diagnoses.map((d) => ({
          record: String(d.record ?? ''),
          field: d.field || '',
          root_cause: d.root_cause || d.diagnosis || '',
          suggested_fix: d.suggested_fix || d.fix || '',
        }));

        drawTable(h,
          [
            { key: 'record', label: 'Record', weight: 1.5 },
            { key: 'field', label: 'Field', weight: 2.5 },
            { key: 'root_cause', label: 'Root Cause', weight: 4 },
            { key: 'suggested_fix', label: 'Suggested Fix', weight: 4 },
          ],
          diagRows,
        );
      }

      // Cryptographic fingerprints
      h.checkPageBreak(20);
      doc.setFontSize(8);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(80);
      doc.text('CRYPTOGRAPHIC FINGERPRINTS', h.margin, h.getY());
      h.setY(h.getY() + 5);

      doc.setFont('courier', 'normal');
      doc.setFontSize(7);
      doc.setTextColor(40);
      [
        `Input file:   ${sdInputHash}`,
        `Output file:  ${sdOutputHash}`,
      ].forEach(line => {
        h.checkPageBreak(5);
        doc.text(line, h.margin + 2, h.getY());
        h.setY(h.getY() + 3.5);
      });
      h.setY(h.getY() + 4);
    }
  }

  // ── DEAD CODE SUMMARY (executive mode) ──
  if (isExec && result?.dead_code?.total_paragraphs > 0) {
    const dc = result.dead_code;
    const deadCount = dc.unreachable_paragraphs?.length || 0;
    h.addHeading(`${section}. DEAD CODE ANALYSIS`, 1);
    section++;
    h.addParagraph(
      deadCount > 0
        ? `${deadCount} of ${dc.total_paragraphs} paragraphs (${dc.dead_percentage}%) identified as unreachable \u2014 candidates for removal before migration.`
        : `All ${dc.total_paragraphs} paragraphs are reachable \u2014 no dead code detected.`
    );
    if (dc.has_alter) {
      h.addParagraph('Note: ALTER statement detected \u2014 results are approximate.');
    }
  }

  // ── VERIFICATION CHECKLIST (both modes) ──

  if (checklist.length > 0) {
    h.addHeading(`${section}. VERIFICATION CHECKLIST`, 1);
    section++;

    const checkRows = checklist.map((c) => ({
      item: c.item || '',
      status: c.status || '--',
      note: c.note || '',
      _colorFn: (d, cols, ry, cellLines, fs) => {
        cols.forEach((co, ci) => {
          if (co.key === 'status') {
            const s = c.status;
            if (s === 'PASS') d.setTextColor(22, 163, 74);
            else if (s === 'FAIL') d.setTextColor(220, 38, 38);
            else if (s === 'WARN') d.setTextColor(217, 119, 6);
            else d.setTextColor(50);
            d.setFont('courier', 'bold');
          } else {
            d.setTextColor(50);
            d.setFont('helvetica', 'normal');
          }
          cellLines[ci].forEach((line, li) => {
            d.text(line, co.x + 2, ry + li * (fs * 0.42));
          });
        });
      },
    }));

    drawTable(h,
      [
        { key: 'item', label: 'Item', weight: 5 },
        { key: 'status', label: 'Status', weight: 1.5 },
        { key: 'note', label: 'Notes', weight: 4 },
      ],
      checkRows,
    );
  }

  // ── UNCERTAINTIES (both modes) ──

  if (humanReview.length > 0) {
    h.addHeading(`${section}. UNCERTAINTIES & ASSUMPTIONS`, 1);
    section++;
    humanReview.forEach((u) => {
      h.checkPageBreak(25);
      h.addHeading(`[${u.severity || 'Unknown'}]`, 3);
      h.addParagraph(u.item || '', 8);
      if (u.reason) h.addParagraph(`Risk: ${u.reason}`, 8);
      h.setY(h.getY() + 3);
    });
  }

  // ── CRYPTOGRAPHIC VERIFICATION (engineer only, if signature present) ──

  if (!isExec && result.signature) {
    const sig = result.signature;
    const chain = sig.verification_chain || {};

    h.addHeading(`${section}. CRYPTOGRAPHIC VERIFICATION`, 1);
    section++;

    h.checkPageBreak(60);

    doc.setFontSize(8);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(80);
    doc.text('VERIFICATION CHAIN', h.margin, h.getY());
    h.setY(h.getY() + 5);

    doc.setFont('courier', 'normal');
    doc.setFontSize(7);
    doc.setTextColor(40);
    [
      `COBOL Source:   ${chain.cobol_hash || 'N/A'}`,
      `Python Model:   ${chain.python_hash || 'N/A'}`,
      `Report Data:    ${chain.report_hash || 'N/A'}`,
      `Chain Hash:     ${chain.chain_hash || 'N/A'}`,
    ].forEach(line => {
      h.checkPageBreak(5);
      doc.text(line, h.margin + 2, h.getY());
      h.setY(h.getY() + 3.5);
    });
    h.setY(h.getY() + 3);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(8);
    doc.setTextColor(80);
    doc.text('DIGITAL SIGNATURE', h.margin, h.getY());
    h.setY(h.getY() + 5);

    doc.setFont('courier', 'normal');
    doc.setFontSize(7);
    doc.setTextColor(40);
    const sigStr = sig.signature || '';
    const sigDisplay = sigStr.length > 64
      ? sigStr.substring(0, 32) + '...' + sigStr.substring(sigStr.length - 32)
      : sigStr;
    [
      `Algorithm:      ${sig.algorithm || 'RSA-PSS-SHA256'}`,
      `Fingerprint:    ${sig.public_key_fingerprint || 'N/A'}`,
      `Signature:      ${sigDisplay}`,
      `Signed At:      ${chain.timestamp || 'N/A'}`,
    ].forEach(line => {
      h.checkPageBreak(5);
      doc.text(line, h.margin + 2, h.getY());
      h.setY(h.getY() + 3.5);
    });
    h.setY(h.getY() + 4);

    h.checkPageBreak(20);
    const boxY = h.getY();
    doc.setDrawColor(...NAVY);
    doc.setLineDashPattern([2, 2], 0);
    doc.rect(h.margin, boxY, h.contentWidth, 14);
    doc.setLineDashPattern([], 0);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(7);
    doc.setTextColor(...NAVY);
    doc.text('CHAIN HASH SEAL', h.margin + 4, boxY + 5);
    doc.setFont('courier', 'bold');
    doc.setFontSize(8);
    doc.text(chain.chain_hash || 'N/A', h.margin + 4, boxY + 10);
    h.setY(boxY + 18);
  }

  // Headers, footers, page numbers
  const modeTag = isExec ? 'EXECUTIVE' : 'ENGINEER';
  h.addPageHeadersAndFooters(`ALETHEIA BEYOND -- FORENSIC REPORT (${modeTag})`);

  // Save
  const sanitized = (fileName || 'analysis').replace(/[^a-z0-9]/gi, '_');
  const tag = isExec ? 'exec' : 'eng';
  doc.save(`forensic_${tag}_${sanitized}_${Date.now()}.pdf`);
};

// ════════════════════════════════════════════════════════════════════
// 2. VAULT EXPORT -- Multi-record summary
// ════════════════════════════════════════════════════════════════════

export const generateVaultExportPDF = (records) => {
  if (!records || records.length === 0) return;

  const doc = new jsPDF({ orientation: 'landscape' });
  const h = createHelpers(doc);
  const pw = doc.internal.pageSize.getWidth();
  const ph = doc.internal.pageSize.getHeight();

  // ── COVER PAGE ──

  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(...GRAY);
  doc.text('A L E T H E I A    B E Y O N D', pw / 2, 40, { align: 'center' });

  doc.setDrawColor(...LIGHT_GRAY);
  doc.line(pw / 2 - 40, 45, pw / 2 + 40, 45);

  doc.setFontSize(24);
  doc.setFont('helvetica', 'bold');
  doc.setTextColor(...NAVY);
  doc.text('VAULT EXPORT', pw / 2, 70, { align: 'center' });

  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(80);
  const exportDate = new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
  doc.text(`${records.length} verification record${records.length === 1 ? '' : 's'} -- ${exportDate}`, pw / 2, 90, { align: 'center' });

  doc.setFontSize(8);
  doc.setTextColor(...GRAY);
  doc.text('CONFIDENTIAL -- FOR AUTHORIZED PERSONNEL ONLY', pw / 2, ph - 20, { align: 'center' });

  // ── TABLE PAGE(S) ──

  doc.addPage();
  const margin = 15;
  const rowHeight = 8;
  let y = margin + 8;

  // Column definitions
  const cols = [
    { label: 'ID', x: margin, w: 12 },
    { label: 'Date', x: margin + 14, w: 45 },
    { label: 'Filename', x: margin + 62, w: 55 },
    { label: 'Status', x: margin + 120, w: 35 },
    { label: 'Paras', x: margin + 158, w: 16 },
    { label: 'Vars', x: margin + 176, w: 16 },
    { label: 'COMP-3', x: margin + 194, w: 18 },
    { label: 'Safe', x: margin + 214, w: 14 },
    { label: 'Warn', x: margin + 230, w: 14 },
    { label: 'Crit', x: margin + 246, w: 14 },
    { label: 'Checklist', x: margin + 262, w: 20 },
  ];

  const drawHeader = () => {
    doc.setFillColor(245, 246, 248);
    doc.rect(margin, y - 5, pw - margin * 2, rowHeight, 'F');
    doc.setFontSize(7);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(80);
    cols.forEach(c => doc.text(c.label, c.x, y));
    y += rowHeight;
    doc.setDrawColor(...LIGHT_GRAY);
    doc.line(margin, y - 5, pw - margin, y - 5);
  };

  drawHeader();

  const formatDate = (iso) => {
    if (!iso) return '--';
    const d = new Date(iso);
    return new Intl.DateTimeFormat('en-GB', {
      day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'UTC',
    }).format(d);
  };

  records.forEach((r, i) => {
    if (y + rowHeight > ph - 20) {
      doc.addPage();
      y = margin + 8;
      drawHeader();
    }

    // Alternating row background
    if (i % 2 === 0) {
      doc.setFillColor(250, 250, 252);
      doc.rect(margin, y - 5, pw - margin * 2, rowHeight, 'F');
    }

    doc.setFontSize(7);
    doc.setFont('courier', 'normal');
    doc.setTextColor(60);

    doc.text(String(r.id || ''), cols[0].x, y);
    doc.text(formatDate(r.timestamp), cols[1].x, y);

    doc.setFont('helvetica', 'normal');
    const fname = (r.filename || '').length > 25 ? r.filename.substring(0, 22) + '...' : (r.filename || '');
    doc.text(fname, cols[2].x, y);

    // Status with color
    const isVerified = r.verification_status === 'VERIFIED';
    doc.setTextColor(isVerified ? 46 : 217, isVerified ? 125 : 119, isVerified ? 50 : 6);
    doc.setFont('helvetica', 'bold');
    doc.text(isVerified ? 'VERIFIED' : 'MANUAL REVIEW', cols[3].x, y);

    doc.setTextColor(60);
    doc.setFont('courier', 'normal');
    doc.text(String(r.paragraphs_count ?? 0), cols[4].x, y);
    doc.text(String(r.variables_count ?? 0), cols[5].x, y);
    doc.text(String(r.comp3_count ?? 0), cols[6].x, y);

    // Colored risk numbers
    doc.setTextColor(22, 163, 74);
    doc.text(String(r.arithmetic_safe ?? 0), cols[7].x, y);
    doc.setTextColor(217, 119, 6);
    doc.text(String(r.arithmetic_warn ?? 0), cols[8].x, y);
    doc.setTextColor(220, 38, 38);
    doc.text(String(r.arithmetic_critical ?? 0), cols[9].x, y);

    doc.setTextColor(60);
    doc.text(`${r.checklist_pass ?? 0}/${r.checklist_total ?? 0}`, cols[10].x, y);

    y += rowHeight;
  });

  // Headers and footers
  const totalPages = doc.getNumberOfPages();
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i);
    if (i > 1) {
      doc.setFontSize(7);
      doc.setTextColor(...GRAY);
      doc.setFont('helvetica', 'normal');
      doc.text('ALETHEIA BEYOND -- VAULT EXPORT', margin, 10);
      doc.text(`Page ${i} of ${totalPages}`, pw - margin, 10, { align: 'right' });
      doc.setDrawColor(...LIGHT_GRAY);
      doc.line(margin, 12, pw - margin, 12);
    }
    doc.setFontSize(7);
    doc.setTextColor(...GRAY);
    doc.text('CONFIDENTIAL', pw / 2, ph - 6, { align: 'center' });
  }

  doc.save(`aletheia_vault_export_${Date.now()}.pdf`);
};

export default generateForensicPDF;
