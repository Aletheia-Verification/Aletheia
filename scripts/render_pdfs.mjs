import { readFileSync, writeFileSync, unlinkSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, '..');
const demoDir = resolve(rootDir, 'demo_data');

const engineData = JSON.parse(readFileSync(resolve(demoDir, '_engine_data.json'), 'utf8'));
const shadowData = JSON.parse(readFileSync(resolve(demoDir, '_shadow_diff_data.json'), 'utf8'));
const cobolSource = readFileSync(resolve(demoDir, '_cobol_source.txt'), 'utf8');

const jspdfNodePath = pathToFileURL(resolve(rootDir, 'frontend/node_modules/jspdf/dist/jspdf.node.js')).href;
const jspdfMod = await import(jspdfNodePath);
const jsPDFConstructor = jspdfMod.jsPDF;

let nextSavePath = null;
jsPDFConstructor.prototype.save = function(filename) {
  const target = nextSavePath || resolve(demoDir, filename);
  const buf = Buffer.from(this.output('arraybuffer'));
  writeFileSync(target, buf);
  console.log('  Wrote: ' + target + ' (' + buf.length + ' bytes)');
  nextSavePath = null;
};

const pdfExportSrc = readFileSync(resolve(rootDir, 'frontend/src/utils/pdfExport.js'), 'utf8');
const shadowPdfSrc = readFileSync(resolve(rootDir, 'frontend/src/utils/shadowDiffPdf.js'), 'utf8');

const jspdfImportLine = `import _jspdfMod from '${jspdfNodePath}';
const jsPDF = _jspdfMod.jsPDF;`;

const patchedExport = pdfExportSrc.replace(
  "import jsPDF from 'jspdf';",
  jspdfImportLine
);
const tmpExportPath = resolve(__dirname, '_tmp_pdfExport.mjs');
writeFileSync(tmpExportPath, patchedExport);

const patchedShadow = shadowPdfSrc.replace(
  "import jsPDF from 'jspdf';",
  jspdfImportLine
);
const tmpShadowPath = resolve(__dirname, '_tmp_shadowDiffPdf.mjs');
writeFileSync(tmpShadowPath, patchedShadow);

const { generateForensicPDF } = await import(pathToFileURL(tmpExportPath).href);
const { generateShadowDiffPDF } = await import(pathToFileURL(tmpShadowPath).href);

console.log('Generating engine_executive.pdf...');
nextSavePath = resolve(demoDir, 'engine_executive.pdf');
generateForensicPDF(engineData, cobolSource, 'DEMO_LOAN_INTEREST.cbl', 'executive');

console.log('Generating engine_engineer.pdf...');
nextSavePath = resolve(demoDir, 'engine_engineer.pdf');
generateForensicPDF(engineData, cobolSource, 'DEMO_LOAN_INTEREST.cbl', 'engineer');

console.log('Generating shadowdiff_executive.pdf...');
nextSavePath = resolve(demoDir, 'shadowdiff_executive.pdf');
generateShadowDiffPDF(shadowData, 'executive');

console.log('Generating shadowdiff_engineer.pdf...');
nextSavePath = resolve(demoDir, 'shadowdiff_engineer.pdf');
generateShadowDiffPDF(shadowData, 'engineer');

try { unlinkSync(tmpExportPath); } catch {}
try { unlinkSync(tmpShadowPath); } catch {}

console.log('Done. All 4 PDFs saved to demo_data/');
