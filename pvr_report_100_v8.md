line 158:15 no viable alternative at input 'IF WS-LATE-DAYS > 30\n                   MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE\n                       GIVING WS-LATE-FEE\n                   MULTIPLY WS-LATE-FEE BY 2\n               ELSE'
line 158:15 no viable alternative at input 'MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE\n                       GIVING WS-LATE-FEE\n                   MULTIPLY WS-LATE-FEE BY 2\n               ELSE'
line 158:15 no viable alternative at input '2\n               ELSE'
line 158:15 mismatched input 'ELSE' expecting SECTION
line 159:43 mismatched input 'BY' expecting SECTION
line 160:23 mismatched input 'GIVING' expecting SECTION
line 161:15 mismatched input 'END-IF' expecting SECTION
line 162:31 mismatched input 'TO' expecting SECTION
line 163:11 mismatched input 'END-IF' expecting SECTION
line 10:17 mismatched input '*' expecting <EOF>
line 3:17 mismatched input 'J' expecting <EOF>
line 30:15 no viable alternative at input 'SUBTRACT 40 FROM WS-HOURS\n                   GIVING WS-OVERTIME-HRS\n               MULTIPLY WS-OVERTIME-HRS BY WS-RATE\n                   GIVING WS-OVERTIME-PAY\n               MULTIPLY WS-OVERTIME-PAY BY 1.5\n               ADD'
line 30:15 mismatched input 'ADD' expecting GIVING
line 31:11 no viable alternative at input 'WS-GROSS-PAY\n           END-IF'
line 33:17 no viable alternative at input 'GO TO DEPENDING'
line 34:15 mismatched input '2100-PATH-A' expecting SECTION
line 34:27 mismatched input '2100-PATH-B' expecting SECTION
line 34:39 mismatched input '2100-PATH-C' expecting SECTION
line 65:15 no viable alternative at input 'EXIT PERFORM\n               END-RETURN'
line 65:15 extraneous input 'END-RETURN' expecting {ABORT, ACCEPT, ADD, ADDRESS, ALTER, AS, ASCII, ASSOCIATED_DATA, ASSOCIATED_DATA_LENGTH, ATTRIBUTE, AUTO, AUTO_SKIP, BACKGROUND_COLOR, BACKGROUND_COLOUR, BEEP, BELL, BINARY, BIT, BLINK, BOUNDS, CALL, CANCEL, CAPABLE, CCSVERSION, CHANGED, CHANNEL, CLOSE, CLOSE_DISPOSITION, COBOL, COMMITMENT, COMPUTE, CONTINUE, CONTROL_POINT, CONVENTION, CRUNCH, CURSOR, DATE, DAY, DAY_OF_WEEK, DEBUG_CONTENTS, DEBUG_ITEM, DEBUG_LINE, DEBUG_NAME, DEBUG_SUB_1, DEBUG_SUB_2, DEBUG_SUB_3, DEFAULT, DEFAULT_DISPLAY, DEFINITION, DELETE, DFHRESP, DFHVALUE, DISABLE, DISK, DISPLAY, DIVIDE, DONTCARE, DOUBLE, EBCDIC, EMPTY_CHECK, ENABLE, END_PERFORM, ENTER, ENTRY, ENTRY_PROCEDURE, ERASE, EOL, EOS, ESCAPE, EVALUATE, EVENT, EXCLUSIVE, EXHIBIT, EXIT, EXPORT, EXTENDED, FOREGROUND_COLOR, FOREGROUND_COLOUR, FULL, FUNCTION, FUNCTIONNAME, FUNCTION_POINTER, GENERATE, GOBACK, GO, GRID, HIGHLIGHT, IF, IMPLICIT, IMPORT, INITIALIZE, INITIATE, INSPECT, INTEGER, KEPT, KEYBOARD, LANGUAGE, LB, LD, LEFTLINE, LENGTH, LENGTH_CHECK, LIBACCESS, LIBPARAMETER, LIBRARY, LINAGE_COUNTER, LINE_COUNTER, LIST, LOCAL, LONG_DATE, LONG_TIME, LOWER, LOWLIGHT, MERGE, MMDDYYYY, MOVE, MULTIPLY, NAMED, NATIONAL, NATIONAL_EDITED, NETWORK, NO_ECHO, NUMERIC_DATE, NUMERIC_TIME, ODT, OPEN, ORDERLY, OVERLINE, OWN, PAGE_COUNTER, PASSWORD, PERFORM, PORT, PRINTER, PRIVATE, PROCESS, PROGRAM, PROMPT, PURGE, READER, REMOTE, REAL, READ, RECEIVE, RECEIVED, RECURSIVE, REF, RELEASE, REMOVE, REQUIRED, REVERSE_VIDEO, RETURN, RETURN_CODE, REWRITE, SAVE, SEARCH, SECURE, SEND, SET, SHARED, SHAREDBYALL, SHAREDBYRUNUNIT, SHARING, SHIFT_IN, SHIFT_OUT, SHORT_DATE, SORT, SORT_CONTROL, SORT_CORE_SIZE, SORT_FILE_SIZE, SORT_MESSAGE, SORT_MODE_SIZE, SORT_RETURN, START, STOP, STRING, SUBTRACT, SYMBOL, TALLY, TASK, TERMINATE, TEST, THREAD, THREAD_LOCAL, TIME, TIMER, TODAYS_DATE, TODAYS_NAME, TRUNCATED, TYPEDEF, UNDERLINE, UNSTRING, UNTIL, VARYING, VIRTUAL, WAIT, WHEN_COMPILED, WITH, WRITE, YEAR, YYYYMMDD, YYYYDDD, ZERO_FILL, '66', '77', '88', INTEGERLITERAL, IDENTIFIER, EXECCICSLINE, EXECSQLIMSLINE, EXECSQLLINE}
line 67:22 extraneous input '.\n' expecting {ACCEPT, ADD, ALTER, CALL, CANCEL, CLOSE, COMPUTE, CONTINUE, DELETE, DISABLE, DISPLAY, DIVIDE, ENABLE, END_PERFORM, ENTRY, EVALUATE, EXHIBIT, EXIT, GENERATE, GOBACK, GO, IF, INITIALIZE, INITIATE, INSPECT, MERGE, MOVE, MULTIPLY, OPEN, PERFORM, PURGE, READ, RECEIVE, RELEASE, RETURN, REWRITE, SEARCH, SEND, SET, SORT, START, STOP, STRING, SUBTRACT, TERMINATE, UNSTRING, WRITE, EXECCICSLINE, EXECSQLIMSLINE, EXECSQLLINE}
<RPT-LINE-BUILD>:44: SyntaxWarning: invalid escape sequence '\|'
line 34:20 extraneous input 'ALSO' expecting {ABORT, ADDRESS, ALL, AS, ASCII, ASSOCIATED_DATA, ASSOCIATED_DATA_LENGTH, ATTRIBUTE, AUTO, AUTO_SKIP, BACKGROUND_COLOR, BACKGROUND_COLOUR, BEEP, BELL, BINARY, BIT, BLINK, BOUNDS, CAPABLE, CCSVERSION, CHANGED, CHANNEL, CLOSE_DISPOSITION, COBOL, COMMITMENT, CONTROL_POINT, CONVENTION, CRUNCH, CURSOR, DATE, DAY, DAY_OF_WEEK, DEBUG_CONTENTS, DEBUG_ITEM, DEBUG_LINE, DEBUG_NAME, DEBUG_SUB_1, DEBUG_SUB_2, DEBUG_SUB_3, DEFAULT, DEFAULT_DISPLAY, DEFINITION, DFHRESP, DFHVALUE, DISK, DONTCARE, DOUBLE, EBCDIC, EMPTY_CHECK, ENTER, ENTRY_PROCEDURE, ERASE, EOL, EOS, ESCAPE, EVENT, EXCLUSIVE, EXPORT, EXTENDED, FALSE, FOREGROUND_COLOR, FOREGROUND_COLOUR, FULL, FUNCTION, FUNCTIONNAME, FUNCTION_POINTER, GRID, HIGHLIGHT, HIGH_VALUE, HIGH_VALUES, IMPLICIT, IMPORT, INTEGER, KEPT, KEYBOARD, LANGUAGE, LB, LD, LEFTLINE, LENGTH, LENGTH_CHECK, LIBACCESS, LIBPARAMETER, LIBRARY, LINAGE_COUNTER, LINE_COUNTER, LIST, LOCAL, LONG_DATE, LONG_TIME, LOWER, LOWLIGHT, LOW_VALUE, LOW_VALUES, MMDDYYYY, NAMED, NATIONAL, NATIONAL_EDITED, NETWORK, NO_ECHO, NOT, NULL_, NULLS, NUMERIC_DATE, NUMERIC_TIME, ODT, ORDERLY, OVERLINE, OWN, PAGE_COUNTER, PASSWORD, PORT, PRINTER, PRIVATE, PROCESS, PROGRAM, PROMPT, QUOTE, QUOTES, READER, REMOTE, REAL, RECEIVED, RECURSIVE, REF, REMOVE, REQUIRED, REVERSE_VIDEO, RETURN_CODE, SAVE, SECURE, SHARED, SHAREDBYALL, SHAREDBYRUNUNIT, SHARING, SHIFT_IN, SHIFT_OUT, SHORT_DATE, SORT_CONTROL, SORT_CORE_SIZE, SORT_FILE_SIZE, SORT_MESSAGE, SORT_MODE_SIZE, SORT_RETURN, SPACE, SPACES, SYMBOL, TALLY, TASK, THREAD, THREAD_LOCAL, TIME, TIMER, TODAYS_DATE, TODAYS_NAME, TRUE, TRUNCATED, TYPEDEF, UNDERLINE, VIRTUAL, WAIT, WHEN_COMPILED, YEAR, YYYYMMDD, YYYYDDD, ZERO, ZERO_FILL, ZEROS, ZEROES, '(', '-', '+', NONNUMERICLITERAL, '66', '77', '88', INTEGERLITERAL, NUMERICLITERAL, IDENTIFIER}
line 53:20 extraneous input 'ALSO' expecting {ABORT, ADDRESS, ALL, AS, ASCII, ASSOCIATED_DATA, ASSOCIATED_DATA_LENGTH, ATTRIBUTE, AUTO, AUTO_SKIP, BACKGROUND_COLOR, BACKGROUND_COLOUR, BEEP, BELL, BINARY, BIT, BLINK, BOUNDS, CAPABLE, CCSVERSION, CHANGED, CHANNEL, CLOSE_DISPOSITION, COBOL, COMMITMENT, CONTROL_POINT, CONVENTION, CRUNCH, CURSOR, DATE, DAY, DAY_OF_WEEK, DEBUG_CONTENTS, DEBUG_ITEM, DEBUG_LINE, DEBUG_NAME, DEBUG_SUB_1, DEBUG_SUB_2, DEBUG_SUB_3, DEFAULT, DEFAULT_DISPLAY, DEFINITION, DFHRESP, DFHVALUE, DISK, DONTCARE, DOUBLE, EBCDIC, EMPTY_CHECK, ENTER, ENTRY_PROCEDURE, ERASE, EOL, EOS, ESCAPE, EVENT, EXCLUSIVE, EXPORT, EXTENDED, FALSE, FOREGROUND_COLOR, FOREGROUND_COLOUR, FULL, FUNCTION, FUNCTIONNAME, FUNCTION_POINTER, GRID, HIGHLIGHT, HIGH_VALUE, HIGH_VALUES, IMPLICIT, IMPORT, INTEGER, KEPT, KEYBOARD, LANGUAGE, LB, LD, LEFTLINE, LENGTH, LENGTH_CHECK, LIBACCESS, LIBPARAMETER, LIBRARY, LINAGE_COUNTER, LINE_COUNTER, LIST, LOCAL, LONG_DATE, LONG_TIME, LOWER, LOWLIGHT, LOW_VALUE, LOW_VALUES, MMDDYYYY, NAMED, NATIONAL, NATIONAL_EDITED, NETWORK, NO_ECHO, NOT, NULL_, NULLS, NUMERIC_DATE, NUMERIC_TIME, ODT, ORDERLY, OVERLINE, OWN, PAGE_COUNTER, PASSWORD, PORT, PRINTER, PRIVATE, PROCESS, PROGRAM, PROMPT, QUOTE, QUOTES, READER, REMOTE, REAL, RECEIVED, RECURSIVE, REF, REMOVE, REQUIRED, REVERSE_VIDEO, RETURN_CODE, SAVE, SECURE, SHARED, SHAREDBYALL, SHAREDBYRUNUNIT, SHARING, SHIFT_IN, SHIFT_OUT, SHORT_DATE, SORT_CONTROL, SORT_CORE_SIZE, SORT_FILE_SIZE, SORT_MESSAGE, SORT_MODE_SIZE, SORT_RETURN, SPACE, SPACES, SYMBOL, TALLY, TASK, THREAD, THREAD_LOCAL, TIME, TIMER, TODAYS_DATE, TODAYS_NAME, TRUE, TRUNCATED, TYPEDEF, UNDERLINE, VIRTUAL, WAIT, WHEN_COMPILED, YEAR, YYYYMMDD, YYYYDDD, ZERO, ZERO_FILL, ZEROS, ZEROES, '(', '-', '+', NONNUMERICLITERAL, '66', '77', '88', INTEGERLITERAL, NUMERICLITERAL, IDENTIFIER}
line 38:20 extraneous input 'ALSO' expecting {ABORT, ADDRESS, ALL, AS, ASCII, ASSOCIATED_DATA, ASSOCIATED_DATA_LENGTH, ATTRIBUTE, AUTO, AUTO_SKIP, BACKGROUND_COLOR, BACKGROUND_COLOUR, BEEP, BELL, BINARY, BIT, BLINK, BOUNDS, CAPABLE, CCSVERSION, CHANGED, CHANNEL, CLOSE_DISPOSITION, COBOL, COMMITMENT, CONTROL_POINT, CONVENTION, CRUNCH, CURSOR, DATE, DAY, DAY_OF_WEEK, DEBUG_CONTENTS, DEBUG_ITEM, DEBUG_LINE, DEBUG_NAME, DEBUG_SUB_1, DEBUG_SUB_2, DEBUG_SUB_3, DEFAULT, DEFAULT_DISPLAY, DEFINITION, DFHRESP, DFHVALUE, DISK, DONTCARE, DOUBLE, EBCDIC, EMPTY_CHECK, ENTER, ENTRY_PROCEDURE, ERASE, EOL, EOS, ESCAPE, EVENT, EXCLUSIVE, EXPORT, EXTENDED, FALSE, FOREGROUND_COLOR, FOREGROUND_COLOUR, FULL, FUNCTION, FUNCTIONNAME, FUNCTION_POINTER, GRID, HIGHLIGHT, HIGH_VALUE, HIGH_VALUES, IMPLICIT, IMPORT, INTEGER, KEPT, KEYBOARD, LANGUAGE, LB, LD, LEFTLINE, LENGTH, LENGTH_CHECK, LIBACCESS, LIBPARAMETER, LIBRARY, LINAGE_COUNTER, LINE_COUNTER, LIST, LOCAL, LONG_DATE, LONG_TIME, LOWER, LOWLIGHT, LOW_VALUE, LOW_VALUES, MMDDYYYY, NAMED, NATIONAL, NATIONAL_EDITED, NETWORK, NO_ECHO, NOT, NULL_, NULLS, NUMERIC_DATE, NUMERIC_TIME, ODT, ORDERLY, OVERLINE, OWN, PAGE_COUNTER, PASSWORD, PORT, PRINTER, PRIVATE, PROCESS, PROGRAM, PROMPT, QUOTE, QUOTES, READER, REMOTE, REAL, RECEIVED, RECURSIVE, REF, REMOVE, REQUIRED, REVERSE_VIDEO, RETURN_CODE, SAVE, SECURE, SHARED, SHAREDBYALL, SHAREDBYRUNUNIT, SHARING, SHIFT_IN, SHIFT_OUT, SHORT_DATE, SORT_CONTROL, SORT_CORE_SIZE, SORT_FILE_SIZE, SORT_MESSAGE, SORT_MODE_SIZE, SORT_RETURN, SPACE, SPACES, SYMBOL, TALLY, TASK, THREAD, THREAD_LOCAL, TIME, TIMER, TODAYS_DATE, TODAYS_NAME, TRUE, TRUNCATED, TYPEDEF, UNDERLINE, VIRTUAL, WAIT, WHEN_COMPILED, YEAR, YYYYMMDD, YYYYDDD, ZERO, ZERO_FILL, ZEROS, ZEROES, '(', '-', '+', NONNUMERICLITERAL, '66', '77', '88', INTEGERLITERAL, NUMERICLITERAL, IDENTIFIER}
<STRESS-STRING-OVERFLOW>:65: SyntaxWarning: invalid escape sequence '\|'
<STRESS-UNSTRING>:55: SyntaxWarning: invalid escape sequence '\|'
<WIRE-VALIDATE>:86: SyntaxWarning: invalid escape sequence '\|'
==========================================================================================
  ALETHEIA VIABILITY EXPERIMENT
