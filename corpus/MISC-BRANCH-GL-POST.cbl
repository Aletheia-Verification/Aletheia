       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-BRANCH-GL-POST.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TXN-FILE ASSIGN TO 'GL-TXN.DAT'
               FILE STATUS IS WS-TXN-STATUS.
           SELECT GL-FILE ASSIGN TO 'GL-POST.DAT'
               FILE STATUS IS WS-GL-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD TXN-FILE.
       01 TXN-RECORD.
           05 TX-BRANCH              PIC X(4).
           05 TX-GL-ACCT             PIC X(6).
           05 TX-AMOUNT              PIC S9(9)V99.
           05 TX-DB-CR               PIC X(1).
       FD GL-FILE.
       01 GL-RECORD.
           05 GL-BRANCH              PIC X(4).
           05 GL-TOTAL-DB            PIC 9(11)V99.
           05 GL-TOTAL-CR            PIC 9(11)V99.
           05 GL-NET                 PIC S9(11)V99.
           05 GL-TXN-COUNT           PIC 9(5).
       WORKING-STORAGE SECTION.
       01 WS-TXN-STATUS              PIC XX.
       01 WS-GL-STATUS               PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-BRANCH-TABLE.
           05 WS-BRANCH OCCURS 10.
               10 WS-BR-ID           PIC X(4).
               10 WS-BR-DEBITS       PIC S9(11)V99 COMP-3.
               10 WS-BR-CREDITS      PIC S9(11)V99 COMP-3.
               10 WS-BR-COUNT        PIC S9(5) COMP-3.
       01 WS-BR-IDX                  PIC 9(2).
       01 WS-BR-USED                 PIC 9(2).
       01 WS-FOUND                   PIC 9(2).
       01 WS-GRAND-DB                PIC S9(13)V99 COMP-3.
       01 WS-GRAND-CR                PIC S9(13)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 1100-OPEN-FILES
           PERFORM 2000-READ-TXNS UNTIL WS-EOF
           PERFORM 3000-WRITE-GL
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BR-USED
           MOVE 0 TO WS-GRAND-DB
           MOVE 0 TO WS-GRAND-CR
           PERFORM VARYING WS-BR-IDX FROM 1 BY 1
               UNTIL WS-BR-IDX > 10
               MOVE SPACES TO WS-BR-ID(WS-BR-IDX)
               MOVE 0 TO WS-BR-DEBITS(WS-BR-IDX)
               MOVE 0 TO WS-BR-CREDITS(WS-BR-IDX)
               MOVE 0 TO WS-BR-COUNT(WS-BR-IDX)
           END-PERFORM.
       1100-OPEN-FILES.
           OPEN INPUT TXN-FILE
           OPEN OUTPUT GL-FILE.
       2000-READ-TXNS.
           READ TXN-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 2100-POST-TXN
           END-READ.
       2100-POST-TXN.
           MOVE 0 TO WS-FOUND
           PERFORM VARYING WS-BR-IDX FROM 1 BY 1
               UNTIL WS-BR-IDX > WS-BR-USED
               OR WS-FOUND > 0
               IF WS-BR-ID(WS-BR-IDX) = TX-BRANCH
                   MOVE WS-BR-IDX TO WS-FOUND
               END-IF
           END-PERFORM
           IF WS-FOUND = 0
               ADD 1 TO WS-BR-USED
               MOVE WS-BR-USED TO WS-FOUND
               MOVE TX-BRANCH TO WS-BR-ID(WS-FOUND)
           END-IF
           ADD 1 TO WS-BR-COUNT(WS-FOUND)
           IF TX-DB-CR = 'D'
               ADD TX-AMOUNT TO WS-BR-DEBITS(WS-FOUND)
               ADD TX-AMOUNT TO WS-GRAND-DB
           ELSE
               ADD TX-AMOUNT TO WS-BR-CREDITS(WS-FOUND)
               ADD TX-AMOUNT TO WS-GRAND-CR
           END-IF.
       3000-WRITE-GL.
           PERFORM VARYING WS-BR-IDX FROM 1 BY 1
               UNTIL WS-BR-IDX > WS-BR-USED
               MOVE WS-BR-ID(WS-BR-IDX) TO GL-BRANCH
               MOVE WS-BR-DEBITS(WS-BR-IDX) TO GL-TOTAL-DB
               MOVE WS-BR-CREDITS(WS-BR-IDX) TO GL-TOTAL-CR
               COMPUTE GL-NET =
                   WS-BR-DEBITS(WS-BR-IDX) -
                   WS-BR-CREDITS(WS-BR-IDX)
               MOVE WS-BR-COUNT(WS-BR-IDX) TO GL-TXN-COUNT
               WRITE GL-RECORD
           END-PERFORM.
       4000-CLOSE-FILES.
           CLOSE TXN-FILE
           CLOSE GL-FILE.
       5000-DISPLAY-SUMMARY.
           DISPLAY 'GL POSTING SUMMARY'
           DISPLAY '=================='
           DISPLAY 'BRANCHES: ' WS-BR-USED
           DISPLAY 'DEBITS:   ' WS-GRAND-DB
           DISPLAY 'CREDITS:  ' WS-GRAND-CR.
