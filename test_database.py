"""
test_database.py — Database Integration Tests for Aletheia Beyond
=================================================================

Tests database functionality with SQLite (aiosqlite) for fast CI.

Run with:
    pytest test_database.py -v --tb=short

Requires:
    pip install pytest pytest-anyio httpx aiosqlite
"""

import os
import uuid
from decimal import Decimal

import pytest

# Use SQLite for testing
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_aletheia.db"
os.environ["USE_IN_MEMORY_DB"] = "false"

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from passlib.context import CryptContext

# Password hasher
hasher = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


# ══════════════════════════════════════════════════════════════════════
# TEST ENGINE SETUP
# ══════════════════════════════════════════════════════════════════════

# Create engine for tests
test_engine = create_async_engine(
    "sqlite+aiosqlite:///./test_aletheia.db",
    echo=False,
)
TestSession = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)


# ══════════════════════════════════════════════════════════════════════
# MODEL TESTS
# ══════════════════════════════════════════════════════════════════════

class TestUserModel:
    """Test User model functionality."""

    @pytest.mark.anyio
    async def test_create_user(self):
        """Can create a user with all fields."""
        from database import Base
        from models import User

        # Create tables
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("password123"),
                institution="Test Institution",
                city="Test City",
                country="Test Country",
                role="Developer",
                is_approved=False,
            )
            session.add(user)
            await session.commit()

            assert user.id is not None
            assert isinstance(user.id, uuid.UUID)
            assert user.is_approved is False

    @pytest.mark.anyio
    async def test_user_to_dict(self):
        """User.to_dict() matches legacy format."""
        from database import Base
        from models import User
        from sqlalchemy.orm import selectinload

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
                is_approved=True,
            )
            session.add(user)
            await session.commit()

            # Reload with eager loading for relationships
            from sqlalchemy import select
            result = await session.execute(
                select(User)
                .options(selectinload(User.security_events))
                .where(User.id == user.id)
            )
            user = result.scalar_one()

            user_dict = user.to_dict()

            assert "password" in user_dict
            assert "institution" in user_dict
            assert "is_approved" in user_dict
            assert "security_history" in user_dict
            assert isinstance(user_dict["security_history"], list)

    @pytest.mark.anyio
    async def test_user_timestamps(self):
        """User has timestamps set on creation."""
        from database import Base
        from models import User

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            assert user.created_at is not None
            assert user.updated_at is not None


class TestSecurityEventModel:
    """Test SecurityEvent model functionality."""

    @pytest.mark.anyio
    async def test_create_security_event(self):
        """Can create a security event linked to user."""
        from database import Base
        from models import User, SecurityEvent

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            # Create user first
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            # Create event
            event = SecurityEvent(
                user_id=user.id,
                event="Test Event",
                ip_address="127.0.0.1",
            )
            session.add(event)
            await session.commit()

            assert event.id is not None
            assert event.user_id == user.id

    @pytest.mark.anyio
    async def test_security_event_to_dict(self):
        """SecurityEvent.to_dict() matches legacy format."""
        from database import Base
        from models import User, SecurityEvent

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            event = SecurityEvent(
                user_id=user.id,
                event="Login",
                ip_address="192.168.1.1",
            )
            session.add(event)
            await session.commit()
            await session.refresh(event)

            event_dict = event.to_dict()

            assert event_dict["event"] == "Login"
            assert event_dict["ip"] == "192.168.1.1"
            assert "timestamp" in event_dict


class TestAnalysisSessionModel:
    """Test AnalysisSession model functionality."""

    @pytest.mark.anyio
    async def test_create_analysis_session(self):
        """Can create an analysis session with Decimal complexity score."""
        from database import Base
        from models import User, AnalysisSession

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            analysis = AnalysisSession(
                user_id=user.id,
                filename="test.cbl",
                cobol_code="IDENTIFICATION DIVISION.",
                is_audit_mode=False,
                complexity_score=Decimal("5.50"),
            )
            session.add(analysis)
            await session.commit()

            assert analysis.id is not None
            assert analysis.complexity_score == Decimal("5.50")

    @pytest.mark.anyio
    async def test_analysis_session_with_audit_mode(self):
        """Can create an audit-mode session with drift detection."""
        from database import Base
        from models import User, AnalysisSession

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            analysis = AnalysisSession(
                user_id=user.id,
                filename="audit.cbl",
                cobol_code="IDENTIFICATION DIVISION.",
                modernized_code="# Python translation",
                is_audit_mode=True,
                drift_detected=True,
                complexity_score=Decimal("7.25"),
            )
            session.add(analysis)
            await session.commit()

            assert analysis.is_audit_mode is True
            assert analysis.drift_detected is True
            assert analysis.modernized_code == "# Python translation"


class TestChatMessageModel:
    """Test ChatMessage model functionality."""

    @pytest.mark.anyio
    async def test_create_chat_message(self):
        """Can create chat messages with Decimal confidence."""
        from database import Base
        from models import User, ChatMessage

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            user_msg = ChatMessage(
                user_id=user.id,
                role="user",
                content="What does this code do?",
                cobol_context="COMPUTE WS-A = WS-B + WS-C.",
            )
            session.add(user_msg)

            assistant_msg = ChatMessage(
                user_id=user.id,
                role="assistant",
                content="This code adds WS-B and WS-C.",
                confidence=Decimal("0.95"),
            )
            session.add(assistant_msg)
            await session.commit()

            assert user_msg.role == "user"
            assert assistant_msg.confidence == Decimal("0.95")


class TestDecimalPrecision:
    """Verify Decimal values are stored without precision loss."""

    @pytest.mark.anyio
    async def test_complexity_score_precision(self):
        """Complexity score maintains Decimal precision."""
        from database import Base
        from models import User, AnalysisSession

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            precise_score = Decimal("3.33")

            analysis = AnalysisSession(
                user_id=user.id,
                filename="precision.cbl",
                cobol_code="TEST",
                complexity_score=precise_score,
            )
            session.add(analysis)
            await session.commit()
            await session.refresh(analysis)

            assert analysis.complexity_score == precise_score

    @pytest.mark.anyio
    async def test_confidence_score_precision(self):
        """Confidence score maintains Decimal precision."""
        from database import Base
        from models import User, ChatMessage

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with TestSession() as session:
            user = User(
                username=f"user_{uuid.uuid4().hex[:8]}",
                password_hash=hasher.hash("pass"),
                institution="I",
                city="C",
                country="CO",
                role="R",
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)

            precise_confidence = Decimal("0.95")

            msg = ChatMessage(
                user_id=user.id,
                role="assistant",
                content="Test",
                confidence=precise_confidence,
            )
            session.add(msg)
            await session.commit()
            await session.refresh(msg)

            assert msg.confidence == precise_confidence


# Cleanup test database after all tests
def teardown_module():
    """Remove test database file."""
    import asyncio

    async def cleanup():
        await test_engine.dispose()

    try:
        asyncio.get_event_loop().run_until_complete(cleanup())
    except RuntimeError:
        asyncio.run(cleanup())

    # Try to remove the file
    import time
    for _ in range(3):
        try:
            if os.path.exists("./test_aletheia.db"):
                os.remove("./test_aletheia.db")
            break
        except PermissionError:
            time.sleep(0.1)
