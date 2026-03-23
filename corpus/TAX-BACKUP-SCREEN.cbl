       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-BACKUP-SCREEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-TIN                 PIC X(9).
           05 WS-NAME                PIC X(30).
           05 WS-INT-INCOME          PIC S9(9)V99 COMP-3.
       01 WS-B-NOTICE-FLAG           PIC X VALUE 'N'.
           88 WS-HAS-B-NOTICE        VALUE 'Y'.
       01 WS-TIN-VALID               PIC X VALUE 'N'.
           88 WS-TIN-OK              VALUE 'Y'.
       01 WS-BACKUP-REQUIRED         PIC X VALUE 'N'.
           88 WS-NEEDS-BACKUP        VALUE 'Y'.
       01 WS-BACKUP-RATE             PIC S9(1)V9(4) COMP-3
           VALUE 0.2400.
       01 WS-BACKUP-AMT              PIC S9(7)V99 COMP-3.
       01 WS-NET-INCOME              PIC S9(9)V99 COMP-3.
       01 WS-EXEMPT-FLAG             PIC X VALUE 'N'.
           88 WS-IS-EXEMPT           VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-TIN
           PERFORM 3000-CHECK-BACKUP
           PERFORM 4000-CALC-WITHHOLDING
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-BACKUP-AMT
           MOVE 'N' TO WS-BACKUP-REQUIRED
           MOVE 'N' TO WS-TIN-VALID.
       2000-VALIDATE-TIN.
           IF WS-TIN IS NUMERIC
               IF WS-TIN NOT = '000000000'
                   MOVE 'Y' TO WS-TIN-VALID
               END-IF
           END-IF.
       3000-CHECK-BACKUP.
           IF WS-TIN-OK
               IF WS-HAS-B-NOTICE
                   MOVE 'Y' TO WS-BACKUP-REQUIRED
               END-IF
           ELSE
               IF WS-IS-EXEMPT
                   MOVE 'N' TO WS-BACKUP-REQUIRED
               ELSE
                   MOVE 'Y' TO WS-BACKUP-REQUIRED
               END-IF
           END-IF.
       4000-CALC-WITHHOLDING.
           IF WS-NEEDS-BACKUP
               COMPUTE WS-BACKUP-AMT =
                   WS-INT-INCOME * WS-BACKUP-RATE
               COMPUTE WS-NET-INCOME =
                   WS-INT-INCOME - WS-BACKUP-AMT
           ELSE
               MOVE WS-INT-INCOME TO WS-NET-INCOME
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'BACKUP WITHHOLDING SCREENING'
           DISPLAY '============================'
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'TIN:         ' WS-TIN
           DISPLAY 'INT INCOME:  ' WS-INT-INCOME
           IF WS-TIN-OK
               DISPLAY 'TIN: VALID'
           ELSE
               DISPLAY 'TIN: INVALID'
           END-IF
           IF WS-NEEDS-BACKUP
               DISPLAY 'BACKUP: REQUIRED'
               DISPLAY 'WITHHELD:    ' WS-BACKUP-AMT
               DISPLAY 'NET INCOME:  ' WS-NET-INCOME
           ELSE
               DISPLAY 'BACKUP: NOT REQUIRED'
           END-IF.
