       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEMO-WITH-COPY.
      *
      * Demonstration program using COPY statements.
      * Tests copybook expansion and REDEFINES resolution.
      *
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER-RECORD.
           COPY CUSTOMER-REC.
       01 WS-RATE-TABLE.
           COPY RATE-TABLE.
       01 WS-WORK-FIELDS.
          05 WS-MONTHLY-RATE     PIC S9(3)V9(6).
          05 WS-INTEREST-AMT     PIC S9(9)V99.
          05 WS-STATUS           PIC X(10).
       PROCEDURE DIVISION.
       MAIN-PARA.
           PERFORM 1000-LOAD-CUSTOMER.
           PERFORM 2000-CALC-INTEREST.
           STOP RUN.
       1000-LOAD-CUSTOMER.
           MOVE "CUST000001" TO WS-CUSTOMER-ID.
           MOVE "SMITH JOHN" TO WS-CUSTOMER-NAME.
           MOVE "CHK" TO WS-ACCOUNT-TYPE.
           MOVE 50000.00 TO WS-BALANCE.
       2000-CALC-INTEREST.
           COMPUTE WS-MONTHLY-RATE =
               WS-RATE-VALUE / 12.
           COMPUTE WS-INTEREST-AMT =
               WS-BALANCE * WS-MONTHLY-RATE.
           IF WS-INTEREST-AMT > WS-CREDIT-LIMIT
               MOVE "OVERLIMIT" TO WS-STATUS
           ELSE
               MOVE "OK" TO WS-STATUS
           END-IF.
