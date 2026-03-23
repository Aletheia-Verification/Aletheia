       IDENTIFICATION DIVISION.
       PROGRAM-ID. SANCTION-LIST-UPDATE.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT DELTA-FILE ASSIGN TO 'DELTAIN'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-DLT-STATUS.
           SELECT MASTER-FILE ASSIGN TO 'MASTERIO'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-MST-STATUS.
           SELECT AUDIT-FILE ASSIGN TO 'AUDITOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-AUD-STATUS.
           SELECT SORT-FILE ASSIGN TO 'SORTWORK'.

       DATA DIVISION.
       FILE SECTION.

       FD DELTA-FILE.
       01 DELTA-RECORD.
           05 DL-ACTION               PIC X(1).
               88 DL-ADD              VALUE 'A'.
               88 DL-DELETE           VALUE 'D'.
               88 DL-MODIFY           VALUE 'M'.
           05 DL-LIST-CODE            PIC X(4).
           05 DL-ENTITY-NAME          PIC X(40).
           05 DL-COUNTRY              PIC X(3).
           05 DL-ID-TYPE              PIC X(2).
           05 DL-ID-NUMBER            PIC X(20).
           05 DL-EFFECTIVE-DATE       PIC 9(8).

       SD SORT-FILE.
       01 SORT-RECORD.
           05 SORT-ACTION             PIC X(1).
           05 SORT-LIST-CODE          PIC X(4).
           05 SORT-ENTITY-NAME        PIC X(40).
           05 SORT-COUNTRY            PIC X(3).
           05 SORT-ID-TYPE            PIC X(2).
           05 SORT-ID-NUMBER          PIC X(20).
           05 SORT-EFF-DATE           PIC 9(8).

       FD MASTER-FILE.
       01 MASTER-RECORD.
           05 MS-LIST-CODE            PIC X(4).
           05 MS-ENTITY-NAME          PIC X(40).
           05 MS-COUNTRY              PIC X(3).
           05 MS-ID-TYPE              PIC X(2).
           05 MS-ID-NUMBER            PIC X(20).
           05 MS-STATUS               PIC X(1).
               88 MS-ACTIVE           VALUE 'A'.
               88 MS-INACTIVE         VALUE 'I'.
           05 MS-ADDED-DATE           PIC 9(8).
           05 MS-MODIFIED-DATE        PIC 9(8).

       FD AUDIT-FILE.
       01 AUDIT-RECORD.
           05 AU-ACTION               PIC X(8).
           05 AU-ENTITY-NAME          PIC X(40).
           05 AU-LIST-CODE            PIC X(4).
           05 AU-RESULT               PIC X(2).
               88 AU-SUCCESS          VALUE 'OK'.
               88 AU-FAILED           VALUE 'FL'.
           05 AU-REASON               PIC X(40).

       WORKING-STORAGE SECTION.

       01 WS-DLT-STATUS               PIC X(2).
       01 WS-MST-STATUS               PIC X(2).
       01 WS-AUD-STATUS               PIC X(2).
       01 WS-EOF-FLAG                 PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.

       01 WS-VALID-LISTS.
           05 WS-VL OCCURS 5          PIC X(4).
       01 WS-VL-COUNT                 PIC 9(1) VALUE 5.
       01 WS-VL-IDX                   PIC 9(1).
       01 WS-VL-FOUND                 PIC X VALUE 'N'.
           88 WS-LIST-VALID           VALUE 'Y'.

       01 WS-COUNTERS.
           05 WS-TOTAL-DELTAS         PIC S9(7) COMP-3 VALUE 0.
           05 WS-ADDS                 PIC S9(7) COMP-3 VALUE 0.
           05 WS-DELETES              PIC S9(7) COMP-3 VALUE 0.
           05 WS-MODIFIES             PIC S9(7) COMP-3 VALUE 0.
           05 WS-ERRORS               PIC S9(7) COMP-3 VALUE 0.

       01 WS-REASON-BUF               PIC X(40).
       01 WS-REASON-PTR               PIC 9(3).
       01 WS-NAME-TALLY               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           SORT SORT-FILE
               ON ASCENDING KEY SORT-LIST-CODE
                   SORT-ENTITY-NAME
               USING DELTA-FILE
               GIVING DELTA-FILE
           PERFORM 1100-OPEN-FILES
           PERFORM 1200-READ-FIRST
           PERFORM 2000-PROCESS-DELTA
               UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'OFAC' TO WS-VL(1)
           MOVE 'EU  ' TO WS-VL(2)
           MOVE 'UN  ' TO WS-VL(3)
           MOVE 'HMTS' TO WS-VL(4)
           MOVE 'DFAT' TO WS-VL(5)
           MOVE 'N' TO WS-EOF-FLAG.

       1100-OPEN-FILES.
           OPEN INPUT DELTA-FILE
           OPEN OUTPUT MASTER-FILE
           OPEN OUTPUT AUDIT-FILE.

       1200-READ-FIRST.
           READ DELTA-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-PROCESS-DELTA.
           ADD 1 TO WS-TOTAL-DELTAS
           PERFORM 2100-VALIDATE-LIST
           IF WS-LIST-VALID
               EVALUATE TRUE
                   WHEN DL-ADD
                       PERFORM 2200-PROCESS-ADD
                   WHEN DL-DELETE
                       PERFORM 2300-PROCESS-DELETE
                   WHEN DL-MODIFY
                       PERFORM 2400-PROCESS-MODIFY
                   WHEN OTHER
                       PERFORM 2500-LOG-ERROR
               END-EVALUATE
           ELSE
               PERFORM 2500-LOG-ERROR
           END-IF
           READ DELTA-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2100-VALIDATE-LIST.
           MOVE 'N' TO WS-VL-FOUND
           PERFORM VARYING WS-VL-IDX FROM 1 BY 1
               UNTIL WS-VL-IDX > WS-VL-COUNT
               OR WS-LIST-VALID
               IF DL-LIST-CODE = WS-VL(WS-VL-IDX)
                   MOVE 'Y' TO WS-VL-FOUND
               END-IF
           END-PERFORM.

       2200-PROCESS-ADD.
           ADD 1 TO WS-ADDS
           MOVE DL-LIST-CODE TO MS-LIST-CODE
           MOVE DL-ENTITY-NAME TO MS-ENTITY-NAME
           MOVE DL-COUNTRY TO MS-COUNTRY
           MOVE DL-ID-TYPE TO MS-ID-TYPE
           MOVE DL-ID-NUMBER TO MS-ID-NUMBER
           MOVE 'A' TO MS-STATUS
           MOVE DL-EFFECTIVE-DATE TO MS-ADDED-DATE
           MOVE DL-EFFECTIVE-DATE TO MS-MODIFIED-DATE
           WRITE MASTER-RECORD
           MOVE 'ADD     ' TO AU-ACTION
           MOVE DL-ENTITY-NAME TO AU-ENTITY-NAME
           MOVE DL-LIST-CODE TO AU-LIST-CODE
           MOVE 'OK' TO AU-RESULT
           MOVE SPACES TO WS-REASON-BUF
           MOVE 1 TO WS-REASON-PTR
           STRING 'ADDED TO ' DL-LIST-CODE ' LIST'
               DELIMITED BY SIZE
               INTO WS-REASON-BUF
               WITH POINTER WS-REASON-PTR
           END-STRING
           MOVE WS-REASON-BUF TO AU-REASON
           WRITE AUDIT-RECORD.

       2300-PROCESS-DELETE.
           ADD 1 TO WS-DELETES
           MOVE DL-LIST-CODE TO MS-LIST-CODE
           MOVE DL-ENTITY-NAME TO MS-ENTITY-NAME
           MOVE DL-COUNTRY TO MS-COUNTRY
           MOVE DL-ID-TYPE TO MS-ID-TYPE
           MOVE DL-ID-NUMBER TO MS-ID-NUMBER
           MOVE 'I' TO MS-STATUS
           MOVE DL-EFFECTIVE-DATE TO MS-MODIFIED-DATE
           MOVE 0 TO MS-ADDED-DATE
           WRITE MASTER-RECORD
           MOVE 'DELETE  ' TO AU-ACTION
           MOVE DL-ENTITY-NAME TO AU-ENTITY-NAME
           MOVE DL-LIST-CODE TO AU-LIST-CODE
           MOVE 'OK' TO AU-RESULT
           MOVE 'REMOVED FROM LIST' TO AU-REASON
           WRITE AUDIT-RECORD.

       2400-PROCESS-MODIFY.
           ADD 1 TO WS-MODIFIES
           MOVE DL-LIST-CODE TO MS-LIST-CODE
           MOVE DL-ENTITY-NAME TO MS-ENTITY-NAME
           MOVE DL-COUNTRY TO MS-COUNTRY
           MOVE DL-ID-TYPE TO MS-ID-TYPE
           MOVE DL-ID-NUMBER TO MS-ID-NUMBER
           MOVE 'A' TO MS-STATUS
           MOVE 0 TO MS-ADDED-DATE
           MOVE DL-EFFECTIVE-DATE TO MS-MODIFIED-DATE
           WRITE MASTER-RECORD
           MOVE 'MODIFY  ' TO AU-ACTION
           MOVE DL-ENTITY-NAME TO AU-ENTITY-NAME
           MOVE DL-LIST-CODE TO AU-LIST-CODE
           MOVE 'OK' TO AU-RESULT
           MOVE 'ENTRY MODIFIED' TO AU-REASON
           WRITE AUDIT-RECORD.

       2500-LOG-ERROR.
           ADD 1 TO WS-ERRORS
           MOVE 'ERROR   ' TO AU-ACTION
           MOVE DL-ENTITY-NAME TO AU-ENTITY-NAME
           MOVE DL-LIST-CODE TO AU-LIST-CODE
           MOVE 'FL' TO AU-RESULT
           MOVE SPACES TO WS-REASON-BUF
           MOVE 1 TO WS-REASON-PTR
           IF NOT WS-LIST-VALID
               STRING 'INVALID LIST CODE: '
                   DL-LIST-CODE
                   DELIMITED BY SIZE
                   INTO WS-REASON-BUF
                   WITH POINTER WS-REASON-PTR
               END-STRING
           ELSE
               STRING 'INVALID ACTION CODE: '
                   DL-ACTION
                   DELIMITED BY SIZE
                   INTO WS-REASON-BUF
                   WITH POINTER WS-REASON-PTR
               END-STRING
           END-IF
           MOVE WS-REASON-BUF TO AU-REASON
           WRITE AUDIT-RECORD.

       3000-CLOSE-FILES.
           CLOSE DELTA-FILE
           CLOSE MASTER-FILE
           CLOSE AUDIT-FILE.

       4000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-NAME-TALLY
           INSPECT WS-REASON-BUF
               TALLYING WS-NAME-TALLY FOR ALL ' '
           DISPLAY 'SANCTION LIST UPDATE COMPLETE'
           DISPLAY 'DELTAS PROCESSED:  ' WS-TOTAL-DELTAS
           DISPLAY 'ADDITIONS:         ' WS-ADDS
           DISPLAY 'DELETIONS:         ' WS-DELETES
           DISPLAY 'MODIFICATIONS:     ' WS-MODIFIES
           DISPLAY 'ERRORS:            ' WS-ERRORS.
