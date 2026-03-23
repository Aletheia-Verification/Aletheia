       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-FED-RESERVE-FMT.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MSG-FILE ASSIGN TO 'FEDMSG.DAT'
               FILE STATUS IS WS-MSG-STATUS.
           SELECT OUT-FILE ASSIGN TO 'FEDOUT.DAT'
               FILE STATUS IS WS-OUT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD MSG-FILE.
       01 MSG-RECORD.
           05 MR-TXN-TYPE            PIC X(4).
           05 MR-AMOUNT              PIC 9(11)V99.
           05 MR-SENDER-ABA          PIC X(9).
           05 MR-RECEIVER-ABA        PIC X(9).
           05 MR-REF-NUM             PIC X(16).
       FD OUT-FILE.
       01 OUT-RECORD.
           05 OR-MSG-TYPE            PIC X(4).
           05 OR-FORMATTED-MSG       PIC X(76).
       WORKING-STORAGE SECTION.
       01 WS-MSG-STATUS              PIC XX.
       01 WS-OUT-STATUS              PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-FORMATTED-LINE          PIC X(76).
       01 WS-TOTAL-MSGS              PIC S9(5) COMP-3.
       01 WS-TOTAL-AMOUNT            PIC S9(13)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-MSGS UNTIL WS-EOF
           PERFORM 3000-CLOSE-FILES
           PERFORM 4000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-MSGS
           MOVE 0 TO WS-TOTAL-AMOUNT.
       1100-OPEN-FILES.
           OPEN INPUT MSG-FILE
           OPEN OUTPUT OUT-FILE.
       2000-READ-MSGS.
           READ MSG-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-FORMAT-MSG
           END-READ.
       2100-FORMAT-MSG.
           ADD 1 TO WS-TOTAL-MSGS
           ADD MR-AMOUNT TO WS-TOTAL-AMOUNT
           STRING MR-SENDER-ABA DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  MR-RECEIVER-ABA DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  MR-AMOUNT DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  MR-REF-NUM DELIMITED BY SIZE
                  INTO WS-FORMATTED-LINE
           END-STRING
           MOVE MR-TXN-TYPE TO OR-MSG-TYPE
           MOVE WS-FORMATTED-LINE TO OR-FORMATTED-MSG
           WRITE OUT-RECORD.
       3000-CLOSE-FILES.
           CLOSE MSG-FILE
           CLOSE OUT-FILE.
       4000-DISPLAY-SUMMARY.
           DISPLAY 'FED RESERVE FORMATTING'
           DISPLAY '======================'
           DISPLAY 'MESSAGES:  ' WS-TOTAL-MSGS
           DISPLAY 'TOTAL AMT: ' WS-TOTAL-AMOUNT.
