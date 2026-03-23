==========================================================================================
  ALETHEIA VIABILITY EXPERIMENT
==========================================================================================

  Programs tested    : 200
  Parse success      : 199/200 (99.5%)
  Generate success   : 200/200 (100.0%)
  Compile success    : 200/200 (100.0%)
  Clean (0 MR)       : 168/200 (84.0%)
  With MANUAL REVIEW : 32 programs, 103 total flags

  PVR (Parse-Verify Rate) = 84.0%

  PROGRAM                   LINES  PARSE   GEN  COMP   MR STATUS                        
  --------------------------------------------------------------------------------------
  ACCT-BENE-UPDATE            121     OK    OK    OK    0 VERIFIED                      
  ACCT-CLOSE-PROC             123     OK    OK    OK    0 VERIFIED                      
  ACCT-ESCHEAT-SCAN           111     OK    OK    OK    0 VERIFIED                      
  ACCT-HOLD-RELEASE           116     OK    OK    OK    0 VERIFIED                      
  ACCT-INTEREST               124     OK    OK    OK    0 VERIFIED                      
  ACCT-MERGE-HANDLER           94     OK    OK    OK    0 VERIFIED                      
  ACCT-MIN-BAL-CHECK          105     OK    OK    OK    0 VERIFIED                      
  ACCT-RECON-DAILY            142     OK    OK    OK    0 VERIFIED                      
  ACCT-REDEFINE                22     OK    OK    OK    0 VERIFIED                      
  ACCT-STMT-CYCLE             127     OK    OK    OK    0 VERIFIED                      
  ACCT-TIER-ASSIGN            112     OK    OK    OK    0 VERIFIED                      
  ACCT-TITLE-CHANGE           100     OK    OK    OK    1 1 MANUAL REVIEW flags         
  ACH-BATCH-VALIDATOR         312     OK    OK    OK    0 VERIFIED                      
  ALTER-DANGER                 18     OK    OK    OK    2 2 MANUAL REVIEW flags         
  ALTER-SQL-HYBRID            212     OK    OK    OK   12 12 MANUAL REVIEW flags        
  ALTER-TEST                   25     OK    OK    OK    2 2 MANUAL REVIEW flags         
  APPLY-PENALTY                23     OK    OK    OK    0 VERIFIED                      
  ARITHMETIC-STRESS           102     OK    OK    OK    0 VERIFIED                      
  BATCH-GL-POSTING            337     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYMENT               192     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYROLL-RUN           305     OK    OK    OK    0 VERIFIED                      
  CALC-INT                     18     OK    OK    OK    0 VERIFIED                      
  CARD-AUTH-PROCESSOR         294     OK    OK    OK    0 VERIFIED                      
  CD-MATURITY-CALC            220     OK    OK    OK    0 VERIFIED                      
  CHECK-DIGIT-VALIDATOR       246     OK    OK    OK    0 VERIFIED                      
  CLR-CHECK-IMAGE              68     OK    OK    OK    0 VERIFIED                      
  CLR-CORRESPONDENT            68     OK    OK    OK    0 VERIFIED                      
  CLR-DISPUTE-CALC             66     OK    OK    OK    0 VERIFIED                      
  CLR-EXCEPTION-PROC           89     OK    OK    OK    0 VERIFIED                      
  CLR-FED-RESERVE-FMT          72     OK    OK    OK    0 VERIFIED                      
  CLR-INTERBANK-FEE            58     OK    OK    OK    0 VERIFIED                      
  CLR-NET-SETTLE               62     OK    OK    OK    0 VERIFIED                      
  CLR-RETURN-REASON            86     OK    OK    OK    0 VERIFIED                      
  COLLATERAL-LTV-CALC         234     OK    OK    OK    0 VERIFIED                      
  COMPOUND-INT                 27     OK    OK    OK    0 VERIFIED                      
  CREDIT-SCORE                180     OK    OK    OK    0 VERIFIED                      
  CSV-PARSER                   21     OK    OK    OK    0 VERIFIED                      
  CURRENCY-DENOM-CALC         198     OK    OK    OK    0 VERIFIED                      
  DATA-CLEANER                 20     OK    OK    OK    0 VERIFIED                      
  DATA-MASKING-ENGINE         215     OK    OK    OK    0 VERIFIED                      
  DEEP-NEST                    34     OK    OK    OK    0 VERIFIED                      
  DEMO-WITH-COPY               36     OK    OK    OK    0 VERIFIED                      
  DEMO_LOAN_INTEREST           93     OK    OK    OK    0 VERIFIED                      
  DEP-CD-RENEWAL               62     OK    OK    OK    0 VERIFIED                      
  DEP-INT-ACCRUE-360           46     OK    OK    OK    0 VERIFIED                      
  DEP-IRA-CONTRIB              67     OK    OK    OK    0 VERIFIED                      
  DEP-PENALTY-EARLY            60     OK    OK    OK    0 VERIFIED                      
  DEP-RATE-BOARD               59     OK    OK    OK    0 VERIFIED                      
  DEP-REG-D-MONITOR            64     OK    OK    OK    0 VERIFIED                      
  DEP-TIER-INTEREST            75     OK    OK    OK    0 VERIFIED                      
  DEP-UNCLM-PROP               83     OK    OK    OK    1 1 MANUAL REVIEW flags         
  DEPOSIT-RECONCILE           254     OK    OK    OK    0 VERIFIED                      
  DISPLAY-MIX                  18     OK    OK    OK    0 VERIFIED                      
  DIV-REMAINDER                18     OK    OK    OK    0 VERIFIED                      
  DORMANT-ACCT-SWEEP          220     OK    OK    OK    0 VERIFIED                      
  DYNAMIC-TABLE                25     OK    OK    OK    0 VERIFIED                      
  EMBEDDED-SQL-BATCH          215     OK    OK    OK    3 3 MANUAL REVIEW flags         
  ESCROW-ANALYSIS             233     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO                    22     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO-PRICING            68     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO-RATE-MATRIX       205     OK    OK    OK    0 VERIFIED                      
  EVAL-VARIABLE                36     OK    OK    OK    0 VERIFIED                      
  EVALUATE-TEST                60     OK    OK    OK    0 VERIFIED                      
  EXEC-SQL-TEST                45     OK    OK    OK    0 VERIFIED                      
  FRAUD-ACCT-TAKEOVER         108     OK    OK    OK    0 VERIFIED                      
  FRAUD-ALERT-FORMAT           91     OK    OK    OK    0 VERIFIED                      
  FRAUD-BIN-LOOKUP             71     OK    OK    OK    0 VERIFIED                      
  FRAUD-CHARGEBACK             89     OK    OK    OK    0 VERIFIED                      
  FRAUD-DEVICE-SCORE          111     OK    OK    OK    0 VERIFIED                      
  FRAUD-GEO-ANOMALY           100     OK    OK    OK    0 VERIFIED                      
  FRAUD-LINK-ANALYZE           93     OK    OK    OK    2 2 MANUAL REVIEW flags         
  FRAUD-RULE-ENGINE           114     OK    OK    OK    1 1 MANUAL REVIEW flags         
  FRAUD-THRESHOLD-ADJ          94     OK    OK    OK    0 VERIFIED                      
  FRAUD-VELOCITY-CHK          100     OK    OK    OK    0 VERIFIED                      
  FX-RATE-CONVERTER           274     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND                  21     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND-ROUTER           66     OK    OK    OK    0 VERIFIED                      
  GOTO-FLOW                    26     OK    OK    OK    0 VERIFIED                      
  INIT-TEST                    22     OK    OK    OK    0 VERIFIED                      
  INS-ANNUITY-VALUE            75     OK    OK    OK    0 VERIFIED                      
  INS-BENEFIT-SCHED           105     OK    OK    OK    0 VERIFIED                      
  INS-CLAIM-ADJUDIC           120     OK    OK    OK    1 1 MANUAL REVIEW flags         
  INS-COINSURE-SPLIT           85     OK    OK    OK    0 VERIFIED                      
  INS-LAPSE-NOTICE            103     OK    OK    OK    0 VERIFIED                      
  INS-MORTALITY-TBL            94     OK    OK    OK    0 VERIFIED                      
  INS-PREM-CALC                98     OK    OK    OK    0 VERIFIED                      
  INS-RESERVE-POST             81     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV                 12     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV-SANITIZE        69     OK    OK    OK    0 VERIFIED                      
  INTEREST-ACCRUAL-BATCH      258     OK    OK    OK    0 VERIFIED                      
  INTR-CALC-3270               37   FAIL    OK    OK    0 VERIFIED                      
  INVOICE-GEN                  59     OK    OK    OK    0 VERIFIED                      
  LATE-FEE-ASSESSOR           228     OK    OK    OK    0 VERIFIED                      
  LEGACY-ALTER-DISPATCH       154     OK    OK    OK   12 12 MANUAL REVIEW flags        
  LOAN-AMORT-ENGINE           256     OK    OK    OK    0 VERIFIED                      
  LOAN-CONV-ASSESS            161     OK    OK    OK    0 VERIFIED                      
  LOAN-COUPON-STRIP           123     OK    OK    OK    0 VERIFIED                      
  LOAN-DELINQ-TRACKER         153     OK    OK    OK    0 VERIFIED                      
  LOAN-ESCROW-ADJUST          145     OK    OK    OK    0 VERIFIED                      
  LOAN-FORBEARANCE-CALC       183     OK    OK    OK    0 VERIFIED                      
  LOAN-GRACE-PERIOD-CALC      189     OK    OK    OK    5 5 MANUAL REVIEW flags         
  LOAN-LOSS-RESERVE           130     OK    OK    OK    0 VERIFIED                      
  LOAN-MODIF-ENGINE           156     OK    OK    OK    0 VERIFIED                      
  LOAN-PAYOFF-QUOTE           123     OK    OK    OK    0 VERIFIED                      
  LOAN-PMI-REMOVAL            155     OK    OK    OK    2 2 MANUAL REVIEW flags         
  LOAN-PREPAY-PENALTY         176     OK    OK    OK    0 VERIFIED                      
  LOAN-RATE-RESET             171     OK    OK    OK    0 VERIFIED                      
  MAIN-LOAN                    34     OK    OK    OK    0 VERIFIED                      
  MISC-AUDIT-TRAIL             75     OK    OK    OK    1 1 MANUAL REVIEW flags         
  MISC-BATCH-TOTALS            68     OK    OK    OK    0 VERIFIED                      
  MISC-BRANCH-GL-POST         111     OK    OK    OK    0 VERIFIED                      
  MISC-DATE-CALC               63     OK    OK    OK    0 VERIFIED                      
  MISC-FEE-WAIVER              65     OK    OK    OK    0 VERIFIED                      
  MISC-LETTER-GEN              83     OK    OK    OK    1 1 MANUAL REVIEW flags         
  MISC-RATE-COMPARE            64     OK    OK    OK    0 VERIFIED                      
  MISC-SAFE-BOX-BILL           64     OK    OK    OK    0 VERIFIED                      
  MONTHLY-TOTALS               28     OK    OK    OK    0 VERIFIED                      
  MR-ALTER-DISPATCH-V2        112     OK    OK    OK   12 12 MANUAL REVIEW flags        
  MR-ALTER-FALLBACK           116     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-ALTER-RECOVERY           100     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-EXEC-CICS-MAP            112     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-CICS-QUEUE           96     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-CURSOR          105     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-REPORT          102     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-UPDATE          111     OK    OK    OK    2 2 MANUAL REVIEW flags         
  MR-ODO-INVOICE              112     OK    OK    OK    2 2 MANUAL REVIEW flags         
  MR-ODO-TABLE                 92     OK    OK    OK    0 VERIFIED                      
  MSG-BUILDER                  18     OK    OK    OK    0 VERIFIED                      
  NESTED-EVAL                  38     OK    OK    OK    0 VERIFIED                      
  OVERDRAFT-PROCESSOR         240     OK    OK    OK    0 VERIFIED                      
  PAY-ADDENDA-PARSE           118     OK    OK    OK    1 1 MANUAL REVIEW flags         
  PAY-BATCH-SETTLE            130     OK    OK    OK    0 VERIFIED                      
  PAY-CUTOFF-CHECK            104     OK    OK    OK    0 VERIFIED                      
  PAY-FLOAT-CALC              120     OK    OK    OK    0 VERIFIED                      
  PAY-LIMIT-ENFORCE           125     OK    OK    OK    4 4 MANUAL REVIEW flags         
  PAY-NSF-FEE-CALC            150     OK    OK    OK    1 1 MANUAL REVIEW flags         
  PAY-OFFSET-APPLY            112     OK    OK    OK    0 VERIFIED                      
  PAY-ORIGINATOR-FEE          100     OK    OK    OK    0 VERIFIED                      
  PAY-PRENOTE-VALID           134     OK    OK    OK    1 1 MANUAL REVIEW flags         
  PAY-RECUR-SCHED             120     OK    OK    OK    0 VERIFIED                      
  PAY-RETURN-PROC             126     OK    OK    OK    0 VERIFIED                      
  PAY-SAME-DAY-ACH            139     OK    OK    OK    1 1 MANUAL REVIEW flags         
  PAYROLL-CALC                 47     OK    OK    OK    0 VERIFIED                      
  PENSION-BENEFIT-CALC        262     OK    OK    OK    0 VERIFIED                      
  PERFORM-VARYING-TEST         71     OK    OK    OK    0 VERIFIED                      
  REG-BSA-AGGREGATE           105     OK    OK    OK    0 VERIFIED                      
  REG-CALL-RPT-GEN             85     OK    OK    OK    0 VERIFIED                      
  REG-CRA-GEOCODE             102     OK    OK    OK    2 2 MANUAL REVIEW flags         
  REG-CTR-BUILDER             103     OK    OK    OK    0 VERIFIED                      
  REG-HMDA-EXTRACT            110     OK    OK    OK    1 1 MANUAL REVIEW flags         
  REG-OFAC-MATCH              112     OK    OK    OK    2 2 MANUAL REVIEW flags         
  REG-RISK-WEIGHT              96     OK    OK    OK    0 VERIFIED                      
  REG-SAR-SCREEN              100     OK    OK    OK    0 VERIFIED                      
  REG-STRESS-CALC              98     OK    OK    OK    0 VERIFIED                      
  REG-TIN-VALIDATOR           111     OK    OK    OK    4 4 MANUAL REVIEW flags         
  REPEAT-TIMES                 16     OK    OK    OK    0 VERIFIED                      
  REWRITE-ACCT-UPDATE          75     OK    OK    OK    0 VERIFIED                      
  SORT-MERGE-RECON             58     OK    OK    OK    0 VERIFIED                      
  SORT-TXN-REPORT             203     OK    OK    OK    0 VERIFIED                      
  STATUS-CHECKER               35     OK    OK    OK    0 VERIFIED                      
  STMT-LINE-BUILDER           246     OK    OK    OK    0 VERIFIED                      
  STRING-INSPECT-REPORT       207     OK    OK    OK    0 VERIFIED                      
  STRING-PTR                   16     OK    OK    OK    0 VERIFIED                      
  STRING-PTR-ASSEMBLER         61     OK    OK    OK    0 VERIFIED                      
  TAX-1099-INT-GEN             93     OK    OK    OK    1 1 MANUAL REVIEW flags         
  TAX-BACKUP-SCREEN            78     OK    OK    OK    0 VERIFIED                      
  TAX-CORRECTED-1099           88     OK    OK    OK    0 VERIFIED                      
  TAX-COST-BASIS               71     OK    OK    OK    0 VERIFIED                      
  TAX-FOREIGN-CREDIT           63     OK    OK    OK    0 VERIFIED                      
  TAX-REMIC-ALLOC              89     OK    OK    OK    0 VERIFIED                      
  TAX-W8BEN-VALID             114     OK    OK    OK    3 3 MANUAL REVIEW flags         
  TAX-WITHOLD-CALC            103     OK    OK    OK    0 VERIFIED                      
  TELLER-BATCH-BALANCE        291     OK    OK    OK    0 VERIFIED                      
  TRADE-ACCRUED-INT            84     OK    OK    OK    0 VERIFIED                      
  TRADE-BOND-YIELD            130     OK    OK    OK    0 VERIFIED                      
  TRADE-CONFIRM-GEN            78     OK    OK    OK    0 VERIFIED                      
  TRADE-CORP-ACTION           102     OK    OK    OK    0 VERIFIED                      
  TRADE-CUSTODY-FEE            89     OK    OK    OK    1 1 MANUAL REVIEW flags         
  TRADE-DIVIDEND-POST          84     OK    OK    OK    0 VERIFIED                      
  TRADE-FAIL-TRACKER          116     OK    OK    OK    0 VERIFIED                      
  TRADE-MARGIN-CALC           112     OK    OK    OK    0 VERIFIED                      
  TRADE-SETTLE-BATCH          124     OK    OK    OK    0 VERIFIED                      
  TRADE-TAX-LOT-CALC           95     OK    OK    OK    1 1 MANUAL REVIEW flags         
  TREAS-FED-FUNDS-PRC          73     OK    OK    OK    0 VERIFIED                      
  TREAS-LIQUIDITY-RPT          93     OK    OK    OK    0 VERIFIED                      
  TREAS-LOCKBOX-PROC          113     OK    OK    OK    0 VERIFIED                      
  TREAS-NOSTRO-RECON          126     OK    OK    OK    0 VERIFIED                      
  TREAS-POOL-ALLOC            111     OK    OK    OK    0 VERIFIED                      
  TREAS-POS-CASH-CALC          90     OK    OK    OK    0 VERIFIED                      
  TREAS-REPO-SETTLE            97     OK    OK    OK    0 VERIFIED                      
  TREAS-SWEEP-ENGINE          122     OK    OK    OK    0 VERIFIED                      
  TREAS-WIRE-FEE-CALC         105     OK    OK    OK    0 VERIFIED                      
  TREAS-ZBA-TRANSFER           98     OK    OK    OK    0 VERIFIED                      
  TYPE-CHECKER                 25     OK    OK    OK    0 VERIFIED                      
  UNSTR-COMPLEX                20     OK    OK    OK    0 VERIFIED                      
  UNSTRING-DELIM-PARSER        87     OK    OK    OK    0 VERIFIED                      
  VSAM-ACCT-UPDATE            247     OK    OK    OK    0 VERIFIED                      
  WIRE-TRANSFER-CALC          286     OK    OK    OK    0 VERIFIED                      
  WIRE-VALIDATE               130     OK    OK    OK    0 VERIFIED                      
  WRITE-ADV-REPORT             90     OK    OK    OK    0 VERIFIED                      

  CONSTRUCT FREQUENCY (across all programs)
  --------------------------------------------------
  STOP RUN                  195 ########################################
  MOVE                      190 ########################################
  PERFORM                   174 ########################################
  IF/ELSE                   172 ########################################
  DISPLAY                   163 ########################################
  INITIALIZE                157 ########################################
  COMP-3                    155 ########################################
  88-level                  154 ########################################
  COMPUTE                   142 ########################################
  ADD                       117 ########################################
  EVALUATE TRUE              88 ########################################
  PERFORM VARYING            76 ########################################
  OCCURS                     61 ########################################
  SUBTRACT                   47 ########################################
  STRING                     44 ########################################
  MULTIPLY                   19 ###################
  EVALUATE variable          19 ###################
  DIVIDE                     17 #################
  UNSTRING                   16 ################
  GO TO                      15 ###############
  PERFORM THRU               15 ###############
  IS NUMERIC                 14 ##############
  DIVIDE REMAINDER            9 #########
  ALTER                       7 #######
  PERFORM TIMES               7 #######
  EXEC SQL                    6 ######
  REDEFINES                   3 ###
  STRING POINTER              3 ###
  EVALUATE ALSO               3 ###
  DELIMITER IN                2 ##
  COPY                        1 #
  88 THRU                     1 #
  IS ALPHABETIC               1 #

  MANUAL REVIEW FLAGS (103 total)
  --------------------------------------------------
  ACCT-TITLE-CHANGE: # MANUAL REVIEW: WS-NEW-FIRST(1:1)ISNUMERIC
  ALTER-DANGER: # MANUAL REVIEW: ALTER 1000-DISPATCH TO PROCEED TO 3000-OVERRIDE
  ALTER-DANGER: # ALTER 1000-DISPATCH                            # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-ADDRESS
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-NAME
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-CLOSE
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-REOPEN
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-ADDRESS
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-NAME
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-CLOSE
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-REOPEN
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-TEST: # MANUAL REVIEW: ALTER CALC-DISPATCH TO PROCEED TO CALC-COMPOUND
  ALTER-TEST: # ALTER CALC-DISPATCH                            # MANUAL REVIEW                                [FAI
  DEP-UNCLM-PROP: # MANUAL REVIEW: WRITERPT-RECORD
  EMBEDDED-SQL-BATCH: # MANUAL REVIEW: CONTINUE
  EMBEDDED-SQL-BATCH: # MANUAL REVIEW: CONTINUE
  EMBEDDED-SQL-BATCH: # MANUAL REVIEW: CONTINUE
  FRAUD-LINK-ANALYZE: # MANUAL REVIEW: WS-BLOCKORWS-REVIEW
  FRAUD-LINK-ANALYZE: # IF WS-BLOCKORWS-REVIEW                         # MANUAL REVIEW: WS-BLOCKORWS-REVIEW           [FAI
  FRAUD-RULE-ENGINE: # MANUAL REVIEW: CONTINUE
  INS-CLAIM-ADJUDIC: # MANUAL REVIEW: CONTINUE
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-DEPOSIT
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-WITHDRAWAL
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-TRANSFER
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-INQUIRY
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-DEPOSIT
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-WITHDRAWAL
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-TRANSFER
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-INQUIRY
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: WS-LATEORWS-DEFAULT
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: Nested IF
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: Nested IF
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: Nested IF
  LOAN-GRACE-PERIOD-CALC: # IF WS-LATEORWS-DEFAULT                         # MANUAL REVIEW: WS-LATEORWS-DEFAULT           [FAI
  LOAN-PMI-REMOVAL: # MANUAL REVIEW: WS-PMI-AUTO-REMOVEORWS-PMI-ELIGIBLE
  LOAN-PMI-REMOVAL: # IF WS-PMI-AUTO-REMOVEORWS-PMI-ELIGIBLE         # MANUAL REVIEW: WS-PMI-AUTO-REMOVEORWS-PMI-E  [FAI
  MISC-AUDIT-TRAIL: # MANUAL REVIEW: WRITEAUDIT-RECORD
  MISC-LETTER-GEN: # MANUAL REVIEW: UNSTRINGWS-FULL-NAMEDELIMITEDBY' 'INTOWS-FIRST-NAMEWS-LAST-N
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-DEPOSIT
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-WITHDRAWAL
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-TRANSFER
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-INQUIRY
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-DEPOSIT
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-WITHDRAWAL
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-TRANSFER
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-INQUIRY
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOPRIMARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOSECONDARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOTERTIARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO PRIMARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO SECONDARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO TERTIARY-SERVICE
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-TIMEOUT
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-DATA-ERR
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-CONN-FAIL
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-TIMEOUT
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-DATA-ERR
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-CONN-FAIL
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-EXEC-SQL-UPDATE: # MANUAL REVIEW: Nested IF
  MR-EXEC-SQL-UPDATE: # MANUAL REVIEW: CONTINUE
  MR-ODO-INVOICE: # MANUAL REVIEW: WS-IL-TAXABLE(WS-IDX)
  MR-ODO-INVOICE: # IF WS-IL-TAXABLE(WS-IDX)                       # MANUAL REVIEW: WS-IL-TAXABLE(WS-IDX)         [FAI
  PAY-ADDENDA-PARSE: # MANUAL REVIEW: WS-RETURNSORWS-PAYMENT-RELORWS-ADDENDA-CTX
  PAY-LIMIT-ENFORCE: # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVIEW
  PAY-LIMIT-ENFORCE: # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVIEW
  PAY-LIMIT-ENFORCE: # IF WS-APPROVEDORWS-PENDING-REVIEW              # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVI  [FAI
  PAY-LIMIT-ENFORCE: # IF WS-APPROVEDORWS-PENDING-REVIEW              # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVI  [FAI
  PAY-NSF-FEE-CALC: # MANUAL REVIEW: Nested IF
  PAY-PRENOTE-VALID: # MANUAL REVIEW: WS-ACCT-NUM(1:1)ISNUMERIC
  PAY-SAME-DAY-ACH: # MANUAL REVIEW: WS-CREDIT-TXNORWS-DEBIT-TXNORWS-PAYROLL-TXN
  REG-CRA-GEOCODE: # MANUAL REVIEW: WS-LOW-INCOMEORWS-MODERATE
  REG-CRA-GEOCODE: # IF WS-LOW-INCOMEORWS-MODERATE                  # MANUAL REVIEW: WS-LOW-INCOMEORWS-MODERATE    [FAI
  REG-HMDA-EXTRACT: # MANUAL REVIEW: CONTINUE
  REG-OFAC-MATCH: pass  # MANUAL REVIEW: inline PERFORM VARYING body
  REG-OFAC-MATCH: # MANUAL REVIEW: INSPECTWS-SDN-NAME(WS-SDN-IDX)TALLYINGWS-WORD-COUNTFORALLWS-
  REG-TIN-VALIDATOR: # MANUAL REVIEW: WS-TIN-VALUEISNUMERIC
  REG-TIN-VALIDATOR: # MANUAL REVIEW: INSPECTWS-TIN-VALUETALLYINGWS-DIGIT-COUNTFORALL'0'
  REG-TIN-VALIDATOR: pass  # MANUAL REVIEW: inline PERFORM VARYING body
  REG-TIN-VALIDATOR: # IF WS-TIN-VALUEISNUMERIC                       # MANUAL REVIEW: WS-TIN-VALUEISNUMERIC         [FAI
  TAX-1099-INT-GEN: # MANUAL REVIEW: WRITETAX-RECORD
  TAX-W8BEN-VALID: # MANUAL REVIEW: UNSTRINGWS-BENE-NAMEDELIMITEDBY' 'INTOWS-FIRSTWS-LASTEND-UNS
  TAX-W8BEN-VALID: # MANUAL REVIEW: INSPECTWS-TIN-VALUETALLYINGWS-DASH-COUNTFORALL'-'
  TAX-W8BEN-VALID: # MANUAL REVIEW: INSPECTWS-TIN-VALUETALLYINGWS-SPACE-COUNTFORALL' '
  TRADE-CUSTODY-FEE: pass  # MANUAL REVIEW: inline PERFORM VARYING body
  TRADE-TAX-LOT-CALC: # MANUAL REVIEW: WS-LT-LONG(WS-LT-IDX)

==========================================================================================
  PVR = 84.0%  (168 clean / 200 tested)
==========================================================================================
