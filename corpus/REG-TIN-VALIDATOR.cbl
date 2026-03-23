       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-TIN-VALIDATOR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TIN-DATA.
           05 WS-TIN-VALUE           PIC X(9).
           05 WS-TIN-TYPE            PIC X(1).
               88 WS-SSN             VALUE 'S'.
               88 WS-EIN             VALUE 'E'.
               88 WS-ITIN            VALUE 'I'.
       01 WS-VALIDATION.
           05 WS-IS-VALID            PIC X VALUE 'N'.
               88 WS-VALID           VALUE 'Y'.
           05 WS-ERROR-MSG           PIC X(30).
       01 WS-DIGIT-COUNT             PIC 9(2).
       01 WS-AREA-NUM                PIC 9(3).
       01 WS-GROUP-NUM               PIC 9(2).
       01 WS-SERIAL-NUM              PIC 9(4).
       01 WS-TIN-IDX                 PIC 9(2).
       01 WS-TIN-TABLE.
           05 WS-INVALID-AREA OCCURS 5.
               10 WS-IA-VALUE        PIC 9(3).
       01 WS-IA-IDX                  PIC 9(1).
       01 WS-FORMATTED-TIN           PIC X(11).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-NUMERIC
           IF WS-VALID
               PERFORM 3000-VALIDATE-FORMAT
           END-IF
           IF WS-VALID
               PERFORM 4000-CHECK-INVALID-AREAS
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'N' TO WS-IS-VALID
           MOVE SPACES TO WS-ERROR-MSG
           MOVE 0 TO WS-DIGIT-COUNT
           MOVE 0 TO WS-INVALID-AREA(1)
           MOVE 666 TO WS-INVALID-AREA(2)
           MOVE 900 TO WS-INVALID-AREA(3)
           MOVE 999 TO WS-INVALID-AREA(4)
           MOVE 0 TO WS-INVALID-AREA(5).
       2000-CHECK-NUMERIC.
           IF WS-TIN-VALUE IS NUMERIC
               MOVE 'Y' TO WS-IS-VALID
               INSPECT WS-TIN-VALUE
                   TALLYING WS-DIGIT-COUNT
                   FOR ALL '0'
               IF WS-DIGIT-COUNT = 9
                   MOVE 'N' TO WS-IS-VALID
                   MOVE 'ALL ZEROS' TO WS-ERROR-MSG
               END-IF
           ELSE
               MOVE 'NOT ALL NUMERIC' TO WS-ERROR-MSG
           END-IF.
       3000-VALIDATE-FORMAT.
           IF WS-SSN
               MOVE WS-TIN-VALUE(1:3) TO WS-AREA-NUM
               MOVE WS-TIN-VALUE(4:2) TO WS-GROUP-NUM
               MOVE WS-TIN-VALUE(6:4) TO WS-SERIAL-NUM
               IF WS-GROUP-NUM = 0
                   MOVE 'N' TO WS-IS-VALID
                   MOVE 'INVALID GROUP' TO WS-ERROR-MSG
               END-IF
               IF WS-SERIAL-NUM = 0
                   MOVE 'N' TO WS-IS-VALID
                   MOVE 'INVALID SERIAL' TO WS-ERROR-MSG
               END-IF
           END-IF
           IF WS-EIN
               MOVE WS-TIN-VALUE(1:2) TO WS-GROUP-NUM
               IF WS-GROUP-NUM = 0
                   MOVE 'N' TO WS-IS-VALID
                   MOVE 'INVALID EIN PREFIX' TO
                       WS-ERROR-MSG
               END-IF
           END-IF.
       4000-CHECK-INVALID-AREAS.
           IF WS-SSN
               PERFORM VARYING WS-IA-IDX FROM 1 BY 1
                   UNTIL WS-IA-IDX > 5
                   IF WS-AREA-NUM =
                       WS-INVALID-AREA(WS-IA-IDX)
                       MOVE 'N' TO WS-IS-VALID
                       MOVE 'INVALID AREA NUMBER' TO
                           WS-ERROR-MSG
                   END-IF
               END-PERFORM
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'TIN VALIDATION REPORT'
           DISPLAY '====================='
           DISPLAY 'TIN VALUE: ' WS-TIN-VALUE
           IF WS-SSN
               DISPLAY 'TYPE: SSN'
           END-IF
           IF WS-EIN
               DISPLAY 'TYPE: EIN'
           END-IF
           IF WS-ITIN
               DISPLAY 'TYPE: ITIN'
           END-IF
           IF WS-VALID
               DISPLAY 'STATUS: VALID'
           ELSE
               DISPLAY 'STATUS: INVALID'
               DISPLAY 'ERROR:  ' WS-ERROR-MSG
           END-IF.
