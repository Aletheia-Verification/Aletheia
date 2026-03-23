"""Tests for jcl_parser.py — IBM JCL Parser → Job Step DAG."""

import pytest

from jcl_parser import parse_jcl


# ── Test 1: Single step job ───────────────────────────────────────

class TestSingleStepJob:
    def test_single_step(self):
        jcl = """\
//MYJOB   JOB (ACCT),'TEST JOB',CLASS=A
//STEP01  EXEC PGM=IEFBR14
//INFILE  DD DSN=MY.INPUT.FILE,DISP=SHR
//OUTFILE DD DSN=MY.OUTPUT.FILE,DISP=(NEW,CATLG,DELETE)
"""
        dag = parse_jcl(jcl)

        assert dag.job_name == "MYJOB"
        assert len(dag.steps) == 1

        step = dag.steps[0]
        assert step.name == "STEP01"
        assert step.program == "IEFBR14"
        assert step.proc is None
        assert len(step.dd_statements) == 2

        dd_names = {dd.name for dd in step.dd_statements}
        assert dd_names == {"INFILE", "OUTFILE"}


# ── Test 2: Multi-step with dataset handoff ───────────────────────

class TestMultiStepHandoff:
    def test_dataset_handoff(self):
        jcl = """\
//BATCH1  JOB (ACCT),'BATCH RUN'
//STEP01  EXEC PGM=EXTRACT
//OUTPUT  DD DSN=WORK.TEMP.DATA,DISP=(NEW,CATLG,DELETE)
//STEP02  EXEC PGM=PROCESS
//INPUT   DD DSN=WORK.TEMP.DATA,DISP=SHR
//REPORT  DD SYSOUT=A
//STEP03  EXEC PGM=CLEANUP
//DELFILE DD DSN=WORK.TEMP.DATA,DISP=(OLD,DELETE)
"""
        dag = parse_jcl(jcl)

        assert len(dag.steps) == 3
        assert dag.steps[0].program == "EXTRACT"
        assert dag.steps[1].program == "PROCESS"
        assert dag.steps[2].program == "CLEANUP"

        # Dataset referenced by multiple steps
        assert "WORK.TEMP.DATA" in dag.datasets
        assert len(dag.datasets["WORK.TEMP.DATA"]) == 3

        # Sequential edges
        assert ("STEP01", "STEP02") in dag.dependencies
        assert ("STEP02", "STEP03") in dag.dependencies

        # SYSOUT DD
        report_dd = [dd for dd in dag.steps[1].dd_statements if dd.name == "REPORT"][0]
        assert report_dd.sysout == "A"
        assert report_dd.dsn is None


# ── Test 3: COND= parameter detection ────────────────────────────

class TestCondParameter:
    def test_cond_detection(self):
        jcl = """\
//CONDJOB JOB (ACCT),'COND TEST'
//STEP01  EXEC PGM=PROG1
//STEP02  EXEC PGM=PROG2,COND=(4,LT,STEP01)
//STEP03  EXEC PGM=PROG3
"""
        dag = parse_jcl(jcl)

        assert dag.steps[0].cond is None
        assert dag.steps[1].cond == "(4,LT,STEP01)"
        assert dag.steps[2].cond is None


# ── Test 4: Inline SYSIN data ─────────────────────────────────────

class TestInlineSysin:
    def test_instream_data(self):
        jcl = """\
//SYSJOB  JOB (ACCT),'SYSIN TEST'
//STEP01  EXEC PGM=SORT
//SYSIN   DD *
  SORT FIELDS=(1,10,CH,A)
  RECORD TYPE=F,LENGTH=80
  END
/*
//SYSOUT  DD SYSOUT=A
"""
        dag = parse_jcl(jcl)

        assert len(dag.steps) == 1
        step = dag.steps[0]

        sysin_dd = [dd for dd in step.dd_statements if dd.name == "SYSIN"][0]
        assert sysin_dd.is_instream is True
        assert "SORT FIELDS" in sysin_dd.instream_data
        assert "RECORD TYPE" in sysin_dd.instream_data
        assert "END" in sysin_dd.instream_data
        assert sysin_dd.instream_data.count("\n") == 2  # 3 lines, 2 newlines

        # SYSOUT DD should also be parsed (after the /* delimiter)
        sysout_dd = [dd for dd in step.dd_statements if dd.name == "SYSOUT"][0]
        assert sysout_dd.sysout == "A"


# ── Test 5: Catalogued procedure (PROC) stub detection ────────────

class TestProcStub:
    def test_explicit_proc(self):
        jcl = """\
//PROCJOB JOB (ACCT),'PROC TEST'
//STEP01  EXEC PROC=SORTPROC
"""
        dag = parse_jcl(jcl)

        assert dag.steps[0].proc == "SORTPROC"
        assert dag.steps[0].program is None

    def test_bare_proc_name(self):
        """Bare name without PGM= or PROC= → treated as proc."""
        jcl = """\
//PROCJOB JOB (ACCT),'BARE PROC'
//STEP01  EXEC MYPROC
"""
        dag = parse_jcl(jcl)

        assert dag.steps[0].proc == "MYPROC"
        assert dag.steps[0].program is None

    def test_pgm_not_misdetected_as_proc(self):
        """FIX 1: PGM= must not be misdetected as a proc name."""
        jcl = """\
//PGMJOB  JOB (ACCT),'PGM TEST'
//STEP01  EXEC PGM=IEFBR14,COND=(0,NE)
"""
        dag = parse_jcl(jcl)

        assert dag.steps[0].program == "IEFBR14"
        assert dag.steps[0].proc is None


