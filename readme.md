aletheia
deterministic behavioral verification for COBOL mainframe migrations.
try it: \*\*try it:\*\* \[attractive-sadye-aletheia-7b91ff1e.koyeb.app](https://attractive-sadye-aletheia-7b91ff1e.koyeb.app)
what it does
you're migrating COBOL to Java or whatever. your vendor says it works. aletheia proves whether it actually behaves the same as the mainframe.
upload your COBOL and get a full analysis. upload mainframe data alongside it and run Shadow Diff to verify behavioral equivalence field by field. binary verdict: VERIFIED or REQUIRES MANUAL REVIEW. no confidence scores, no AI in the verification loop. fully deterministic.
how it works
parses the original COBOL with ANTLR4, builds a deterministic semantic model, generates a Python reference execution, then compares that against mainframe production data. if the outputs match you get a proof. if they don't you get a diagnosis of exactly where the behavior diverged.
the Python model is the internal answer key. the migrated code gets graded against it.
stats
1006+ tests, 0 failures. 94.3% verified on 459 dense banking/insurance programs. handles 5000+ line programs.
who this is for
migration consultancies and banks running COBOL migrations who need to prove the rewrite is correct.
contact
built by hector from spain. happy to verify a batch of your programs for free. open an issue or reach out at fathector7@gmail.com .

