/**
 * CobolHighlighter — regex-based COBOL syntax highlighting.
 * Zero dependencies. Drop-in replacement for <pre><code>{text}</code></pre>.
 *
 * Props:
 *   code      — string of COBOL source
 *   className — forwarded to outer <pre>
 *   style     — forwarded to outer <pre>
 */

const COLORS = {
    division: '#1B2A4A',   // navy bold — divisions, sections
    verb:     '#16A34A',   // green     — COBOL verbs
    literal:  '#D97706',   // amber     — strings, numbers
    comment:  '#9CA3AF',   // gray      — comments
    pic:      '#7C3AED',   // purple    — PIC clauses, COMP
};

// Multi-word keywords must come before single-word to match first
const MULTI_WORD_VERBS = [
    'STOP RUN', 'EXIT PROGRAM', 'GO TO', 'END-IF', 'END-EVALUATE',
    'END-PERFORM', 'END-STRING', 'END-UNSTRING', 'END-SEARCH',
    'END-READ', 'END-WRITE', 'END-COMPUTE', 'END-ADD', 'END-SUBTRACT',
    'END-MULTIPLY', 'END-DIVIDE', 'END-CALL', 'NOT AT END',
    'NOT ON SIZE ERROR', 'ON SIZE ERROR', 'AT END',
    'WHEN OTHER',
];

const SINGLE_VERBS = [
    'MOVE', 'COMPUTE', 'ADD', 'SUBTRACT', 'MULTIPLY', 'DIVIDE',
    'PERFORM', 'IF', 'ELSE', 'EVALUATE', 'WHEN', 'DISPLAY',
    'STRING', 'UNSTRING', 'INSPECT', 'READ', 'WRITE', 'OPEN',
    'CLOSE', 'CALL', 'GOBACK', 'INITIALIZE', 'SET', 'SEARCH',
    'SORT', 'ACCEPT', 'THEN', 'THRU', 'THROUGH', 'VARYING',
    'UNTIL', 'TIMES', 'GIVING', 'REMAINDER', 'RETURNING',
    'ASCENDING', 'DESCENDING', 'DELIMITED', 'INTO', 'FROM',
    'BY', 'TO', 'ROUNDED', 'WITH', 'REPLACING', 'TALLYING',
    'CORRESPONDING', 'REDEFINES', 'COPY', 'USING',
];

const DIVISIONS = [
    'IDENTIFICATION DIVISION', 'ENVIRONMENT DIVISION',
    'DATA DIVISION', 'PROCEDURE DIVISION',
    'WORKING-STORAGE SECTION', 'FILE SECTION', 'LINKAGE SECTION',
    'FILE-CONTROL', 'INPUT-OUTPUT SECTION', 'CONFIGURATION SECTION',
    'DIVISION', 'SECTION',
];

const COMP_KEYWORDS = ['COMP-3', 'COMP-4', 'COMP-5', 'COMP'];

// Build the master regex — order matters: strings > PIC > divisions > multi-word verbs > single verbs > numbers
function buildTokenRegex() {
    const parts = [];

    // 1. String literals (single or double quoted)
    parts.push('(?<str>"[^"]*"|\'[^\']*\')');

    // 2. PIC clauses: PIC followed by the picture string (e.g. S9(5)V99)
    parts.push('(?<pic>\\bPIC\\s+[SXA9(.)V\\-+Z*/,$BCDRP0 ]+)');

    // 3. COMP keywords (before divisions to avoid partial matches)
    parts.push('(?<comp>\\b(?:' + COMP_KEYWORDS.join('|') + ')\\b)');

    // 4. Divisions/sections (multi-word, must come before single words)
    const divEscaped = DIVISIONS.map(d => d.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    parts.push('(?<div>\\b(?:' + divEscaped.join('|') + ')\\b\\.?)');

    // 5. Multi-word verbs
    const mwEscaped = MULTI_WORD_VERBS.map(v => v.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    parts.push('(?<mverb>\\b(?:' + mwEscaped.join('|') + ')\\b)');

    // 6. Single-word verbs
    parts.push('(?<verb>\\b(?:' + SINGLE_VERBS.join('|') + ')\\b)');

    // 7. Numeric literals (standalone numbers, including decimals)
    parts.push('(?<num>\\b\\d+\\.?\\d*\\b)');

    // 8. PROGRAM-ID value (the program name after PROGRAM-ID.)
    parts.push('(?<progid>\\bPROGRAM-ID\\b)');

    return new RegExp(parts.join('|'), 'gi');
}

const TOKEN_RE = buildTokenRegex();

function tokenizeLine(line) {
    const result = [];
    let lastIndex = 0;

    // Reset regex state
    TOKEN_RE.lastIndex = 0;
    let match;

    while ((match = TOKEN_RE.exec(line)) !== null) {
        // Push plain text before this match
        if (match.index > lastIndex) {
            result.push(line.slice(lastIndex, match.index));
        }

        const text = match[0];

        if (match.groups.str) {
            result.push(<span key={match.index} style={{ color: COLORS.literal }}>{text}</span>);
        } else if (match.groups.pic) {
            result.push(<span key={match.index} style={{ color: COLORS.pic }}>{text}</span>);
        } else if (match.groups.comp) {
            result.push(<span key={match.index} style={{ color: COLORS.pic }}>{text}</span>);
        } else if (match.groups.div) {
            result.push(<span key={match.index} style={{ color: COLORS.division, fontWeight: 700 }}>{text}</span>);
        } else if (match.groups.mverb) {
            result.push(<span key={match.index} style={{ color: COLORS.verb }}>{text}</span>);
        } else if (match.groups.verb) {
            result.push(<span key={match.index} style={{ color: COLORS.verb }}>{text}</span>);
        } else if (match.groups.num) {
            result.push(<span key={match.index} style={{ color: COLORS.literal }}>{text}</span>);
        } else if (match.groups.progid) {
            result.push(<span key={match.index} style={{ color: COLORS.division, fontWeight: 700 }}>{text}</span>);
        } else {
            result.push(text);
        }

        lastIndex = match.index + text.length;
    }

    // Trailing plain text
    if (lastIndex < line.length) {
        result.push(line.slice(lastIndex));
    }

    return result;
}

function highlightCobol(code) {
    if (!code) return null;
    return code.split('\n').map((line, i, arr) => {
        // Comment: column 7 asterisk (fixed-format COBOL)
        const isComment = line.length > 6 && line[6] === '*';
        if (isComment) {
            return (
                <span key={i} style={{ color: COLORS.comment, fontStyle: 'italic' }}>
                    {line}{i < arr.length - 1 ? '\n' : ''}
                </span>
            );
        }
        return (
            <span key={i}>
                {tokenizeLine(line)}{i < arr.length - 1 ? '\n' : ''}
            </span>
        );
    });
}

export default function CobolHighlighter({ code, className = '', style = {} }) {
    return (
        <pre className={className} style={style}>
            <code>{highlightCobol(code)}</code>
        </pre>
    );
}
