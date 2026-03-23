       IDENTIFICATION DIVISION.
       PROGRAM-ID. ARITHMETIC-STRESS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A                   PIC S9(5)V99.
       01  WS-B                   PIC S9(5)V99.
       01  WS-C                   PIC S9(5)V99.
       01  WS-D                   PIC S9(5)V99.
       01  WS-RESULT              PIC S9(7)V99.
       01  WS-REMAINDER           PIC S9(5)V99.
       01  WS-BIG                 PIC S9(3)V99.
       01  WS-OVERFLOW-FLAG       PIC X(1).
       01  WS-RATE                PIC 9V9(4).
       01  WS-PRINCIPAL           PIC S9(7)V99.
       01  WS-MONTHS              PIC 9(3).
       01  WS-PAYMENT             PIC S9(7)V99.
       01  WS-INTEREST            PIC S9(7)V99.
       01  WS-TOTAL               PIC S9(9)V99.
       01  WS-TEMP                PIC S9(9)V99.

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           MOVE 100.50 TO WS-A
           MOVE 200.75 TO WS-B
           MOVE 50.25  TO WS-C
           MOVE 10.00  TO WS-D
           MOVE 'N' TO WS-OVERFLOW-FLAG

           ADD WS-A TO WS-B
           ADD WS-A WS-B TO WS-C
           ADD WS-A TO WS-B GIVING WS-RESULT
           ADD 100 TO WS-A
           ADD WS-A WS-B WS-C GIVING WS-RESULT

           SUBTRACT WS-A FROM WS-B
           SUBTRACT WS-A FROM WS-B GIVING WS-RESULT
           SUBTRACT 50 FROM WS-C
           SUBTRACT WS-A WS-B FROM WS-C GIVING WS-RESULT

           MULTIPLY WS-A BY WS-B
           MULTIPLY WS-A BY WS-B GIVING WS-RESULT
           MULTIPLY 2 BY WS-C
           MULTIPLY WS-A BY 3 GIVING WS-RESULT

           DIVIDE WS-A INTO WS-B
           DIVIDE WS-A INTO WS-B GIVING WS-RESULT
           DIVIDE WS-A BY WS-B GIVING WS-RESULT
           DIVIDE WS-A INTO WS-B GIVING WS-RESULT
               REMAINDER WS-REMAINDER
           DIVIDE 12 INTO WS-C

           COMPUTE WS-RESULT = WS-A + WS-B - WS-C
           COMPUTE WS-RESULT = WS-A * WS-B / WS-C
           COMPUTE WS-RESULT = (WS-A + WS-B) * (WS-C - WS-D)
           COMPUTE WS-RESULT = WS-A ** 2

           COMPUTE WS-RESULT ROUNDED =
               WS-A * WS-B / WS-C

           ADD WS-A TO WS-BIG
               ON SIZE ERROR
                   MOVE 'Y' TO WS-OVERFLOW-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-OVERFLOW-FLAG
           END-ADD

           MULTIPLY WS-A BY WS-BIG
               ON SIZE ERROR
                   MOVE 'Y' TO WS-OVERFLOW-FLAG
           END-MULTIPLY

           DIVIDE WS-A INTO WS-BIG
               ON SIZE ERROR
                   MOVE 'Y' TO WS-OVERFLOW-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-OVERFLOW-FLAG
           END-DIVIDE

           COMPUTE WS-BIG ROUNDED = WS-A * WS-B
               ON SIZE ERROR
                   MOVE 'Y' TO WS-OVERFLOW-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-OVERFLOW-FLAG
           END-COMPUTE

           MOVE 50000.00 TO WS-PRINCIPAL
           MOVE 0.0425 TO WS-RATE
           MOVE 360 TO WS-MONTHS
           COMPUTE WS-PAYMENT ROUNDED =
               WS-PRINCIPAL *
               (WS-RATE / 12) /
               (1 - (1 + WS-RATE / 12) ** (0 - WS-MONTHS))

           MOVE 0 TO WS-TOTAL
           ADD WS-A TO WS-TOTAL
           ADD WS-B TO WS-TOTAL
           SUBTRACT WS-C FROM WS-TOTAL
           MULTIPLY WS-D BY WS-TOTAL
           DIVIDE 3 INTO WS-TOTAL

           STOP RUN.
