       IDENTIFICATION DIVISION.
       PROGRAM-ID. PERF-VARY-TEST-AFTER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X             PIC 9(1) VALUE 0.
       01  WS-COUNT         PIC 9(2) VALUE 0.
       01  WS-TRACE         PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-BODY
               VARYING WS-X FROM 1 BY 1
               UNTIL WS-X > 3
               WITH TEST AFTER.
           DISPLAY WS-COUNT.
           DISPLAY WS-TRACE.
           STOP RUN.
       1000-BODY.
           ADD 1 TO WS-COUNT.
           STRING WS-TRACE DELIMITED BY '  '
                  WS-X DELIMITED BY SIZE
                  INTO WS-TRACE.
