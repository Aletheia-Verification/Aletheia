"""
models.py — SQLAlchemy ORM Models for Aletheia Beyond
=====================================================

All models use UUID primary keys for security (non-sequential).
Timestamps use timezone-aware UTC.

Tables:
    - users: User accounts with approval status
    - security_events: Audit trail for SOC-2 compliance
    - analysis_sessions: COBOL analysis records
    - chat_messages: Chat interaction history
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, List, Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base

# Conditional import for PostgreSQL-specific types
try:
    from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
    HAS_POSTGRES = True
except ImportError:
    HAS_POSTGRES = False

# Use String for UUID on SQLite, native UUID on PostgreSQL
from sqlalchemy import Uuid


# ──────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ──────────────────────────────────────────────────────────────────────

def utc_now() -> datetime:
    """Return current UTC timestamp."""
    return datetime.now(timezone.utc)


# ──────────────────────────────────────────────────────────────────────
# USER MODEL
# ──────────────────────────────────────────────────────────────────────

class User(Base):
    """
    User account model.

    Maps to legacy users_db dict structure for backward compatibility.

    Attributes:
        id: UUID primary key
        username: Unique, normalized lowercase username
        password_hash: PBKDF2-SHA256 hashed password
        institution: Company/organization name
        city: User's city
        country: User's country
        role: Job title
        is_approved: Gate for analysis access
        created_at: Account creation timestamp
        updated_at: Last modification timestamp
    """
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    username: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
        index=True,
    )
    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    institution: Mapped[str] = mapped_column(String(200), nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    country: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[str] = mapped_column(String(100), nullable=False)
    is_approved: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
    )

    # Relationships
    security_events: Mapped[List["SecurityEvent"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="SecurityEvent.timestamp.desc()",
    )
    analysis_sessions: Mapped[List["AnalysisSession"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )
    chat_messages: Mapped[List["ChatMessage"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert to dict matching legacy users_db format.

        Returns:
            Dictionary with password, institution, city, country,
            role, is_approved, and security_history fields.
        """
        return {
            "password": self.password_hash,
            "institution": self.institution,
            "city": self.city,
            "country": self.country,
            "role": self.role,
            "is_approved": self.is_approved,
            "security_history": [
                evt.to_dict() for evt in self.security_events
            ],
        }


# ──────────────────────────────────────────────────────────────────────
# SECURITY EVENT MODEL
# ──────────────────────────────────────────────────────────────────────

class SecurityEvent(Base):
    """
    Audit trail entry for SOC-2 compliance.

    Records every state-changing action: login, analysis, file upload.

    Attributes:
        id: UUID primary key
        user_id: Foreign key to users.id
        event: Event description
        ip_address: Client IP address (IPv4 or IPv6)
        timestamp: Event timestamp (UTC)
    """
    __tablename__ = "security_events"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event: Mapped[str] = mapped_column(String(500), nullable=False)
    ip_address: Mapped[str] = mapped_column(
        String(45),
        nullable=False,
        default="local",
    )
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        index=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="security_events")

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert to dict matching legacy SecurityEventRecord format.

        Returns:
            Dictionary with event, timestamp, and ip fields.
        """
        return {
            "event": self.event,
            "timestamp": self.timestamp.isoformat(),
            "ip": self.ip_address,
        }


# ──────────────────────────────────────────────────────────────────────
# ANALYSIS SESSION MODEL
# ──────────────────────────────────────────────────────────────────────

class AnalysisSession(Base):
    """
    Record of a COBOL analysis or audit engagement.

    Stores both input (COBOL code) and output (analysis result)
    for full audit traceability.

    Attributes:
        id: UUID primary key
        user_id: Foreign key to users.id
        filename: Original COBOL filename
        cobol_code: Source code analyzed
        modernized_code: Python translation (audit mode only)
        is_audit_mode: Whether this was an audit engagement
        result_json: Full analysis result as JSON
        complexity_score: 1.00-10.00 score (Decimal for precision)
        drift_detected: Whether behavioral drift was found
        created_at: Session timestamp
    """
    __tablename__ = "analysis_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    cobol_code: Mapped[str] = mapped_column(Text, nullable=False)
    modernized_code: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    is_audit_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    # Store result as JSON text (compatible with both SQLite and PostgreSQL)
    result_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    complexity_score: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(4, 2),
        nullable=True,
    )
    drift_detected: Mapped[Optional[bool]] = mapped_column(
        Boolean,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        index=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="analysis_sessions")

    # Composite index for user analysis history queries
    __table_args__ = (
        Index("ix_analysis_user_created", "user_id", "created_at"),
    )


# ──────────────────────────────────────────────────────────────────────
# CHAT MESSAGE MODEL
# ──────────────────────────────────────────────────────────────────────

class ChatMessage(Base):
    """
    Chat interaction record for context preservation.

    Attributes:
        id: UUID primary key
        user_id: Foreign key to users.id
        session_id: Optional session grouping ID
        role: 'user' or 'assistant'
        content: Message text
        cobol_context: Code context provided (optional)
        python_context: Translation context (optional)
        confidence: Assistant confidence score 0.00-1.00 (Decimal)
        created_at: Message timestamp
    """
    __tablename__ = "chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    session_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid,
        nullable=True,
        index=True,
    )
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    cobol_context: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    python_context: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    confidence: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(3, 2),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="chat_messages")
