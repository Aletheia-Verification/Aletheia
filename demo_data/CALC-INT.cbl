       IDENTIFICATION DIVISION.
       PROGRAM-ID. CALC-INT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TEMP              PIC S9(13)V99.

       LINKAGE SECTION.
       01  LS-PRINCIPAL         PIC S9(13)V99.
       01  LS-RATE              PIC S9(3)V9(4).
       01  LS-RESULT            PIC S9(13)V99.

       PROCEDURE DIVISION USING LS-PRINCIPAL
                                LS-RATE
                                LS-RESULT.
       CALC-INTEREST.
           COMPUTE LS-RESULT = LS-PRINCIPAL * LS-RATE.
           GOBACK.
