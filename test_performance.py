"""
ALETHEIA PERFORMANCE BENCHMARKS

Measures throughput of the full pipeline against the real corpus.
Run: python test_performance.py

Uses time.perf_counter() for real-world wall-clock timing.
"""

import os
import sys
import time
from datetime import datetime
from decimal import Decimal
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT))
os.environ["USE_IN_MEMORY_DB"] = "1"

from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module
from shadow_diff import compare_outputs

CORPUS_DIR = PROJECT_ROOT / "corpus"


# ── Helpers ──────────────────────────────────────────────────────


def load_corpus():
    """Load all .cbl files from corpus/. Returns [(filename, source, line_count)]."""
    programs = []
    for cbl in sorted(CORPUS_DIR.glob("*.cbl")):
        source = cbl.read_text(encoding="utf-8")
        programs.append((cbl.name, source, source.count("\n") + 1))
    return programs


def synthetic_records(count, fields):
    """Generate list of synthetic record dicts for comparison benchmarks."""
    records = []
    for i in range(count):
        record = {f: str(Decimal(str(100 + i * 0.01))) for f in fields}
        records.append(record)
    return records


def fmt_rate(value, unit=""):
    """Format a rate number with comma separators."""
    if value >= 1_000_000:
        return f"{value:,.0f} {unit}".strip()
    elif value >= 1000:
        return f"{value:,.0f} {unit}".strip()
    else:
        return f"{value:.1f} {unit}".strip()


# ── Benchmarks ───────────────────────────────────────────────────


def bench_analyze(corpus):
    """Benchmark analyze_cobol() on all corpus programs."""
    results = []
    total_start = time.perf_counter()

    for filename, source, loc in corpus:
        start = time.perf_counter()
        analysis = analyze_cobol(source)
        elapsed = time.perf_counter() - start
        results.append((filename, analysis, elapsed, loc))

    total_elapsed = time.perf_counter() - total_start
    total_loc = sum(r[3] for r in results)
    return results, total_elapsed, total_loc


def bench_generate(analyze_results):
    """Benchmark generate_python_module() on all analysis results."""
    gen_results = []
    total_start = time.perf_counter()

    for filename, analysis, _, loc in analyze_results:
        if not analysis.get("success"):
            continue
        start = time.perf_counter()
        result = generate_python_module(analysis)
        elapsed = time.perf_counter() - start
        gen_results.append((filename, result, elapsed))

    total_elapsed = time.perf_counter() - total_start
    return gen_results, total_elapsed


def bench_pipeline(corpus):
    """Benchmark full analyze+generate pipeline."""
    total_start = time.perf_counter()
    success_count = 0

    for filename, source, loc in corpus:
        analysis = analyze_cobol(source)
        if analysis.get("success"):
            generate_python_module(analysis)
            success_count += 1

    total_elapsed = time.perf_counter() - total_start
    return success_count, total_elapsed


def bench_compare(sizes):
    """Benchmark compare_outputs() at different record counts."""
    fields = ["ws_field_a", "ws_field_b", "ws_field_c", "ws_field_d", "ws_field_e"]
    results = []

    for count in sizes:
        # Build matching records (best-case: 100% match)
        aletheia = synthetic_records(count, fields)
        mainframe = synthetic_records(count, fields)

        start = time.perf_counter()
        compare_outputs(aletheia, mainframe, fields)
        elapsed = time.perf_counter() - start

        results.append((count, elapsed))

    return results


# ── Report ───────────────────────────────────────────────────────


