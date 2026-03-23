"""
compiler_config.py — IBM z/OS COBOL Compiler Flag Emulation

Manages compiler settings that affect generated Python behavior.
The critical flag is TRUNC mode, which controls arithmetic overflow:

  TRUNC(STD): Standard COBOL truncation — result mod PIC capacity
  TRUNC(BIN): Binary — COMP items keep full range, DISPLAY truncates
  TRUNC(OPT): Optimized — no truncation (compiler trusts programmer)

Default: STD + COMPAT — matches IBM's actual default (18-digit precision).
Uses contextvars for per-request isolation in async FastAPI.
"""

from contextvars import ContextVar
from dataclasses import dataclass, asdict


@dataclass
class CompilerConfig:
    trunc_mode: str = "STD"        # STD | BIN | OPT
    arith_mode: str = "COMPAT"     # COMPAT (18 digits) | EXTEND (31 digits)
    decimal_point: str = "PERIOD"  # PERIOD | COMMA
    currency_sign: str = "$"
    numproc: str = "NOPFD"         # NOPFD | PFD | MIG
    codepage: str = "cp037"        # cp037 (US/Canada) | cp500 (Intl Latin-1) | cp1047 (Open Systems)

    def validate(self):
        if self.trunc_mode not in ("STD", "BIN", "OPT"):
            raise ValueError(f"Invalid trunc_mode: {self.trunc_mode}")
        if self.arith_mode not in ("COMPAT", "EXTEND"):
            raise ValueError(f"Invalid arith_mode: {self.arith_mode}")
        if self.decimal_point not in ("PERIOD", "COMMA"):
            raise ValueError(f"Invalid decimal_point: {self.decimal_point}")
        if self.numproc not in ("NOPFD", "PFD", "MIG"):
            raise ValueError(f"Invalid numproc: {self.numproc}")
        if self.codepage not in ("cp037", "cp500", "cp1047"):
            raise ValueError(f"Invalid codepage: {self.codepage}")

    def to_dict(self):
        return asdict(self)

    @property
    def precision(self):
        """Decimal precision based on ARITH mode."""
        return 31 if self.arith_mode == "EXTEND" else 18


# ── Per-context config (isolates concurrent async requests) ──────────
_config_var: ContextVar[CompilerConfig] = ContextVar(
    "compiler_config", default=CompilerConfig()
)


def get_config() -> CompilerConfig:
    """Return the compiler configuration for the current context."""
    return _config_var.get()


def set_config(**kwargs) -> CompilerConfig:
    """Set compiler configuration for the current context. Returns the new config."""
    cfg = CompilerConfig(**kwargs)
    cfg.validate()
    _config_var.set(cfg)
    return cfg


def reset_config() -> CompilerConfig:
    """Reset to default configuration for the current context."""
    cfg = CompilerConfig()
    _config_var.set(cfg)
    return cfg
