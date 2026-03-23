       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-1042S-FBAR.
      *================================================================
      * Form 1042-S / FBAR Reporting Generator
      * Processes foreign person income withholding records,
      * generates 1042-S forms and FBAR threshold checks.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RECIPIENT.
           05 WS-RCP-NAME             PIC X(30).
           05 WS-RCP-TIN              PIC X(9).
           05 WS-RCP-COUNTRY          PIC X(3).
           05 WS-RCP-STATUS           PIC X(2).
               88 WS-NRA              VALUE 'NR'.
               88 WS-FOREIGN-CORP     VALUE 'FC'.
               88 WS-FOREIGN-TRUST    VALUE 'FT'.
               88 WS-FOREIGN-PART     VALUE 'FP'.
       01 WS-INCOME-TABLE.
           05 WS-INC-ENTRY OCCURS 12
              ASCENDING KEY IS WS-IE-CODE
              INDEXED BY WS-IE-IDX.
               10 WS-IE-CODE          PIC X(2).
               10 WS-IE-DESC          PIC X(20).
               10 WS-IE-GROSS         PIC S9(9)V99 COMP-3.
               10 WS-IE-TREATY-RATE   PIC S9(1)V9(4) COMP-3.
               10 WS-IE-STAT-RATE     PIC S9(1)V9(4) COMP-3.
               10 WS-IE-EXEMPT-AMT    PIC S9(9)V99 COMP-3.
               10 WS-IE-TAXABLE       PIC S9(9)V99 COMP-3.
               10 WS-IE-TAX-WITHHELD  PIC S9(7)V99 COMP-3.
       01 WS-INC-COUNT                PIC 9(2) VALUE 12.
       01 WS-TREATY-DATA.
           05 WS-TREATY-COUNTRY       PIC X(3).
           05 WS-TREATY-EXISTS        PIC X(1).
               88 WS-HAS-TREATY       VALUE 'Y'.
           05 WS-TREATY-ARTICLE       PIC X(5).
       01 WS-TOTALS.
           05 WS-TOTAL-GROSS          PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-TAXABLE        PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-WITHHELD       PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-EXEMPT         PIC S9(9)V99 COMP-3.
       01 WS-FBAR-FIELDS.
           05 WS-FOREIGN-ACCT-BAL     PIC S9(11)V99 COMP-3.
           05 WS-FBAR-THRESHOLD       PIC S9(11)V99 COMP-3
               VALUE 10000.00.
           05 WS-FBAR-REQUIRED        PIC X(1).
               88 WS-NEEDS-FBAR       VALUE 'Y'.
               88 WS-NO-FBAR          VALUE 'N'.
       01 WS-FORM-1042S.
           05 WS-FORM-SEQUENCE        PIC 9(6).
           05 WS-WITHHOLDING-AGENT    PIC X(30).
           05 WS-WA-EIN               PIC X(9).
           05 WS-CHAPTER-IND          PIC 9(1).
               88 WS-CHAPTER-3        VALUE 3.
               88 WS-CHAPTER-4        VALUE 4.
       01 WS-WORK-FIELDS.
           05 WS-APPLICABLE-RATE      PIC S9(1)V9(4) COMP-3.
           05 WS-SEARCH-CODE          PIC X(2).
       01 WS-SIGN-WITHHELD
           PIC S9(7)V99 SIGN IS LEADING SEPARATE.
       01 WS-PROCESS-DATE             PIC 9(8).
       01 WS-DIVIDE-FIELDS.
           05 WS-AVG-RATE             PIC S9(1)V9(4) COMP-3.
           05 WS-RATE-REMAINDER       PIC S9(1)V9(4) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-WITHHOLDING
           PERFORM 3000-TOTAL-INCOME
           PERFORM 4000-CHECK-FBAR
           PERFORM 5000-BUILD-1042S
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-GROSS
           MOVE 0 TO WS-TOTAL-TAXABLE
           MOVE 0 TO WS-TOTAL-WITHHELD
           MOVE 0 TO WS-TOTAL-EXEMPT
           SET WS-NO-FBAR TO TRUE
           MOVE 0 TO WS-FORM-SEQUENCE.
       2000-CALC-WITHHOLDING.
           PERFORM VARYING WS-IE-IDX FROM 1 BY 1
               UNTIL WS-IE-IDX > WS-INC-COUNT
               IF WS-IE-GROSS(WS-IE-IDX) > 0
                   IF WS-HAS-TREATY
                       MOVE WS-IE-TREATY-RATE(WS-IE-IDX)
                           TO WS-APPLICABLE-RATE
                   ELSE
                       MOVE WS-IE-STAT-RATE(WS-IE-IDX)
                           TO WS-APPLICABLE-RATE
                   END-IF
                   COMPUTE WS-IE-TAXABLE(WS-IE-IDX) =
                       WS-IE-GROSS(WS-IE-IDX) -
                       WS-IE-EXEMPT-AMT(WS-IE-IDX)
                   IF WS-IE-TAXABLE(WS-IE-IDX) < 0
                       MOVE 0
                           TO WS-IE-TAXABLE(WS-IE-IDX)
                   END-IF
                   COMPUTE WS-IE-TAX-WITHHELD(WS-IE-IDX) =
                       WS-IE-TAXABLE(WS-IE-IDX) *
                       WS-APPLICABLE-RATE
               END-IF
           END-PERFORM.
       3000-TOTAL-INCOME.
           PERFORM VARYING WS-IE-IDX FROM 1 BY 1
               UNTIL WS-IE-IDX > WS-INC-COUNT
               ADD WS-IE-GROSS(WS-IE-IDX)
                   TO WS-TOTAL-GROSS
               ADD WS-IE-TAXABLE(WS-IE-IDX)
                   TO WS-TOTAL-TAXABLE
               ADD WS-IE-TAX-WITHHELD(WS-IE-IDX)
                   TO WS-TOTAL-WITHHELD
               ADD WS-IE-EXEMPT-AMT(WS-IE-IDX)
                   TO WS-TOTAL-EXEMPT
           END-PERFORM
           COMPUTE WS-SIGN-WITHHELD = WS-TOTAL-WITHHELD
           IF WS-TOTAL-TAXABLE > 0
               DIVIDE WS-TOTAL-WITHHELD
                   BY WS-TOTAL-TAXABLE
                   GIVING WS-AVG-RATE
                   REMAINDER WS-RATE-REMAINDER
           END-IF.
       4000-CHECK-FBAR.
           IF WS-FOREIGN-ACCT-BAL > WS-FBAR-THRESHOLD
               SET WS-NEEDS-FBAR TO TRUE
           END-IF.
       5000-BUILD-1042S.
           ADD 1 TO WS-FORM-SEQUENCE
           IF WS-NRA OR WS-FOREIGN-CORP
               SET WS-CHAPTER-3 TO TRUE
           ELSE
               SET WS-CHAPTER-4 TO TRUE
           END-IF.
       6000-DISPLAY-REPORT.
           DISPLAY "1042-S / FBAR REPORT"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "RECIPIENT: " WS-RCP-NAME
           DISPLAY "COUNTRY: " WS-RCP-COUNTRY
           DISPLAY "STATUS: " WS-RCP-STATUS
           DISPLAY "GROSS INCOME: " WS-TOTAL-GROSS
           DISPLAY "TAXABLE: " WS-TOTAL-TAXABLE
           DISPLAY "WITHHELD: " WS-SIGN-WITHHELD
           DISPLAY "EXEMPT: " WS-TOTAL-EXEMPT
           IF WS-HAS-TREATY
               DISPLAY "TREATY: " WS-TREATY-COUNTRY
                   " ART " WS-TREATY-ARTICLE
           END-IF
           DISPLAY "FORM SEQ: " WS-FORM-SEQUENCE
           DISPLAY "CHAPTER: " WS-CHAPTER-IND
           IF WS-NEEDS-FBAR
               DISPLAY "FBAR FILING REQUIRED"
               DISPLAY "FOREIGN BALANCE: "
                   WS-FOREIGN-ACCT-BAL
           END-IF.
