       IDENTIFICATION DIVISION.
       PROGRAM-ID. SORT-MERGE-RECON.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SORT-FILE ASSIGN TO 'SORT.TMP'.
           SELECT INPUT-FILE ASSIGN TO 'UNSORTED.DAT'
               FILE STATUS IS WS-IN-STATUS.
           SELECT OUTPUT-FILE ASSIGN TO 'SORTED.DAT'
               FILE STATUS IS WS-OUT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       SD SORT-FILE.
       01 SORT-RECORD.
           05 SR-KEY                 PIC X(12).
           05 SR-AMOUNT              PIC 9(9)V99.
           05 SR-TYPE                PIC X(2).
           05 SR-DATE                PIC 9(8).
       FD INPUT-FILE.
       01 INPUT-RECORD.
           05 IR-KEY                 PIC X(12).
           05 IR-AMOUNT              PIC 9(9)V99.
           05 IR-TYPE                PIC X(2).
           05 IR-DATE                PIC 9(8).
       FD OUTPUT-FILE.
       01 OUTPUT-RECORD.
           05 OR-KEY                 PIC X(12).
           05 OR-AMOUNT              PIC 9(9)V99.
           05 OR-TYPE                PIC X(2).
           05 OR-DATE                PIC 9(8).
       WORKING-STORAGE SECTION.
       01 WS-IN-STATUS               PIC XX.
       01 WS-OUT-STATUS              PIC XX.
       01 WS-SORT-STATUS             PIC X(1).
           88 WS-SORT-OK             VALUE 'Y'.
           88 WS-SORT-FAIL           VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SORT-FILE
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           SET WS-SORT-FAIL TO TRUE.
       2000-SORT-FILE.
           SORT SORT-FILE
               ON ASCENDING KEY SR-KEY
               USING INPUT-FILE
               GIVING OUTPUT-FILE
           MOVE 'Y' TO WS-SORT-STATUS.
       3000-DISPLAY-RESULTS.
           DISPLAY 'SORT MERGE RECONCILIATION'
           DISPLAY '========================='
           IF WS-SORT-OK
               DISPLAY 'SORT: COMPLETED'
           ELSE
               DISPLAY 'SORT: FAILED'
           END-IF.
