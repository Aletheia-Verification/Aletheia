       IDENTIFICATION DIVISION.
       PROGRAM-ID. EXEC-SQL-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ACCOUNT-ID       PIC 9(10).
       01  WS-BALANCE           PIC S9(13)V99.
       01  WS-INTEREST-RATE     PIC S9(3)V9(4).
       01  WS-CUSTOMER-NAME     PIC X(40).
       01  WS-SQLCODE           PIC S9(9) COMP.
       01  WS-NEW-BALANCE       PIC S9(13)V99.

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           MOVE 1001 TO WS-ACCOUNT-ID.

           EXEC SQL
               SELECT BALANCE, INTEREST_RATE, CUSTOMER_NAME
               INTO :WS-BALANCE, :WS-INTEREST-RATE, :WS-CUSTOMER-NAME
               FROM ACCOUNTS
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC.

           IF WS-SQLCODE NOT = 0
               DISPLAY "DB ERROR: " WS-SQLCODE
               STOP RUN
           END-IF.

           COMPUTE WS-NEW-BALANCE =
               WS-BALANCE * (1 + WS-INTEREST-RATE).

           EXEC SQL
               UPDATE ACCOUNTS
               SET BALANCE = :WS-NEW-BALANCE
               WHERE ACCOUNT_ID = :WS-ACCOUNT-ID
           END-EXEC.

           EXEC CICS
               SEND MAP('BALMAP')
               MAPSET('BALMSET')
               FROM(WS-NEW-BALANCE)
               ERASE
           END-EXEC.

           STOP RUN.
