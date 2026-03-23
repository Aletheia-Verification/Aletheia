"""
cobol_file_io.py — Abstract File I/O Layer for Generated Python

Provides runtime file I/O functions injected into the generated Python namespace.
Two backends:
  - StreamBackend:    feeds pre-parsed records (for Shadow Diff / testing)
  - RealFileBackend:  reads/writes actual flat files from disk (for CLI)

Mirrors how mainframes work: JCL assigns DD names to physical datasets at runtime.
"""

import logging
from decimal import Decimal
from pathlib import Path

logger = logging.getLogger(__name__)


def to_python_name(name):
    """COBOL name → Python name: WS-DAILY-RATE → ws_daily_rate"""
    return name.lower().replace("-", "_")


class ReverseKey:
    """Wrapper for DESCENDING sort keys — inverts comparison operators."""

    __slots__ = ("val",)

    def __init__(self, val):
        self.val = val

    def __lt__(self, other):
        return self.val > other.val

    def __eq__(self, other):
        return self.val == other.val

    def __le__(self, other):
        return self.val >= other.val

    def __gt__(self, other):
        return self.val < other.val

    def __ge__(self, other):
        return self.val <= other.val

    def __repr__(self):
        return f"ReverseKey({self.val!r})"


# ══════════════════════════════════════════════════════════════════════
# Backends
# ══════════════════════════════════════════════════════════════════════


class StreamBackend:
    """In-memory backend for Shadow Diff verification and testing.

    Input files are fed from pre-parsed record iterators.
    Output files collect records into a list for later comparison.
    """

    def __init__(self, input_streams=None, output_collectors=None):
        """
        Args:
            input_streams: dict mapping file_name → iterator of record dicts
            output_collectors: dict mapping file_name → list (records appended here)
        """
        self._input_streams = input_streams or {}
        self._output_collectors = output_collectors or {}
        self._open_files = set()
        self._materialized = {}   # file_name → list of records (for START)
        self._cursor = {}         # file_name → int position
        self._relative_stores = {}  # file_name → dict[int, record]

    def open(self, file_name, mode):
        self._open_files.add(file_name)
        return "00"

    def read(self, file_name):
        stream = self._input_streams.get(file_name)
        if stream is None:
            return None, "35"
        try:
            record = next(stream)
            return record, "00"
        except StopIteration:
            return None, "10"

    def write(self, file_name, record_bytes):
        collector = self._output_collectors.get(file_name)
        if collector is None:
            self._output_collectors[file_name] = [record_bytes]
        else:
            collector.append(record_bytes)
        return "00"

    def rewrite(self, file_name, record):
        """Update last-read record (noop for stream testing)."""
        return "00"

    def read_by_key(self, file_name, key_field, key_value):
        """Lookup by key (noop for stream testing — returns None/not found)."""
        return None, "23"

    # ── Indexed file operations ─────────────────────────────────────

    def start(self, file_name, key_field, key_value, mode='EQ'):
        """Position cursor for subsequent read_next by key criteria."""
        if file_name not in self._materialized:
            stream = self._input_streams.get(file_name)
            if stream is None:
                return "23"
            records = list(stream)
            if len(records) > 100_000:
                logger.warning(
                    "Indexed file materialized with %d records — "
                    "consider streaming mode for large files", len(records))
            self._materialized[file_name] = records
        records = self._materialized[file_name]
        for i, rec in enumerate(records):
            val = str(rec.get(key_field, ''))
            target = str(key_value)
            if mode == 'EQ' and val == target:
                self._cursor[file_name] = i
                return "00"
            elif mode == 'GE' and val >= target:
                self._cursor[file_name] = i
                return "00"
            elif mode == 'GT' and val > target:
                self._cursor[file_name] = i
                return "00"
        return "23"

    def read_next(self, file_name):
        """Read next record after START position."""
        records = self._materialized.get(file_name)
        if records is None:
            return None, "35"
        pos = self._cursor.get(file_name, 0)
        if pos >= len(records):
            return None, "10"
        record = records[pos]
        self._cursor[file_name] = pos + 1
        return record, "00"

    def delete(self, file_name):
        """Delete current record (last read via read_next)."""
        records = self._materialized.get(file_name)
        pos = self._cursor.get(file_name, 0)
        if records is None or pos <= 0:
            return "23"
        del records[pos - 1]
        self._cursor[file_name] = pos - 1
        return "00"

    # ── Relative file operations ────────────────────────────────────

    def read_relative(self, file_name, relative_key):
        """Read record at position N (1-based)."""
        store = self._relative_stores.get(file_name, {})
        record = store.get(relative_key)
        if record is None:
            return None, "23"
        return record, "00"

    def write_relative(self, file_name, record, relative_key):
        """Write record at position N (1-based). Returns '22' if occupied."""
        if file_name not in self._relative_stores:
            self._relative_stores[file_name] = {}
        store = self._relative_stores[file_name]
        if relative_key in store:
            return "22"
        store[relative_key] = record
        return "00"

    def rewrite_relative(self, file_name, record, relative_key):
        """Overwrite record at position N. Returns '23' if not found."""
        store = self._relative_stores.get(file_name, {})
        if relative_key not in store:
            return "23"
        store[relative_key] = record
        return "00"

    def delete_relative(self, file_name, relative_key):
        """Delete record at position N. Returns '23' if not found."""
        store = self._relative_stores.get(file_name, {})
        if relative_key not in store:
            return "23"
        del store[relative_key]
        return "00"

    def close(self, file_name):
        self._open_files.discard(file_name)
        return "00"


