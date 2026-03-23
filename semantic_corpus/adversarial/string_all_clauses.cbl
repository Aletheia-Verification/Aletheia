       IDENTIFICATION DIVISION.
       PROGRAM-ID. STRING-ALL-CLAUSES.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FIRST         PIC X(10) VALUE 'JOHN'.
       01  WS-LAST          PIC X(10) VALUE 'SMITH'.
       01  WS-RESULT        PIC X(20) VALUE SPACES.
       01  WS-PTR           PIC 9(2) VALUE 1.
       01  WS-OVERFLOW      PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           STRING WS-FIRST DELIMITED BY '  '
                  ', ' DELIMITED BY SIZE
                  WS-LAST DELIMITED BY '  '
                  INTO WS-RESULT
                  WITH POINTER WS-PTR
                  ON OVERFLOW
                      MOVE 'Y' TO WS-OVERFLOW
                  NOT ON OVERFLOW
                      MOVE 'N' TO WS-OVERFLOW
           END-STRING.
           DISPLAY WS-RESULT.
           DISPLAY WS-PTR.
           DISPLAY WS-OVERFLOW.
           STOP RUN.
