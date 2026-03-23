       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-AUDIT-TRAIL.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT AUDIT-FILE ASSIGN TO 'AUDIT.DAT'
               FILE STATUS IS WS-AUDIT-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD AUDIT-FILE.
       01 AUDIT-RECORD.
           05 AD-TIMESTAMP           PIC X(20).
           05 AD-USER-ID             PIC X(8).
           05 AD-ACTION              PIC X(10).
           05 AD-ACCT-NUM            PIC X(12).
           05 AD-AMOUNT              PIC S9(9)V99.
           05 AD-STATUS              PIC X(2).
       WORKING-STORAGE SECTION.
       01 WS-AUDIT-STATUS            PIC XX.
       01 WS-AUDIT-DATA.
           05 WS-TIMESTAMP           PIC X(20).
           05 WS-USER-ID             PIC X(8).
           05 WS-ACTION              PIC X(10).
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-AMOUNT              PIC S9(9)V99 COMP-3.
       01 WS-AUDIT-MSG               PIC X(60).
       01 WS-WRITE-OK                PIC X VALUE 'N'.
           88 WS-WRITTEN             VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-BUILD-RECORD
           PERFORM 3000-WRITE-AUDIT
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-WRITE-OK.
       2000-BUILD-RECORD.
           MOVE WS-TIMESTAMP TO AD-TIMESTAMP
           MOVE WS-USER-ID TO AD-USER-ID
           MOVE WS-ACTION TO AD-ACTION
           MOVE WS-ACCT-NUM TO AD-ACCT-NUM
           MOVE WS-AMOUNT TO AD-AMOUNT
           MOVE 'OK' TO AD-STATUS
           STRING WS-ACTION DELIMITED BY '  '
                  '|' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-USER-ID DELIMITED BY SIZE
                  '|' DELIMITED BY SIZE
                  WS-AMOUNT DELIMITED BY SIZE
                  INTO WS-AUDIT-MSG
           END-STRING.
       3000-WRITE-AUDIT.
           OPEN OUTPUT AUDIT-FILE
           IF WS-AUDIT-STATUS = '00'
               WRITE AUDIT-RECORD
               IF WS-AUDIT-STATUS = '00'
                   MOVE 'Y' TO WS-WRITE-OK
               END-IF
               CLOSE AUDIT-FILE
           END-IF.
       4000-DISPLAY-RESULTS.
           DISPLAY 'AUDIT TRAIL'
           DISPLAY '==========='
           DISPLAY 'ACTION:  ' WS-ACTION
           DISPLAY 'ACCOUNT: ' WS-ACCT-NUM
           DISPLAY 'USER:    ' WS-USER-ID
           DISPLAY 'AMOUNT:  ' WS-AMOUNT
           IF WS-WRITTEN
               DISPLAY 'STATUS: RECORDED'
           ELSE
               DISPLAY 'STATUS: WRITE FAILED'
           END-IF
           DISPLAY WS-AUDIT-MSG.