class RealFileBackend:
    """Disk-based backend for standalone CLI execution.

    Reads/writes actual fixed-width flat files.
    """

    def __init__(self, file_paths=None):
        """
        Args:
            file_paths: dict mapping file_name → filesystem path string
        """
        self._file_paths = file_paths or {}
        self._handles = {}

    def open(self, file_name, mode):
        path = self._file_paths.get(file_name)
        if not path or (mode == "r" and not Path(path).exists()):
            return None, "35"
        try:
            self._handles[file_name] = open(path, mode + "b")
            return None, "00"
        except OSError:
            return None, "35"

    def read(self, file_name, record_length):
        fh = self._handles.get(file_name)
        if fh is None:
            return None, "35"
        raw = fh.read(record_length)
        if not raw:
            return None, "10"
        return raw, "00"

    def close(self, file_name):
        fh = self._handles.get(file_name)
        if fh:
            fh.close()
            del self._handles[file_name]
        return "00"

    def write(self, file_name, record_bytes):
        fh = self._handles.get(file_name)
        if fh is None:
            return "35"
        try:
            fh.write(record_bytes)
            return "00"
        except OSError:
            fh.close()
            del self._handles[file_name]
            return "48"

    # ── Indexed file stubs (flat files don't support indexed ops) ──

    def start(self, file_name, key_field, key_value, mode='EQ'):
        return "48"

    def read_next(self, file_name, record_length=0):
        return self.read(file_name, record_length) if record_length else (None, "48")

    def delete(self, file_name):
        return "48"

    # ── Relative file operations ────────────────────────────────────

    def read_relative(self, file_name, relative_key, record_length=0):
        fh = self._handles.get(file_name)
        if fh is None or record_length <= 0:
            return None, "35"
        offset = (relative_key - 1) * record_length
        fh.seek(offset)
        raw = fh.read(record_length)
        if not raw or len(raw) < record_length:
            return None, "23"
        return raw, "00"

    def write_relative(self, file_name, record_bytes, relative_key, record_length=0):
        fh = self._handles.get(file_name)
        if fh is None:
            return "35"
        offset = (relative_key - 1) * record_length
        fh.seek(offset)
        try:
            fh.write(record_bytes)
            return "00"
        except OSError:
            return "48"

    def rewrite_relative(self, file_name, record_bytes, relative_key, record_length=0):
        return self.write_relative(file_name, record_bytes, relative_key, record_length)

    def delete_relative(self, file_name, relative_key, record_length=0):
        fh = self._handles.get(file_name)
        if fh is None:
            return "35"
        offset = (relative_key - 1) * record_length
        fh.seek(offset)
        try:
            fh.write(b'\x00' * record_length)
            return "00"
        except OSError:
            return "48"

    def close_all(self):
        for fh in self._handles.values():
            fh.close()
        self._handles.clear()


