      * ============================================================
      * RATE-TABLE.CPY — Interest Rate Table with REDEFINES
      * Demonstrates REDEFINES for dual interpretation of same memory
      * ============================================================
       05 WS-RATE-ENTRY.
          10 WS-RATE-CODE        PIC X(4).
          10 WS-RATE-VALUE       PIC S9(3)V9(4).
       05 WS-RATE-RAW REDEFINES WS-RATE-ENTRY
                                 PIC X(11).
