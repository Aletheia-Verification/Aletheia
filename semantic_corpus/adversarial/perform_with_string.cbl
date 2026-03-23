       IDENTIFICATION DIVISION.
       PROGRAM-ID. PERF-STRING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A            PIC X(5).
       01  WS-B            PIC X(5).
       01  WS-OUT           PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM PARA-BUILD.
           STOP RUN.
       PARA-BUILD.
           STRING WS-A DELIMITED BY SIZE
                  WS-B DELIMITED BY SIZE
                  INTO WS-OUT
           END-STRING.