# ── Test 6: Missing DSN edge case ─────────────────────────────────

class TestMissingDSN:
    def test_dummy_dd(self):
        jcl = """\
//DUMMYJOB JOB (ACCT),'DUMMY TEST'
//STEP01   EXEC PGM=UTIL
//NULLFILE DD DUMMY
//SYSPRINT DD SYSOUT=*
"""
        dag = parse_jcl(jcl)

        null_dd = [dd for dd in dag.steps[0].dd_statements if dd.name == "NULLFILE"][0]
        assert null_dd.dsn is None
        assert null_dd.disp is None

        sysprint_dd = [dd for dd in dag.steps[0].dd_statements if dd.name == "SYSPRINT"][0]
        assert sysprint_dd.sysout == "*"
        assert sysprint_dd.dsn is None


# ── Test 7: DISP=(NEW,CATLG,DELETE) parsing ───────────────────────

class TestDispParsing:
    def test_full_disp(self):
        jcl = """\
//DISPJOB JOB (ACCT),'DISP TEST'
//STEP01  EXEC PGM=CREATE
//NEWFILE DD DSN=MY.NEW.FILE,DISP=(NEW,CATLG,DELETE)
"""
        dag = parse_jcl(jcl)
        dd = dag.steps[0].dd_statements[0]
        assert dd.disp == ("NEW", "CATLG", "DELETE")

    def test_simple_disp(self):
        jcl = """\
//DISPJOB JOB (ACCT),'DISP SHR'
//STEP01  EXEC PGM=READ
//INFILE  DD DSN=MY.EXIST.FILE,DISP=SHR
"""
        dag = parse_jcl(jcl)
        dd = dag.steps[0].dd_statements[0]
        assert dd.disp == ("SHR", "", "")

    def test_mod_disp_creates_edge(self):
        """FIX 2: MOD is a 'creates' disposition for edge detection."""
        jcl = """\
//MODJOB  JOB (ACCT),'MOD TEST'
//STEP01  EXEC PGM=APPEND
//LOGFILE DD DSN=APP.LOG,DISP=(MOD,CATLG)
//STEP02  EXEC PGM=READER
//INPUT   DD DSN=APP.LOG,DISP=SHR
"""
        dag = parse_jcl(jcl)

        # MOD creates, SHR reads → edge STEP01 → STEP02
        assert ("STEP01", "STEP02") in dag.dependencies

    def test_two_part_disp(self):
        jcl = """\
//TWOJOB  JOB (ACCT),'TWO PART'
//STEP01  EXEC PGM=PROG
//OUT     DD DSN=MY.FILE,DISP=(NEW,CATLG)
"""
        dag = parse_jcl(jcl)
        dd = dag.steps[0].dd_statements[0]
        assert dd.disp == ("NEW", "CATLG", "")


# ── Test 8: Step dependency ordering ──────────────────────────────

class TestStepOrdering:
    def test_four_step_chain(self):
        jcl = """\
//CHAINJOB JOB (ACCT),'CHAIN TEST'
//S1      EXEC PGM=PROG1
//S2      EXEC PGM=PROG2
//S3      EXEC PGM=PROG3
//S4      EXEC PGM=PROG4
"""
        dag = parse_jcl(jcl)

        assert len(dag.steps) == 4
        assert [s.name for s in dag.steps] == ["S1", "S2", "S3", "S4"]

        # 3 sequential edges
        assert ("S1", "S2") in dag.dependencies
        assert ("S2", "S3") in dag.dependencies
        assert ("S3", "S4") in dag.dependencies

        # Summary is well-formed
        s = dag.summary()
        assert "JOB: CHAINJOB" in s
        assert "PGM=PROG1" in s
        assert "S1 -> S2 -> S3 -> S4" in s


# ── Test 9: No duplicate edges ──────────────────────────────────

class TestNoDuplicateEdges:
    def test_jcl_no_duplicate_edges(self):
        """Multiple DD statements in STEP2 reading same DSN created by STEP1
        should not produce duplicate dependency edges."""
        jcl = """\
//DUPJOB  JOB (ACCT),'DEDUP TEST'
//STEP1   EXEC PGM=WRITER
//OUT1    DD DSN=SHARED.DATA,DISP=(NEW,CATLG,DELETE)
//STEP2   EXEC PGM=READER
//IN1     DD DSN=SHARED.DATA,DISP=SHR
//IN2     DD DSN=SHARED.DATA,DISP=SHR
"""
        dag = parse_jcl(jcl)

        assert ("STEP1", "STEP2") in dag.dependencies
        # Count occurrences — must be exactly 1
        count = dag.dependencies.count(("STEP1", "STEP2"))
        assert count == 1, f"Expected 1 edge STEP1→STEP2, got {count}"


# ── Test 10: Dedup preserves order ──────────────────────────────

class TestDedupPreservesOrder:
    def test_jcl_dedup_preserves_order(self):
        """Edges A→B, B→C, A→B (duplicate from dataset handoff).
        After dedup: [A→B, B→C] in that order."""
        jcl = """\
//ORDJOB  JOB (ACCT),'ORDER TEST'
//A       EXEC PGM=PROG1
//OUT     DD DSN=LINK.DATA,DISP=(NEW,CATLG,DELETE)
//B       EXEC PGM=PROG2
//IN      DD DSN=LINK.DATA,DISP=SHR
//C       EXEC PGM=PROG3
"""
        dag = parse_jcl(jcl)

        # Sequential: A→B, B→C. Dataset handoff: A→B (duplicate).
        # After dedup: exactly [('A', 'B'), ('B', 'C')]
        assert dag.dependencies == [("A", "B"), ("B", "C")]
