       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOTO-SPAGHETTI.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNTER       PIC 9(2) VALUE 0.
       01  WS-PATH          PIC X(30) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-START THRU 3000-END.
           DISPLAY WS-PATH.
           STOP RUN.
       1000-START.
           ADD 1 TO WS-COUNTER.
           STRING WS-PATH DELIMITED BY '  '
                  'A' DELIMITED BY SIZE
                  INTO WS-PATH.
           GO TO 2000-MIDDLE.
       1500-SKIP.
           STRING WS-PATH DELIMITED BY '  '
                  'B' DELIMITED BY SIZE
                  INTO WS-PATH.
           GO TO 3000-END.
       2000-MIDDLE.
           ADD 1 TO WS-COUNTER.
           STRING WS-PATH DELIMITED BY '  '
                  'C' DELIMITED BY SIZE
                  INTO WS-PATH.
           GO TO 1500-SKIP.
       2500-DEAD.
           STRING WS-PATH DELIMITED BY '  '
                  'D' DELIMITED BY SIZE
                  INTO WS-PATH.
       3000-END.
           ADD 1 TO WS-COUNTER.
           STRING WS-PATH DELIMITED BY '  '
                  'E' DELIMITED BY SIZE
                  INTO WS-PATH.
