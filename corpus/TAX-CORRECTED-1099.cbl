       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-CORRECTED-1099.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ORIGINAL-DATA.
           05 WS-ORIG-SSN            PIC X(9).
           05 WS-ORIG-NAME           PIC X(30).
           05 WS-ORIG-AMOUNT         PIC S9(9)V99 COMP-3.
       01 WS-CORRECTED-DATA.
           05 WS-CORR-SSN            PIC X(9).
           05 WS-CORR-NAME           PIC X(30).
           05 WS-CORR-AMOUNT         PIC S9(9)V99 COMP-3.
       01 WS-VARIANCE                PIC S9(9)V99 COMP-3.
       01 WS-CORR-REASON             PIC X(1).
           88 WS-AMOUNT-CHANGE       VALUE 'A'.
           88 WS-NAME-CHANGE         VALUE 'N'.
           88 WS-SSN-CHANGE          VALUE 'S'.
       01 WS-PARSED-FIRST            PIC X(15).
       01 WS-PARSED-LAST             PIC X(20).
       01 WS-FORMATTED-LINE          PIC X(80).
       01 WS-CORRECTION-FLAG         PIC X VALUE 'N'.
           88 WS-NEEDS-CORRECTION    VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-COMPARE-DATA
           IF WS-NEEDS-CORRECTION
               PERFORM 3000-PARSE-NAME
               PERFORM 4000-BUILD-CORRECTION
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-VARIANCE
           MOVE 'N' TO WS-CORRECTION-FLAG.
       2000-COMPARE-DATA.
           IF WS-CORR-AMOUNT NOT = WS-ORIG-AMOUNT
               SET WS-AMOUNT-CHANGE TO TRUE
               MOVE 'Y' TO WS-CORRECTION-FLAG
               COMPUTE WS-VARIANCE =
                   WS-CORR-AMOUNT - WS-ORIG-AMOUNT
           END-IF
           IF WS-CORR-NAME NOT = WS-ORIG-NAME
               SET WS-NAME-CHANGE TO TRUE
               MOVE 'Y' TO WS-CORRECTION-FLAG
           END-IF
           IF WS-CORR-SSN NOT = WS-ORIG-SSN
               SET WS-SSN-CHANGE TO TRUE
               MOVE 'Y' TO WS-CORRECTION-FLAG
           END-IF.
       3000-PARSE-NAME.
           UNSTRING WS-CORR-NAME
               DELIMITED BY ' '
               INTO WS-PARSED-FIRST
                    WS-PARSED-LAST
           END-UNSTRING.
       4000-BUILD-CORRECTION.
           STRING 'CORR 1099 SSN='
                      DELIMITED BY SIZE
                  WS-CORR-SSN DELIMITED BY SIZE
                  ' NEW-AMT=' DELIMITED BY SIZE
                  WS-CORR-AMOUNT DELIMITED BY SIZE
                  ' VAR=' DELIMITED BY SIZE
                  WS-VARIANCE DELIMITED BY SIZE
                  INTO WS-FORMATTED-LINE
           END-STRING.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CORRECTED 1099 REPORT'
           DISPLAY '====================='
           DISPLAY 'ORIGINAL SSN:  ' WS-ORIG-SSN
           DISPLAY 'ORIGINAL AMT:  ' WS-ORIG-AMOUNT
           IF WS-NEEDS-CORRECTION
               DISPLAY 'CORRECTED SSN: ' WS-CORR-SSN
               DISPLAY 'CORRECTED AMT: ' WS-CORR-AMOUNT
               DISPLAY 'VARIANCE:      ' WS-VARIANCE
               IF WS-AMOUNT-CHANGE
                   DISPLAY 'REASON: AMOUNT CORRECTED'
               END-IF
               IF WS-NAME-CHANGE
                   DISPLAY 'REASON: NAME CORRECTED'
               END-IF
               IF WS-SSN-CHANGE
                   DISPLAY 'REASON: SSN CORRECTED'
               END-IF
               DISPLAY WS-FORMATTED-LINE
           ELSE
               DISPLAY 'NO CORRECTION NEEDED'
           END-IF.
