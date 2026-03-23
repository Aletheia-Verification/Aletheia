"""
test_exec_sql.py — EXEC SQL/CICS Logic-Only Parser Tests

13 tests covering:
  - EXEC SQL parsing (SELECT INTO, UPDATE SET/WHERE, INSERT VALUES, DELETE, FETCH, COMMIT)
  - EXEC CICS parsing (SEND FROM, RECEIVE INTO, READ SET)
  - Variable taint classification (TAINTED, USED, CONTROL)
  - SQLCODE branch mapping

Run with:
    pytest test_exec_sql.py -v
"""

import pytest

from exec_sql_parser import (
    parse_exec_sql,
    parse_exec_cics,
    classify_variables,
    map_sqlcode_branches,
    analyze_exec_blocks,
)


# ══════════════════════════════════════════════════════════════════════
# Component 1: EXEC SQL Parser
# ══════════════════════════════════════════════════════════════════════


class TestExecSqlParser:
    def test_select_into(self):
        """SELECT INTO extracts output and input variables."""
        body = "SELECT BALANCE, INTEREST_RATE INTO :WS-BALANCE, :WS-RATE FROM ACCOUNTS WHERE ACCOUNT_ID = :WS-ACCT-ID"
        result = parse_exec_sql(body)
        assert result["verb"] == "SELECT"
        assert "WS-BALANCE" in result["into_vars"]
        assert "WS-RATE" in result["into_vars"]
        assert "WS-ACCT-ID" in result["where_vars"]

    def test_update_set_where(self):
        """UPDATE SET extracts set vars and where vars."""
        body = "UPDATE ACCOUNTS SET BALANCE = :WS-NEW-BAL WHERE ACCOUNT_ID = :WS-ACCT-ID"
        result = parse_exec_sql(body)
        assert result["verb"] == "UPDATE"
        assert "WS-NEW-BAL" in result["set_vars"]
        assert "WS-ACCT-ID" in result["where_vars"]

    def test_insert_values(self):
        """INSERT VALUES extracts host variables."""
        body = "INSERT INTO TRANSACTIONS VALUES(:WS-ACCT-ID, :WS-AMOUNT)"
        result = parse_exec_sql(body)
        assert result["verb"] == "INSERT"
        assert "WS-ACCT-ID" in result["all_host_vars"]
        assert "WS-AMOUNT" in result["all_host_vars"]

    def test_delete_where(self):
        """DELETE WHERE extracts where variables."""
        body = "DELETE FROM ACCOUNTS WHERE ACCOUNT_ID = :WS-ACCT-ID"
        result = parse_exec_sql(body)
        assert result["verb"] == "DELETE"
        assert "WS-ACCT-ID" in result["where_vars"]

    def test_fetch_into(self):
        """FETCH INTO extracts output variables."""
        body = "FETCH CURSOR1 INTO :WS-NAME, :WS-BALANCE"
        result = parse_exec_sql(body)
        assert result["verb"] == "FETCH"
        assert "WS-NAME" in result["into_vars"]
        assert "WS-BALANCE" in result["into_vars"]

    def test_unknown_verb(self):
        """COMMIT has no host variables."""
        body = "COMMIT"
        result = parse_exec_sql(body)
        assert result["verb"] == "COMMIT"
        assert result["into_vars"] == []
        assert result["where_vars"] == []
        assert result["all_host_vars"] == []


# ══════════════════════════════════════════════════════════════════════
# Component 2: EXEC CICS Parser
# ══════════════════════════════════════════════════════════════════════


class TestExecCicsParser:
    def test_cics_send_from(self):
        """SEND FROM extracts from_vars."""
        body = "SEND MAP('BALMAP') MAPSET('BALMSET') FROM(WS-DATA) ERASE"
        result = parse_exec_cics(body)
        assert result["verb"] == "SEND"
        assert "WS-DATA" in result["from_vars"]

    def test_cics_receive_into(self):
        """RECEIVE INTO extracts into_vars."""
        body = "RECEIVE MAP('INPMAP') MAPSET('INPMSET') INTO(WS-INPUT)"
        result = parse_exec_cics(body)
        assert result["verb"] == "RECEIVE"
        assert "WS-INPUT" in result["into_vars"]

    def test_cics_read_set(self):
        """READ SET extracts into_vars (pointer-based read)."""
        body = "READ FILE('CUSTFILE') INTO(WS-RECORD) RIDFLD(WS-KEY)"
        result = parse_exec_cics(body)
        assert result["verb"] == "READ"
        assert "WS-RECORD" in result["into_vars"]


# ══════════════════════════════════════════════════════════════════════
# Component 3: Variable Taint Tracker
# ══════════════════════════════════════════════════════════════════════


class TestVariableTaint:
    def test_select_into_taints(self):
        """Variables in SELECT INTO are classified as TAINTED."""
        parsed_blocks = [{
            "exec_type": "EXEC SQL",
            "verb": "SELECT",
            "body_preview": "SELECT BAL INTO :WS-BAL FROM T",
            "parsed": {
                "verb": "SELECT",
                "into_vars": ["WS-BAL"],
                "where_vars": [],
                "set_vars": [],
                "all_host_vars": ["WS-BAL"],
            },
        }]
        result = classify_variables(parsed_blocks, [])
        tainted_names = [t["var"] for t in result["tainted"]]
        assert "WS-BAL" in tainted_names

    def test_where_var_is_used(self):
        """Variables in WHERE clause are classified as USED."""
        parsed_blocks = [{
            "exec_type": "EXEC SQL",
            "verb": "SELECT",
            "body_preview": "SELECT BAL INTO :WS-BAL FROM T WHERE ID = :WS-ID",
            "parsed": {
                "verb": "SELECT",
                "into_vars": ["WS-BAL"],
                "where_vars": ["WS-ID"],
                "set_vars": [],
                "all_host_vars": ["WS-BAL", "WS-ID"],
            },
        }]
        result = classify_variables(parsed_blocks, [])
        used_names = [u["var"] for u in result["used"]]
        assert "WS-ID" in used_names

    def test_sqlcode_is_control(self):
        """WS-SQLCODE is classified as CONTROL."""
        variables = [{"name": "WS-SQLCODE", "comp3": True}]
        result = classify_variables([], variables)
        control_names = [c["var"] for c in result["control"]]
        assert "WS-SQLCODE" in control_names


# ══════════════════════════════════════════════════════════════════════
# Component 4: SQLCODE Branch Mapping
# ══════════════════════════════════════════════════════════════════════


class TestSqlcodeBranches:
    def test_sqlcode_branch_mapping(self):
        """IF WS-SQLCODE NOT = 0 maps to error handler."""
        conditions = [
            {"raw": "IF WS-SQLCODE NOT = 0"},
        ]
        exec_deps = [{"type": "EXEC SQL", "verb": "SELECT"}]
        result = map_sqlcode_branches(conditions, exec_deps)
        assert len(result) == 1
        assert result[0]["branch"] == "error"
        assert "Error handler" in result[0]["meaning"]
