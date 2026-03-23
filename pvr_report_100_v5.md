==========================================================================================
  ALETHEIA VIABILITY EXPERIMENT
==========================================================================================

  Programs tested    : 100
  Parse success      : 99/100 (99.0%)
  Generate success   : 100/100 (100.0%)
  Compile success    : 100/100 (100.0%)
  Clean (0 MR)       : 77/100 (77.0%)
  With MANUAL REVIEW : 23 programs, 50 total flags

  PVR (Parse-Verify Rate) = 77.0%

  PROGRAM                   LINES  PARSE   GEN  COMP   MR STATUS                        
  --------------------------------------------------------------------------------------
  ACCT-BALANCE-ADD             47     OK    OK    OK    0 VERIFIED                      
  ACCT-BALANCE-SUB             75     OK    OK    OK    0 VERIFIED                      
  ACCT-FEE-CALC                65     OK    OK    OK    0 VERIFIED                      
  ACCT-INTEREST               124     OK    OK    OK    0 VERIFIED                      
  ACCT-REDEFINE                22     OK    OK    OK    0 VERIFIED                      
  ALTER-DANGER                 18     OK    OK    OK    2 2 MANUAL REVIEW flags         
  ALTER-TEST                   25     OK    OK    OK    2 2 MANUAL REVIEW flags         
  APPLY-PENALTY                23     OK    OK    OK    0 VERIFIED                      
  ARITHMETIC-STRESS           102     OK    OK    OK    0 VERIFIED                      
  BATCH-MONTHLY                64     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYMENT               192     OK    OK    OK    2 2 MANUAL REVIEW flags         
  BATCH-RATE-TABLE             61     OK    OK    OK    0 VERIFIED                      
  BATCH-TOTAL-VARY             69     OK    OK    OK    0 VERIFIED                      
  CALC-INT                     18     OK    OK    OK    0 VERIFIED                      
  COMPOUND-INT                 27     OK    OK    OK    0 VERIFIED                      
  COMPUTE-CHAIN                38     OK    OK    OK    0 VERIFIED                      
  COMPUTE-COMPOUND             35     OK    OK    OK    0 VERIFIED                      
  COMPUTE-MULTI-TARGET         59     OK    OK    OK    0 VERIFIED                      
  CREDIT-SCORE                180     OK    OK    OK    0 VERIFIED                      
  CSV-PARSER                   21     OK    OK    OK    0 VERIFIED                      
  DATA-CLEANER                 20     OK    OK    OK    0 VERIFIED                      
  DEEP-NEST                    34     OK    OK    OK    0 VERIFIED                      
  DEMO-WITH-COPY               36     OK    OK    OK    0 VERIFIED                      
  DEMO_LOAN_INTEREST           93     OK    OK    OK    0 VERIFIED                      
  DISPLAY-MIX                  18     OK    OK    OK    0 VERIFIED                      
  DIV-REMAINDER                18     OK    OK    OK    0 VERIFIED                      
  DYNAMIC-TABLE                25     OK    OK    OK    0 VERIFIED                      
  EVAL-88-LEVEL                32     OK    OK    OK    0 VERIFIED                      
  EVAL-88-MULTI                38     OK    OK    OK    0 VERIFIED                      
  EVAL-88-NESTED               55     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO                    22     OK    OK    OK    0 VERIFIED                      
  EVAL-IN-VARY                 69     OK    OK    OK    0 VERIFIED                      
  EVAL-NESTED-WHEN             45     OK    OK    OK    0 VERIFIED                      
  EVAL-VARIABLE                36     OK    OK    OK    0 VERIFIED                      
  EVAL-VARY-ACCUM              72     OK    OK    OK    2 2 MANUAL REVIEW flags         
  EVAL-VARY-STRING             62     OK    OK    OK    2 2 MANUAL REVIEW flags         
  EVAL-WHEN-COMPOUND           45     OK    OK    OK    0 VERIFIED                      
  EVAL-WHEN-RANGE              37     OK    OK    OK    0 VERIFIED                      
  EVALUATE-TEST                60     OK    OK    OK    0 VERIFIED                      
  EXEC-SQL-TEST                45     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND                  21     OK    OK    OK    0 VERIFIED                      
  GOTO-FLOW                    26     OK    OK    OK    0 VERIFIED                      
  INIT-TEST                    22     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV                 12     OK    OK    OK    0 VERIFIED                      
  INTR-CALC-3270               37   FAIL    OK    OK    0 VERIFIED                      
  INVOICE-GEN                  59     OK    OK    OK    0 VERIFIED                      
  LOAN-AMORT-CALC              70     OK    OK    OK    0 VERIFIED                      
  LOAN-PENALTY                 69     OK    OK    OK    2 2 MANUAL REVIEW flags         
  LOAN-SIMPLE-INT              46     OK    OK    OK    0 VERIFIED                      
  MAIN-LOAN                    34     OK    OK    OK    0 VERIFIED                      
  MONTHLY-TOTALS               28     OK    OK    OK    0 VERIFIED                      
  MOVE-CORR-ACCT               37     OK    OK    OK    0 VERIFIED                      
  MOVE-CORR-EMPTY              30     OK    OK    OK    0 VERIFIED                      
  MOVE-CORR-MIXED              47     OK    OK    OK    0 VERIFIED                      
  MSG-BUILDER                  18     OK    OK    OK    0 VERIFIED                      
  NESTED-EVAL                  38     OK    OK    OK    0 VERIFIED                      
  PAYROLL-CALC                 47     OK    OK    OK    0 VERIFIED                      
  PERF-THRU-BRANCH             53     OK    OK    OK    0 VERIFIED                      
  PERF-THRU-GOTO               48     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PERF-THRU-SEQ                46     OK    OK    OK    0 VERIFIED                      
  PERF-TIMES-COND              58     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PERF-TIMES-NEST              51     OK    OK    OK    0 VERIFIED                      
  PERF-TIMES-PARA              48     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PERF-UNTIL-88                46     OK    OK    OK    0 VERIFIED                      
  PERF-UNTIL-AND               55     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PERF-UNTIL-OR                49     OK    OK    OK    0 VERIFIED                      
  PERFORM-VARYING-TEST         71     OK    OK    OK    0 VERIFIED                      
  REFMOD-CONDITION             33     OK    OK    OK    0 VERIFIED                      
  REFMOD-DATE-PARSE            33     OK    OK    OK    0 VERIFIED                      
  REFMOD-WRITE                 67     OK    OK    OK    2 2 MANUAL REVIEW flags         
  REPEAT-TIMES                 16     OK    OK    OK    0 VERIFIED                      
  RPT-LINE-BUILD               52     OK    OK    OK    2 2 MANUAL REVIEW flags         
  RPT-STRING-HDR               45     OK    OK    OK    0 VERIFIED                      
  RPT-SUMMARY                  94     OK    OK    OK    0 VERIFIED                      
  STATUS-CHECKER               35     OK    OK    OK    0 VERIFIED                      
  STRESS-DEEP-NEST             89     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-DISPLAY-MIX           77     OK    OK    OK    0 VERIFIED                      
  STRESS-DIV-REMAINDER         73     OK    OK    OK    4 4 MANUAL REVIEW flags         
  STRESS-EVAL-PERFORM          77     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-EXEC-SQL              25     OK    OK    OK    0 VERIFIED                      
  STRESS-GOTO-THRU             86     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-INIT-GROUP            60     OK    OK    OK    0 VERIFIED                      
  STRESS-INSPECT-BOTH          48     OK    OK    OK    0 VERIFIED                      
  STRESS-MIXED-COMP            78     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-NAME-COLLISION        76     OK    OK    OK    0 VERIFIED                      
  STRESS-PIC-OVERFLOW          60     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-REDEFINES-COMP3       71     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-STRING-OVERFLOW       66     OK    OK    OK    4 4 MANUAL REVIEW flags         
  STRESS-THRU-GOTO-OUT         64     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-UNSTRING              61     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRING-PTR                   16     OK    OK    OK    0 VERIFIED                      
  TXN-APPROVE-FLOW             82     OK    OK    OK    0 VERIFIED                      
  TXN-BATCH-CHECK              61     OK    OK    OK    0 VERIFIED                      
  TXN-VALIDATE-IF              64     OK    OK    OK    0 VERIFIED                      
  TYPE-CHECKER                 25     OK    OK    OK    0 VERIFIED                      
  UNSTR-COMPLEX                20     OK    OK    OK    2 2 MANUAL REVIEW flags         
  VARY-AFTER-ACCUM             41     OK    OK    OK    0 VERIFIED                      
  VARY-AFTER-MATRIX            30     OK    OK    OK    0 VERIFIED                      
  VARY-AFTER-STEP              28     OK    OK    OK    0 VERIFIED                      
  WIRE-VALIDATE               130     OK    OK    OK    0 VERIFIED                      

  CONSTRUCT FREQUENCY (across all programs)
  --------------------------------------------------
  STOP RUN                   97 ########################################
  MOVE                       87 ########################################
  DISPLAY                    63 ########################################
  IF/ELSE                    46 ########################################
  COMPUTE                    42 ########################################
  ADD                        40 ########################################
  PERFORM                    39 #######################################
  COMP-3                     33 #################################
  88-level                   20 ####################
  STRING                     15 ###############
  SUBTRACT                   14 ##############
  EVALUATE TRUE              13 #############
  GO TO                      13 #############
  PERFORM TIMES              12 ############
  OCCURS                     11 ###########
  MULTIPLY                   11 ###########
  EVALUATE variable          10 ##########
  INSPECT TALLYING           10 ##########
  UNSTRING                   10 ##########
  PERFORM VARYING             9 #########
  EVALUATE ALSO               9 #########
  88 THRU                     9 #########
  DIVIDE                      8 ########
  STRING POINTER              8 ########
  ALTER                       6 ######
  INITIALIZE                  6 ######
  PERFORM THRU                6 ######
  OCCURS DEPENDING            5 #####
  DELIMITER IN                5 #####
  INSPECT CONVERTING          5 #####
  GO TO DEPENDING             5 #####
  INSPECT REPLACING           4 ####
  REDEFINES                   3 ###
  DIVIDE REMAINDER            3 ###
  EXEC SQL                    2 ##
  COPY                        1 #
  IS ALPHABETIC               1 #
  IS NUMERIC                  1 #

  MANUAL REVIEW FLAGS (50 total)
  --------------------------------------------------
  ALTER-DANGER: # MANUAL REVIEW: ALTER 1000-DISPATCH TO PROCEED TO 3000-OVERRIDE
  ALTER-DANGER: # ALTER 1000-DISPATCH                            # MANUAL REVIEW                                [FAI
  ALTER-TEST: # MANUAL REVIEW: ALTER CALC-DISPATCH TO PROCEED TO CALC-COMPOUND
  ALTER-TEST: # ALTER CALC-DISPATCH                            # MANUAL REVIEW                                [FAI
  BATCH-PAYMENT: # MANUAL REVIEW: MULTIPLYWS-LATE-FEEBY
  BATCH-PAYMENT: # MULTIPLYWS-LATE-FEEBY                          # MANUAL REVIEW                                [FAI
  EVAL-VARY-ACCUM: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  EVAL-VARY-ACCUM: # UNSTRING WS-TXN-LINE                           # MANUAL REVIEW                                [FAI
  EVAL-VARY-STRING: # MANUAL REVIEW: STRING with OVERFLOW
  EVAL-VARY-STRING: # STRING ... INTO WS-REPORT-LINE                 # MANUAL REVIEW                                [FAI
  LOAN-PENALTY: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  LOAN-PENALTY: # UNSTRING WS-PENALTY-CODE                       # MANUAL REVIEW                                [FAI
  PERF-THRU-GOTO: # MANUAL REVIEW: ALTER 2000-DISPATCH TO PROCEED TO 2100-PATH-B
  PERF-THRU-GOTO: # ALTER 2000-DISPATCH                            # MANUAL REVIEW                                [FAI
  PERF-TIMES-COND: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  PERF-TIMES-COND: # UNSTRING WS-INPUT-LINE                         # MANUAL REVIEW                                [FAI
  PERF-TIMES-PARA: # MANUAL REVIEW: STRING with OVERFLOW
  PERF-TIMES-PARA: # STRING ... INTO WS-REPORT                      # MANUAL REVIEW                                [FAI
  PERF-UNTIL-AND: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  PERF-UNTIL-AND: # SORT SORT-FILE PROCEDURE                       # MANUAL REVIEW                                [FAI
  REFMOD-WRITE: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  REFMOD-WRITE: # SORT SORT-FILE PROCEDURE                       # MANUAL REVIEW                                [FAI
  RPT-LINE-BUILD: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  RPT-LINE-BUILD: # UNSTRING WS-RAW-RECORD                         # MANUAL REVIEW                                [FAI
  STRESS-DEEP-NEST: # MANUAL REVIEW: ALTER 2000-DYNAMIC-JUMP TO PROCEED TO 3000-PATH-C
  STRESS-DEEP-NEST: # ALTER 2000-DYNAMIC-JUMP                        # MANUAL REVIEW                                [FAI
  STRESS-DIV-REMAINDER: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  STRESS-DIV-REMAINDER: # MANUAL REVIEW: READMASTER-FILE
  STRESS-DIV-REMAINDER: # MANUAL REVIEW: REWRITEMASTER-REC
  STRESS-DIV-REMAINDER: # SORT SORT-WORK PROCEDURE                       # MANUAL REVIEW                                [FAI
  STRESS-EVAL-PERFORM: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  STRESS-EVAL-PERFORM: # SORT SORT-FILE PROCEDURE                       # MANUAL REVIEW                                [FAI
  STRESS-GOTO-THRU: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  STRESS-GOTO-THRU: # SORT SORT-FILE PROCEDURE                       # MANUAL REVIEW                                [FAI
  STRESS-MIXED-COMP: # MANUAL REVIEW: READIDX-FILEKEYISIDX-KEY
  STRESS-MIXED-COMP: # MANUAL REVIEW: REWRITEIDX-REC
  STRESS-PIC-OVERFLOW: # MANUAL REVIEW: ALTER 5000-JUMP TO PROCEED TO 6000-OVERFLOW-A
  STRESS-PIC-OVERFLOW: # ALTER 5000-JUMP                                # MANUAL REVIEW                                [FAI
  STRESS-REDEFINES-COMP3: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  STRESS-REDEFINES-COMP3: # UNSTRING WS-PARSE-INPUT                        # MANUAL REVIEW                                [FAI
  STRESS-STRING-OVERFLOW: # MANUAL REVIEW: STRING with OVERFLOW
  STRESS-STRING-OVERFLOW: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  STRESS-STRING-OVERFLOW: # STRING ... INTO WS-RESULT                      # MANUAL REVIEW                                [FAI
  STRESS-STRING-OVERFLOW: # UNSTRING WS-PARSE-IN                           # MANUAL REVIEW                                [FAI
  STRESS-THRU-GOTO-OUT: # MANUAL REVIEW: ALTER 4000-DYNAMIC TO PROCEED TO 5000-ESCAPE
  STRESS-THRU-GOTO-OUT: # ALTER 4000-DYNAMIC                             # MANUAL REVIEW                                [FAI
  STRESS-UNSTRING: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  STRESS-UNSTRING: # UNSTRING WS-INPUT                              # MANUAL REVIEW                                [FAI
  UNSTR-COMPLEX: # MANUAL REVIEW: UNSTRING with OR/POINTER/TALLYING/DELIMITER-IN/COUNT-IN
  UNSTR-COMPLEX: # UNSTRING WS-INPUT                              # MANUAL REVIEW                                [FAI

==========================================================================================
  PVR = 77.0%  (77 clean / 100 tested)
==========================================================================================
