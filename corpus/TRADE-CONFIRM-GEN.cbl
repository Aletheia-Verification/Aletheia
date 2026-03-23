       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRADE-CONFIRM-GEN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TRADE-DATA.
           05 WS-TRADE-ID            PIC X(12).
           05 WS-SECURITY-ID         PIC X(10).
           05 WS-SECURITY-NAME       PIC X(30).
           05 WS-QTY                 PIC 9(7).
           05 WS-PRICE               PIC S9(7)V99 COMP-3.
           05 WS-TRADE-DATE          PIC X(10).
           05 WS-SETTLE-DATE         PIC X(10).
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ACCT-NAME           PIC X(30).
       01 WS-SIDE                    PIC X(1).
           88 WS-BUY                 VALUE 'B'.
           88 WS-SELL                VALUE 'S'.
       01 WS-AMOUNTS.
           05 WS-GROSS               PIC S9(11)V99 COMP-3.
           05 WS-COMMISSION          PIC S9(7)V99 COMP-3.
           05 WS-NET                 PIC S9(11)V99 COMP-3.
       01 WS-CONFIRM-LINE1           PIC X(80).
       01 WS-CONFIRM-LINE2           PIC X(80).
       01 WS-CONFIRM-LINE3           PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-CALC-AMOUNTS
           PERFORM 2000-BUILD-CONFIRM
           PERFORM 3000-DISPLAY-CONFIRM
           STOP RUN.
       1000-CALC-AMOUNTS.
           COMPUTE WS-GROSS = WS-QTY * WS-PRICE
           COMPUTE WS-COMMISSION = WS-GROSS * 0.005
           IF WS-BUY
               COMPUTE WS-NET = WS-GROSS + WS-COMMISSION
           ELSE
               COMPUTE WS-NET = WS-GROSS - WS-COMMISSION
           END-IF.
       2000-BUILD-CONFIRM.
           STRING 'TRADE CONFIRM ' DELIMITED BY SIZE
                  WS-TRADE-ID DELIMITED BY SIZE
                  ' DATE=' DELIMITED BY SIZE
                  WS-TRADE-DATE DELIMITED BY SIZE
                  INTO WS-CONFIRM-LINE1
           END-STRING
           IF WS-BUY
               STRING 'BOUGHT ' DELIMITED BY SIZE
                      WS-QTY DELIMITED BY SIZE
                      ' ' DELIMITED BY SIZE
                      WS-SECURITY-NAME DELIMITED BY '  '
                      ' @ ' DELIMITED BY SIZE
                      WS-PRICE DELIMITED BY SIZE
                      INTO WS-CONFIRM-LINE2
               END-STRING
           ELSE
               STRING 'SOLD ' DELIMITED BY SIZE
                      WS-QTY DELIMITED BY SIZE
                      ' ' DELIMITED BY SIZE
                      WS-SECURITY-NAME DELIMITED BY '  '
                      ' @ ' DELIMITED BY SIZE
                      WS-PRICE DELIMITED BY SIZE
                      INTO WS-CONFIRM-LINE2
               END-STRING
           END-IF
           STRING 'NET AMT=' DELIMITED BY SIZE
                  WS-NET DELIMITED BY SIZE
                  ' SETTLE=' DELIMITED BY SIZE
                  WS-SETTLE-DATE DELIMITED BY SIZE
                  INTO WS-CONFIRM-LINE3
           END-STRING.
       3000-DISPLAY-CONFIRM.
           DISPLAY WS-CONFIRM-LINE1
           DISPLAY WS-CONFIRM-LINE2
           DISPLAY WS-CONFIRM-LINE3
           DISPLAY 'ACCOUNT: ' WS-ACCT-NUM
           DISPLAY 'GROSS:   ' WS-GROSS
           DISPLAY 'COMM:    ' WS-COMMISSION
           DISPLAY 'NET:     ' WS-NET.