def generate_report(stats):
    """Format and print the benchmark report."""
    lines = []
    lines.append("")
    lines.append("=" * 64)
    lines.append("  ALETHEIA PERFORMANCE BENCHMARKS")
    lines.append(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append("=" * 64)
    lines.append("")

    # Parser
    a = stats["analyze"]
    lines.append(f"  Parser:      {a['programs']} programs, {a['loc']:,} LOC "
                 f"in {a['elapsed']:.2f}s")
    lines.append(f"               {fmt_rate(a['loc_per_sec'], 'LOC/sec')} | "
                 f"{a['ms_per_program']:.0f} ms/program")
    lines.append("")

    # Generator
    g = stats["generate"]
    lines.append(f"  Generator:   {g['programs']} programs "
                 f"in {g['elapsed']:.2f}s")
    lines.append(f"               {fmt_rate(g['programs_per_sec'], 'programs/sec')} | "
                 f"{g['ms_per_program']:.0f} ms/program")
    lines.append("")

    # Pipeline
    p = stats["pipeline"]
    lines.append(f"  Pipeline:    {p['programs']} programs "
                 f"in {p['elapsed']:.2f}s")
    lines.append(f"               {fmt_rate(p['programs_per_sec'], 'programs/sec')} | "
                 f"{p['ms_per_program']:.0f} ms/program")
    lines.append("")

    # Comparator
    lines.append("  Comparator:")
    for c in stats["compare"]:
        rate = fmt_rate(c["records_per_sec"], "records/sec")
        lines.append(f"    {c['count']:>7,} records in {c['elapsed']:.3f}s — {rate}")
    lines.append("")

    lines.append("=" * 64)

    report = "\n".join(lines)
    print(report)
    return report


# ── Main ─────────────────────────────────────────────────────────


def main():
    corpus = load_corpus()
    if not corpus:
        print("No corpus programs found in corpus/")
        sys.exit(1)

    print(f"\nLoaded {len(corpus)} corpus programs "
          f"({sum(c[2] for c in corpus):,} total LOC)")

    # 1. Parser benchmark
    print("\n  Benchmarking parser...", end="", flush=True)
    analyze_results, analyze_elapsed, total_loc = bench_analyze(corpus)
    print(f" {analyze_elapsed:.1f}s")

    # 2. Generator benchmark
    print("  Benchmarking generator...", end="", flush=True)
    gen_results, gen_elapsed = bench_generate(analyze_results)
    print(f" {gen_elapsed:.1f}s")

    # 3. Pipeline benchmark (separate run for clean timing)
    print("  Benchmarking pipeline...", end="", flush=True)
    pipeline_count, pipeline_elapsed = bench_pipeline(corpus)
    print(f" {pipeline_elapsed:.1f}s")

    # 4. Comparator benchmark
    sizes = [1_000, 10_000, 100_000]
    print("  Benchmarking comparator...", end="", flush=True)
    compare_results = bench_compare(sizes)
    print(f" done")

    # Build stats
    stats = {
        "analyze": {
            "programs": len(corpus),
            "loc": total_loc,
            "elapsed": analyze_elapsed,
            "loc_per_sec": total_loc / analyze_elapsed if analyze_elapsed > 0 else 0,
            "ms_per_program": (analyze_elapsed / len(corpus)) * 1000,
        },
        "generate": {
            "programs": len(gen_results),
            "elapsed": gen_elapsed,
            "programs_per_sec": len(gen_results) / gen_elapsed if gen_elapsed > 0 else 0,
            "ms_per_program": (gen_elapsed / len(gen_results)) * 1000 if gen_results else 0,
        },
        "pipeline": {
            "programs": pipeline_count,
            "elapsed": pipeline_elapsed,
            "programs_per_sec": pipeline_count / pipeline_elapsed if pipeline_elapsed > 0 else 0,
            "ms_per_program": (pipeline_elapsed / pipeline_count) * 1000 if pipeline_count > 0 else 0,
        },
        "compare": [
            {
                "count": count,
                "elapsed": elapsed,
                "records_per_sec": count / elapsed if elapsed > 0 else 0,
            }
            for count, elapsed in compare_results
        ],
    }

    # Generate report
    report = generate_report(stats)

    # Write to file
    report_path = PROJECT_ROOT / "performance_report.md"
    with open(report_path, "w") as f:
        f.write(f"# Aletheia Performance Report\n\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
        f.write("```\n")
        f.write(report)
        f.write("\n```\n")
    print(f"\n  Report saved: {report_path}")


if __name__ == "__main__":
    main()
