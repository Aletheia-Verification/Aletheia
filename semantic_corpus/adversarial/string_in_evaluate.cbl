       IDENTIFICATION DIVISION.
       PROGRAM-ID. STR-IN-EVAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X            PIC 9(1).
       01  WS-OUT           PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN WS-X = 1
                   STRING 'YES' DELIMITED BY SIZE
                       INTO WS-OUT
                   END-STRING
               WHEN OTHER
                   MOVE 'NO' TO WS-OUT
           END-EVALUATE.
           STOP RUN.