==========================================================================================

  Programs tested    : 100
  Parse success      : 99/100 (99.0%)
  Generate success   : 100/100 (100.0%)
  Compile success    : 100/100 (100.0%)
  Clean (0 MR)       : 87/100 (87.0%)
  With MANUAL REVIEW : 13 programs, 28 total flags

  PVR (Parse-Verify Rate) = 87.0%

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
  EVAL-VARY-ACCUM              72     OK    OK    OK    0 VERIFIED                      
  EVAL-VARY-STRING             62     OK    OK    OK    0 VERIFIED                      
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
  LOAN-PENALTY                 69     OK    OK    OK    0 VERIFIED                      
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
  PERF-TIMES-COND              58     OK    OK    OK    0 VERIFIED                      
  PERF-TIMES-NEST              51     OK    OK    OK    0 VERIFIED                      
  PERF-TIMES-PARA              48     OK    OK    OK    0 VERIFIED                      
  PERF-UNTIL-88                46     OK    OK    OK    0 VERIFIED                      
  PERF-UNTIL-AND               55     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PERF-UNTIL-OR                49     OK    OK    OK    0 VERIFIED                      
  PERFORM-VARYING-TEST         71     OK    OK    OK    0 VERIFIED                      
  REFMOD-CONDITION             33     OK    OK    OK    0 VERIFIED                      
  REFMOD-DATE-PARSE            33     OK    OK    OK    0 VERIFIED                      
  REFMOD-WRITE                 67     OK    OK    OK    2 2 MANUAL REVIEW flags         
  REPEAT-TIMES                 16     OK    OK    OK    0 VERIFIED                      
  RPT-LINE-BUILD               52     OK    OK    OK    0 VERIFIED                      
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
  STRESS-REDEFINES-COMP3       71     OK    OK    OK    0 VERIFIED                      
  STRESS-STRING-OVERFLOW       66     OK    OK    OK    0 VERIFIED                      
  STRESS-THRU-GOTO-OUT         64     OK    OK    OK    2 2 MANUAL REVIEW flags         
  STRESS-UNSTRING              61     OK    OK    OK    0 VERIFIED                      
  STRING-PTR                   16     OK    OK    OK    0 VERIFIED                      
  TXN-APPROVE-FLOW             82     OK    OK    OK    0 VERIFIED                      
  TXN-BATCH-CHECK              61     OK    OK    OK    0 VERIFIED                      
  TXN-VALIDATE-IF              64     OK    OK    OK    0 VERIFIED                      
  TYPE-CHECKER                 25     OK    OK    OK    0 VERIFIED                      
  UNSTR-COMPLEX                20     OK    OK    OK    0 VERIFIED                      
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

  MANUAL REVIEW FLAGS (28 total)
  --------------------------------------------------
  ALTER-DANGER: # MANUAL REVIEW: ALTER 1000-DISPATCH TO PROCEED TO 3000-OVERRIDE
  ALTER-DANGER: # ALTER 1000-DISPATCH                            # MANUAL REVIEW                                [FAI
  ALTER-TEST: # MANUAL REVIEW: ALTER CALC-DISPATCH TO PROCEED TO CALC-COMPOUND
  ALTER-TEST: # ALTER CALC-DISPATCH                            # MANUAL REVIEW                                [FAI
  BATCH-PAYMENT: # MANUAL REVIEW: MULTIPLYWS-LATE-FEEBY
  BATCH-PAYMENT: # MULTIPLYWS-LATE-FEEBY                          # MANUAL REVIEW                                [FAI
  PERF-THRU-GOTO: # MANUAL REVIEW: ALTER 2000-DISPATCH TO PROCEED TO 2100-PATH-B
  PERF-THRU-GOTO: # ALTER 2000-DISPATCH                            # MANUAL REVIEW                                [FAI
  PERF-UNTIL-AND: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  PERF-UNTIL-AND: # SORT SORT-FILE PROCEDURE                       # MANUAL REVIEW                                [FAI
  REFMOD-WRITE: # MANUAL REVIEW: SORT with INPUT/OUTPUT PROCEDURE
  REFMOD-WRITE: # SORT SORT-FILE PROCEDURE                       # MANUAL REVIEW                                [FAI
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
  STRESS-THRU-GOTO-OUT: # MANUAL REVIEW: ALTER 4000-DYNAMIC TO PROCEED TO 5000-ESCAPE
  STRESS-THRU-GOTO-OUT: # ALTER 4000-DYNAMIC                             # MANUAL REVIEW                                [FAI

==========================================================================================
  PVR = 87.0%  (87 clean / 100 tested)
==========================================================================================
