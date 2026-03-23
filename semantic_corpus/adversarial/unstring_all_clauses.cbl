       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTRING-ALL-CLAUSES.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-INPUT         PIC X(30) VALUE 'AAA,BBB;CCC,DDD'.
       01  WS-OUT1          PIC X(5).
       01  WS-OUT2          PIC X(5).
       01  WS-OUT3          PIC X(5).
       01  WS-OUT4          PIC X(5).
       01  WS-DELIM1        PIC X(1).
       01  WS-DELIM2        PIC X(1).
       01  WS-COUNT1        PIC 9(2).
       01  WS-COUNT2        PIC 9(2).
       01  WS-PTR           PIC 9(2) VALUE 1.
       01  WS-TALLY         PIC 9(2) VALUE 0.
       01  WS-OVERFLOW      PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-INPUT
               DELIMITED BY ',' OR ';'
               INTO WS-OUT1 DELIMITER IN WS-DELIM1
                             COUNT IN WS-COUNT1
                    WS-OUT2 DELIMITER IN WS-DELIM2
                             COUNT IN WS-COUNT2
                    WS-OUT3
                    WS-OUT4
               WITH POINTER WS-PTR
               TALLYING IN WS-TALLY
               ON OVERFLOW
                   MOVE 'Y' TO WS-OVERFLOW
               NOT ON OVERFLOW
                   MOVE 'N' TO WS-OVERFLOW
           END-UNSTRING.
           DISPLAY WS-OUT1.
           DISPLAY WS-OUT2.
           DISPLAY WS-TALLY.
           STOP RUN.