# ══════════════════════════════════════════════════════════════════════
# CobolFileManager
# ══════════════════════════════════════════════════════════════════════


class CobolFileManager:
    """Runtime file I/O manager injected into generated Python namespace.

    Generated Python calls _io_open/_io_read/_io_write/_io_close/_io_populate
    which are bound methods of this class.

    file_meta structure (from _FILE_META in generated code):
    {
        'INPUT-FILE': {
            'record_name': 'INPUT-RECORD',
            'fields': [{'name': 'FIELD-A', 'python_name': 'ws_field_a',
                         'start': 0, 'length': 10, 'type': 'string', 'decimals': 0}, ...],
            'record_length': 80,
            'status_var': 'ws_file_status',  # Python name, or None
            'direction': 'INPUT',
        },
        ...
    }
    """

    def __init__(self, file_meta, namespace, backend):
        self.file_meta = file_meta
        self.namespace = namespace
        self.backend = backend
        # Reverse map: record_name → file_name (for WRITE which uses record name)
        self._record_to_file = {}
        for fname, meta in file_meta.items():
            rn = meta.get("record_name")
            if rn:
                self._record_to_file[rn.upper()] = fname

    def _set_status(self, file_name, code):
        """Set FILE STATUS variable in namespace if configured."""
        meta = self.file_meta.get(file_name, {})
        status_var = meta.get("status_var")
        if status_var:
            existing = self.namespace.get(status_var)
            if existing is not None and hasattr(existing, "store"):
                existing.store(Decimal(code))
            else:
                self.namespace[status_var] = code

    def open(self, file_name, mode):
        """OPEN INPUT/OUTPUT."""
        status = self.backend.open(file_name, mode)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    def read(self, file_name):
        """READ — returns parsed record dict or None at EOF."""
        result = self.backend.read(file_name)
        if isinstance(result, tuple):
            record, status = result
        else:
            record, status = result, "00" if result else "10"
        self._set_status(file_name, status)
        return record

    def populate(self, file_name, record):
        """Copy parsed record fields → namespace variables via to_python_name().

        Record dict keys are COBOL names (e.g. 'ACCOUNT-NUM').
        Namespace keys are Python names (e.g. 'ws_account_num').
        """
        meta = self.file_meta.get(file_name, {})
        fields = meta.get("fields", [])
        for field in fields:
            cobol_name = field["name"]
            python_name = field.get("python_name") or to_python_name(cobol_name)
            if cobol_name not in record:
                # Reset to zero/blank to prevent stale data from previous record
                existing = self.namespace.get(python_name)
                if existing is not None and hasattr(existing, "store"):
                    existing.store(Decimal("0"))
                elif isinstance(existing, str):
                    self.namespace[python_name] = " "
                continue
            value = record[cobol_name]
            existing = self.namespace.get(python_name)
            if isinstance(value, str):
                # PIC X/A fields: direct string assignment
                if existing is not None and hasattr(existing, "store"):
                    existing.store(value)
                else:
                    self.namespace[python_name] = value
            else:
                # Numeric: use .store() to preserve PIC truncation
                if existing is not None and hasattr(existing, "store"):
                    existing.store(Decimal(str(value)))
                else:
                    self.namespace[python_name] = Decimal(str(value))

    def write(self, record_name, from_source=None):
        """WRITE record-name [FROM work-area].

        WRITE FROM is a group-level byte MOVE: read the from_source group's
        child fields from namespace, pack into FD record bytes, write.
        Without FROM, pack the FD record's own fields from namespace.
        """
        file_name = self._record_to_file.get(record_name.upper())
        if not file_name:
            return
        meta = self.file_meta.get(file_name, {})
        fields = meta.get("fields", [])

        # Determine which fields to read from namespace
        if from_source:
            # FROM work-area: read the from_source's child fields
            # The from_source group maps to the FD record's fields positionally
            from_meta = meta.get("from_fields", {}).get(from_source.upper(), fields)
        else:
            from_meta = fields

        # Collect field values as a record dict
        output_record = {}
        for field in from_meta:
            python_name = field.get("python_name") or to_python_name(field["name"])
            val = self.namespace.get(python_name)
            if val is not None:
                raw = val.value if hasattr(val, "value") else val
                if isinstance(raw, Decimal) and raw == 0:
                    raw = Decimal("0")
                output_record[field["name"]] = str(raw)
            else:
                output_record[field["name"]] = ""

        status = self.backend.write(file_name, output_record)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    def write_record(self, file_name, record):
        """Write a record dict directly to a file (for SORT output).

        Unlike write() which reads fields from namespace, this takes a
        pre-built record dict and passes it to the backend.
        """
        status = self.backend.write(file_name, record)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    def rewrite(self, record_name):
        """REWRITE record-name — update current record in place."""
        file_name = self._record_to_file.get(record_name.upper())
        if not file_name:
            return
        meta = self.file_meta.get(file_name, {})
        fields = meta.get("fields", [])
        record = {}
        for field in fields:
            python_name = field.get("python_name") or to_python_name(field["name"])
            val = self.namespace.get(python_name)
            if val is not None:
                raw = val.value if hasattr(val, "value") else val
                if isinstance(raw, Decimal) and raw == 0:
                    raw = Decimal("0")
                record[field["name"]] = str(raw)
            else:
                record[field["name"]] = ""
        status = self.backend.rewrite(file_name, record)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status or "00")

    def read_by_key(self, file_name, key_field, key_value):
        """READ with KEY IS — lookup record by key value."""
        result = self.backend.read_by_key(file_name, key_field, key_value)
        if isinstance(result, tuple):
            record, status = result
        else:
            record, status = result, "00" if result else "23"
        self._set_status(file_name, status)
        return record

    # ── Indexed file operations ─────────────────────────────────────

    def start(self, file_name, key_field, key_value, mode='EQ'):
        """START — position to record matching key criteria."""
        status = self.backend.start(file_name, key_field, key_value, mode)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    def read_next(self, file_name):
        """READ NEXT — sequential read after START."""
        result = self.backend.read_next(file_name)
        if isinstance(result, tuple):
            record, status = result
        else:
            record, status = result, "00" if result else "10"
        self._set_status(file_name, status)
        return record

    def delete(self, file_name):
        """DELETE — remove current record (last read)."""
        status = self.backend.delete(file_name)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    # ── Relative file operations ────────────────────────────────────

    def read_relative(self, file_name, relative_key):
        """READ record at relative position N."""
        result = self.backend.read_relative(file_name, relative_key)
        if isinstance(result, tuple):
            record, status = result
        else:
            record, status = result, "00" if result else "23"
        self._set_status(file_name, status)
        return record

    def write_relative(self, record_name, relative_key):
        """WRITE record at relative position N."""
        file_name = self._record_to_file.get(record_name.upper())
        if not file_name:
            return
        meta = self.file_meta.get(file_name, {})
        fields = meta.get("fields", [])
        record = {}
        for field in fields:
            python_name = field.get("python_name") or to_python_name(field["name"])
            val = self.namespace.get(python_name)
            if val is not None:
                raw = val.value if hasattr(val, "value") else val
                record[field["name"]] = str(raw)
            else:
                record[field["name"]] = ""
        status = self.backend.write_relative(file_name, record, relative_key)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    def delete_relative(self, file_name, relative_key):
        """DELETE record at relative position N."""
        status = self.backend.delete_relative(file_name, relative_key)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)

    def close(self, file_name):
        """CLOSE file-name."""
        status = self.backend.close(file_name)
        if isinstance(status, tuple):
            status = status[1]
        self._set_status(file_name, status)
